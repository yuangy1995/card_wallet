#!/usr/bin/env python3
"""从本地完整 Git 历史提取旧 Gradle 签名密码，写入仓库外的私有 filter-repo 替换表。"""
import os
from pathlib import Path
import re
import subprocess
import sys

PASSWORD = re.compile(rb'''(?:storePassword|keyPassword)\s*=?\s*["']([^"'\r\n]+)["']''')


def collect_passwords():
    objects = subprocess.run(["git", "rev-list", "--objects", "--all"], check=True, capture_output=True).stdout
    blobs = set()
    for line in objects.splitlines():
        parts = line.split(b" ", 1)
        if len(parts) == 2 and parts[1].endswith((b".gradle", b".gradle.kts")):
            blobs.add(parts[0])
    passwords = set()
    for blob in blobs:
        content = subprocess.run(["git", "cat-file", "-p", blob.decode("ascii")], check=True, capture_output=True).stdout
        passwords.update(PASSWORD.findall(content))
    return passwords


def main():
    if len(sys.argv) != 2:
        raise ValueError("用法：在完整镜像仓库中执行 prepare-signing-history-redactions.py <仓库外的新替换表路径>")
    output = Path(sys.argv[1]).expanduser().resolve()
    repository = Path(subprocess.run(["git", "rev-parse", "--absolute-git-dir"], check=True, capture_output=True, text=True).stdout.strip()).resolve()
    if output == repository or repository in output.parents:
        raise ValueError("替换表必须在 Git 仓库之外")
    passwords = collect_passwords()
    if not passwords:
        raise ValueError("没有提取到旧密码；检查是否为完整镜像，或是否已经清理。不得据此认定历史无其他密钥。")
    if any(b"==>" in password or b"\x00" in password for password in passwords):
        raise ValueError("发现需要手工转义的旧密码；停止生成，避免错误替换。")
    descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as handle:
        for password in sorted(passwords):
            handle.write(b"literal:" + password + b"==>REMOVED_EXPOSED_SIGNING_PASSWORD\n")
    print(f"已写入 {len(passwords)} 条私有替换规则；不要展示或上传此文件。")
    print("仅生成替换表，没有重写历史或推送远端；仍需扫描其他类型凭据。")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError):
        print("生成失败：检查完整历史、仓库外的新输出路径和权限；不要打印旧密码。", file=sys.stderr)
        sys.exit(1)
