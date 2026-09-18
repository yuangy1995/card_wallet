#!/usr/bin/env python3
"""Verify an external private signing backup, upload it via gh stdin, optionally dispatch releases."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

REPOSITORY = 'yuangy1995/card_wallet'
SECRET_NAMES = ('ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS',
                'ANDROID_KEY_PASSWORD', 'ANDROID_SIGNING_CERT_SHA256', 'SPARKLE_PRIVATE_KEY')


def run(command, *, data=None, env=None):
    result = subprocess.run(command, input=data, env=env, capture_output=True)
    if result.returncode:
        raise RuntimeError(f'{Path(command[0]).name} 执行失败，请检查登录、权限或工具版本；未打印凭据。')
    return result.stdout


def remote_file(name):
    response = json.loads(run(['gh', 'api', f'repos/{REPOSITORY}/contents/{name}?ref=main']))
    return base64.b64decode(response['content'])


def upload(values):
    for name in SECRET_NAMES:
        run(['gh', 'secret', 'set', name, '--repo', REPOSITORY], data=values[name].encode())
        print(f'已配置 {name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--publish', action='store_true')
    args = parser.parse_args()
    for tool in ('gh', 'keytool', 'openssl'):
        if not shutil.which(tool):
            raise RuntimeError(f'缺少 {tool}；需要 GitHub CLI、JDK 17 和支持 Ed25519 的 OpenSSL。')
    directory = args.directory.expanduser().resolve()
    if any((p / '.git').exists() for p in (directory, *directory.parents)):
        raise RuntimeError('私有签名目录不能位于 Git 工作区中。')
    if os.name != 'posix':
        raise RuntimeError('请在 macOS、Linux 或 WSL 的私有文件系统运行。')
    os.chmod(directory, 0o700)
    for name in ('release.p12', 'signing.json', 'sparkle-private-key.txt'):
        path = directory / name
        if not path.is_file() or path.is_symlink():
            raise RuntimeError(f'备份缺少普通文件 {name}')
        os.chmod(path, 0o600)
    run(['gh', 'auth', 'status'])
    record = json.loads((directory / 'signing.json').read_text())
    certificate = run(['keytool', '-exportcert', '-keystore', str(directory / 'release.p12'),
                       '-alias', record['alias'], '-storepass:env', 'CW_SIGNING_PASSWORD'],
                      env={**os.environ, 'CW_SIGNING_PASSWORD': record['password']})
    fingerprint = hashlib.sha256(certificate).hexdigest()
    pinned = remote_file('apps/android/signing-certificate.sha256').decode().strip()
    if fingerprint != record['certificate_sha256'] or fingerprint != pinned:
        raise RuntimeError('Android 备份和远端新证书指纹不一致；未上传。')
    encoded_seed = (directory / 'sparkle-private-key.txt').read_text().strip()
    seed = base64.b64decode(encoded_seed, validate=True)
    if len(seed) != 32:
        raise RuntimeError('Sparkle 备份必须是 Base64 编码的 32 字节 seed。')
    # RFC 8410 PKCS#8 wrapping. Secret bytes go to stdin, never argv or a temporary file.
    private_der = bytes.fromhex('302e020100300506032b657004220420') + seed
    public_der = run(['openssl', 'pkey', '-inform', 'DER', '-pubout', '-outform', 'DER'], data=private_der)
    if len(public_der) != 44 or public_der[:12].hex() != '302a300506032b6570032100':
        raise RuntimeError('OpenSSL 未返回预期的 Ed25519 公钥。')
    public_key = base64.b64encode(public_der[12:]).decode()
    plist = plistlib.loads(remote_file('apps/macos/Resources/Info.plist'))
    if public_key != record['sparkle_public_key'] or public_key != plist['SUPublicEDKey']:
        raise RuntimeError('Sparkle 备份与远端新公钥不一致；未上传。')
    values = {'ANDROID_KEYSTORE_BASE64': base64.b64encode((directory / 'release.p12').read_bytes()).decode(),
              'ANDROID_KEYSTORE_PASSWORD': record['password'], 'ANDROID_KEY_ALIAS': record['alias'],
              'ANDROID_KEY_PASSWORD': record['password'], 'ANDROID_SIGNING_CERT_SHA256': fingerprint,
              'SPARKLE_PRIVATE_KEY': encoded_seed}
    try:
        upload(values)
    except RuntimeError:
        print('可能仅部分 Secrets 更新成功。不要发布；修复权限后使用同一目录重跑。', file=sys.stderr)
        raise
    print('六项新签名 Secrets 配置完成；请妥善保留这份私有备份。')
    if args.publish:
        run(['gh', 'workflow', 'run', 'android-release.yml', '--repo', REPOSITORY, '--ref', 'main',
             '-f', 'version=1.3.0', '-f', 'version_code=5', '-f', 'publish=true'])
        run(['gh', 'workflow', 'run', 'macos-release.yml', '--repo', REPOSITORY, '--ref', 'main',
             '-f', 'version=1.1.0', '-f', 'publish=true'])
        print('两端发布已触发，尚不代表发布成功。请检查 Actions 和 Releases，再处理旧仓库。')


if __name__ == '__main__':
    try:
        main()
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, KeyError):
        print('私有备份格式、目录或工具读取失败；未打印凭据，请核对文件。', file=sys.stderr)
        sys.exit(1)
