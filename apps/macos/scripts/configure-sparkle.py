#!/usr/bin/env python3
"""只向构建配置注入公开验证密钥；私钥仅用于生成更新签名，不进入应用。"""
import base64
import os
from pathlib import Path
import plistlib
import sys

PREVIOUS_PUBLIC_KEY = 'zYvJmq2G5KNcMa/wbxZwKrd+LmjFB3c1khtPWPj6qFo='
FEED = 'https://github.com/yuangy1995/card_wallet/releases/latest/download/appcast.xml'


def validated_key(value):
    value = value.strip()
    try:
        decoded = base64.b64decode(value, validate=True)
    except (ValueError, UnicodeError):
        raise ValueError('SPARKLE_PUBLIC_KEY 必须是有效的 Base64 公钥') from None
    if len(decoded) != 32 or not any(decoded):
        raise ValueError('SPARKLE_PUBLIC_KEY 必须是 32 字节 Ed25519 公钥')
    if value == PREVIOUS_PUBLIC_KEY:
        raise ValueError('当前发布系列必须使用新 Sparkle 密钥，不得沿用旧公钥')
    return value


def configure(path, value):
    key = validated_key(value)
    with path.open('rb') as source:
        info = plistlib.load(source)
    info['SUPublicEDKey'] = key
    info['SUFeedURL'] = FEED
    with path.open('wb') as target:
        plistlib.dump(info, target, sort_keys=False)


if __name__ == '__main__':
    try:
        configure(Path(__file__).resolve().parents[1] / 'Resources/Info.plist', os.environ.get('SPARKLE_PUBLIC_KEY', ''))
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(f'Sparkle 配置失败：{error}', file=sys.stderr)
        sys.exit(1)
    print('已注入当前发布系列的公开更新密钥。')
