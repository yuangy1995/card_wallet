#!/usr/bin/env python3
"""检查整个 Git 索引中的签名材料和常见凭据；只输出文件名，不输出匹配值。不是全历史扫描。"""
import os
from pathlib import Path
import subprocess
import sys

BLOCKED_SUFFIXES = {".jks", ".keystore", ".p12", ".pfx", ".p8", ".key", ".mobileprovision", ".provisionprofile"}
BLOCKED_NAMES = {"keystore.properties", "key.properties", "signing.properties", "signing.json", "signing.env", "sparkle_private_key", "sparkle_ed25519_key"}
PRIVATE_PATTERN = r"-----BEGIN (RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,}"
PASSWORD_PATTERN = r'''(storePassword|keyPassword)[[:space:]]*=?[[:space:]]*["'][^"']+["']'''


def git_paths(*args):
    result = subprocess.run(["git", *args], capture_output=True, check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError("Git 索引检查失败")
    return {path.decode("utf-8", errors="replace") for path in result.stdout.split(b"\0") if path}


def check():
    # 发布脚本可能在 apps/android 或 apps/macos 中调用，扫描范围不能随工作目录缩小。
    root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True, stderr=subprocess.PIPE).strip()
    os.chdir(root)
    paths = git_paths("ls-files", "-z")
    blocked = set()
    for name in paths:
        path = Path(name)
        basename = path.name.lower()
        if (path.suffix.lower() in BLOCKED_SUFFIXES or basename in BLOCKED_NAMES
                or basename == ".env" or (basename.startswith(".env.") and basename != ".env.example")):
            blocked.add(name)
    blocked |= git_paths("grep", "--cached", "-I", "-l", "-z", "-E", "-e", PRIVATE_PATTERN, "--", ".")
    blocked |= git_paths("grep", "--cached", "-I", "-l", "-z", "-E", "-e", PASSWORD_PATTERN, "--", "*.gradle", "*.gradle.kts")
    for path in sorted(blocked):
        print(f"禁止提交签名材料或疑似凭据：{path!r}", file=sys.stderr)
    return not blocked


if __name__ == "__main__":
    try:
        sys.exit(0 if check() else 1)
    except (OSError, RuntimeError, subprocess.CalledProcessError):
        print("签名安全检查无法完成，停止检查。", file=sys.stderr)
        sys.exit(2)
