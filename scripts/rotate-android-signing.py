#!/usr/bin/env python3
"""在维护者本机生成 Android 新签名并通过标准输入上传 GitHub Secrets。"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import shlex
import shutil
import subprocess
import sys

SECRET_NAMES = ("ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS",
                "ANDROID_KEY_PASSWORD", "ANDROID_SIGNING_CERT_SHA256")


def execute(command, *, env=None, data=None):
    result = subprocess.run(command, input=data, env=env, capture_output=True, check=False)
    if result.returncode:
        # 不转发工具原始输出，避免意外打印令牌或密码。
        raise RuntimeError(f"{Path(command[0]).name} 执行失败；请检查工具、登录、权限及私有备份。")
    return result.stdout


def write_private(path, content):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        handle.write(content)


def signing_environment(directory, record):
    return {
        "ANDROID_KEYSTORE_PATH": str(directory / "release.p12"),
        "ANDROID_KEYSTORE_PASSWORD": record["password"],
        "ANDROID_KEY_ALIAS": record["alias"],
        "ANDROID_KEY_PASSWORD": record["password"],
        "ANDROID_SIGNING_CERT_SHA256": record["certificate_sha256"],
    }


def upload(repository, directory, record):
    values = signing_environment(directory, record)
    values["ANDROID_KEYSTORE_BASE64"] = base64.b64encode((directory / "release.p12").read_bytes()).decode("ascii")
    for name in SECRET_NAMES:
        execute(["gh", "secret", "set", name, "--repo", repository], data=values[name].encode("utf-8"))
        print(f"已上传 {name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default="yuangy1995/card_wallet")
    parser.add_argument("--directory", type=Path, required=True, help="仓库之外的私有备份目录；首次运行必须不存在")
    parser.add_argument("--reuse", action="store_true", help="上传已有备份，不生成第二套密钥；用于上传失败后的重试")
    args = parser.parse_args()
    if os.name != "posix":
        raise RuntimeError("请在 macOS、Linux 或 WSL 的私有 Linux 文件系统内运行，以保证文件权限。")
    for tool in ("keytool", "gh"):
        if not shutil.which(tool):
            raise RuntimeError(f"缺少 {tool}；需要 JDK 17 和已登录的 GitHub CLI。")
    directory = args.directory.expanduser().resolve()
    if any((parent / ".git").exists() for parent in (directory, *directory.parents)):
        raise RuntimeError("签名备份不能放在任何 Git 工作区内。")
    execute(["gh", "auth", "status"])
    os.umask(0o077)
    if args.reuse:
        if directory.stat().st_mode & 0o077:
            raise RuntimeError("备份目录必须仅当前用户可访问（chmod 700）。")
        record = json.loads((directory / "signing.json").read_text(encoding="utf-8"))
    else:
        directory.mkdir(mode=0o700, parents=True, exist_ok=False)
        record = {"alias": "cardwallet-release", "password": secrets.token_urlsafe(48)}
        env = {**os.environ, "CW_SIGNING_PASSWORD": record["password"]}
        execute(["keytool", "-genkeypair", "-noprompt", "-storetype", "PKCS12",
                 "-keystore", str(directory / "release.p12"), "-alias", record["alias"],
                 "-keyalg", "RSA", "-keysize", "3072", "-validity", "10000",
                 "-dname", "CN=Card Wallet Release",
                 "-storepass:env", "CW_SIGNING_PASSWORD", "-keypass:env", "CW_SIGNING_PASSWORD"], env=env)
        os.chmod(directory / "release.p12", 0o600)
    env = {**os.environ, "CW_SIGNING_PASSWORD": record["password"]}
    certificate = execute(["keytool", "-exportcert", "-keystore", str(directory / "release.p12"),
                           "-alias", record["alias"], "-storepass:env", "CW_SIGNING_PASSWORD"], env=env)
    fingerprint = hashlib.sha256(certificate).hexdigest()
    if args.reuse:
        if record["certificate_sha256"] != fingerprint:
            raise RuntimeError("备份记录与签名文件不匹配，未上传任何 Secret。")
    else:
        record["certificate_sha256"] = fingerprint
        write_private(directory / "signing.json", json.dumps(record, indent=2) + "\n")
        write_private(directory / "signing.env", "".join(
            f"export {name}={shlex.quote(value)}\n" for name, value in signing_environment(directory, record).items()))
    # 再次调用发布校验器，禁止意外重新上传已泄漏的旧证书。
    import importlib.util
    spec = importlib.util.spec_from_file_location("verify_release", Path(__file__).resolve().parents[1] / "apps/android/scripts/verify-release.py")
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    verifier.expected_certificate(fingerprint)
    print(f"私有恢复备份：{directory}；请保存在加密磁盘或密码管理器中，不要上传或粘贴。")
    try:
        upload(args.repo, directory, record)
    except RuntimeError:
        print("Secrets 可能仅部分更新。不要触发发布；修复权限后用相同目录加 --reuse 重试。", file=sys.stderr)
        raise
    print(f"五项 Secrets 上传完成。新证书 SHA-256：{fingerprint}")
    print("本脚本没有重写 Git 历史，也没有发布安装包。")


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print(f"签名配置失败：{error}", file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, KeyError) as error:
        print(f"签名配置失败：{type(error).__name__}。检查依赖、目录、GitHub 权限；不要把私有备份发到聊天。", file=sys.stderr)
        sys.exit(1)
