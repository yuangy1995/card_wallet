#!/bin/bash
# 仅生成 Android 发布产物，不上传、不改动 Mac 的 appcast.xml。
set -euo pipefail
cd "$(dirname "$0")"

if [ "$#" -ne 2 ] || [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! "$2" =~ ^[1-9][0-9]*$ ]]; then
    echo "用法: bash prepare-update.sh <版本号，如 1.1.0> <递增版本编号，如 2>" >&2
    exit 1
fi
VERSION="$1"
VERSION_CODE="$2"
TAG="android-v$VERSION-$VERSION_CODE"
OUTPUT="dist/updates/$TAG"
if [ -e "$OUTPUT" ]; then
    echo "发布目录已存在，请使用新的版本编号：$OUTPUT" >&2
    exit 1
fi
if [ -z "${JAVA_HOME:-}" ] && [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi
./gradlew :app:assembleRelease -PreleaseVersionName="$VERSION" -PreleaseVersionCode="$VERSION_CODE"
mkdir -p "$OUTPUT"
ASSET="CardWallet-Android-$VERSION_CODE.apk"
cp app/build/outputs/apk/release/app-release.apk "$OUTPUT/$ASSET"
shasum -a 256 "$OUTPUT/$ASSET"
echo "已生成：$OUTPUT/$ASSET"
echo "发布仓库：yuangy1995/card_wallet"
echo "Release 标签：${TAG}（正式版，不勾选预发布）"
echo "上传 APK 后 GitHub 自动生成 SHA-256 digest，客户端验证后才允许安装。"
