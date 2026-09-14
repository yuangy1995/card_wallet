#!/bin/bash
# 只生成本地发布附件，不上传、不发布 GitHub Release。
set -euo pipefail
cd "$(dirname "$0")"

if [ "$#" -ne 1 ]; then
    echo '用法: bash prepare-update.sh /绝对路径/卡包.app' >&2
    exit 1
fi

APP_PATH="$1"
PLIST="$APP_PATH/Contents/Info.plist"
SPARKLE_BIN="build/SourcePackages/artifacts/sparkle/Sparkle/bin"
ACCOUNT="com.applist.cardwallet.mac"
KEY_ACCOUNT="com.applist.cardwallet.mac.public"
REPOSITORY="yuangy1995/card-wallet-releases"

if [ ! -x "$SPARKLE_BIN/generate_appcast" ]; then
    echo '请先按 README 解析 Sparkle 依赖。' >&2
    exit 1
fi

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")
if [ "$BUNDLE_ID" != "$ACCOUNT" ]; then
    echo '请选择卡包 macOS 客户端。' >&2
    exit 1
fi
if [ -z "${SPARKLE_PRIVATE_KEY:-}" ]; then
    if ! PUBLIC_KEY=$("$SPARKLE_BIN/generate_keys" --account "$KEY_ACCOUNT" -p); then
        echo '未找到当前发布系列的 Sparkle 更新签名密钥；本地请恢复钥匙串，CI 请配置 SPARKLE_PRIVATE_KEY。' >&2
        exit 1
    fi
    APP_KEY=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$PLIST")
    if [ "$APP_KEY" != "$PUBLIC_KEY" ]; then
        echo '应用的更新公钥与本机签名密钥不匹配。' >&2
        exit 1
    fi
fi

# CI 仅通过标准输入传入当前发布密钥，不写文件、不放进命令行参数。
generate_appcast() {
    if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
        printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/generate_appcast" --ed-key-file - "$@"
    else
        "$SPARKLE_BIN/generate_appcast" --account "$KEY_ACCOUNT" "$@"
    fi
}

# 固定使用 Ad-Hoc 签名，不要求 Developer ID 或公证。
codesign --verify --deep --strict "$APP_PATH"
if ! codesign -dv "$APP_PATH" 2>&1 | grep '^Signature=adhoc$' > /dev/null; then
    echo '发布包必须使用 Ad-Hoc 临时签名，请使用 build.sh 打包。' >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")
TAG="mac-v${VERSION}-${BUILD}"
OUTPUT="dist/updates/$TAG"
mkdir -p dist/updates
mkdir "$OUTPUT"
for ARCH in arm64 x86_64; do
    ARCH_APP="$OUTPUT/$ARCH/卡包.app"
    mkdir "$OUTPUT/$ARCH"
    ditto "$APP_PATH" "$ARCH_APP"
    while IFS= read -r -d '' BINARY; do
        if file "$BINARY" | grep 'Mach-O universal binary' > /dev/null; then
            lipo "$BINARY" -thin "$ARCH" -output "$BINARY"
        fi
    done < <(find "$ARCH_APP" -type f -print0)
    FRAMEWORK="$ARCH_APP/Contents/Frameworks/Sparkle.framework"
    # 拆分架构后，从内到外重新施加临时签名，保留组件原有权限。
    for COMPONENT in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
        codesign --force --sign - --options runtime --preserve-metadata=entitlements "$FRAMEWORK/Versions/B/$COMPONENT"
    done
    codesign --force --sign - --options runtime "$FRAMEWORK"
    codesign --force --sign - --options runtime --preserve-metadata=entitlements "$ARCH_APP"
    codesign --verify --deep --strict "$ARCH_APP"
    test "$(lipo -archs "$ARCH_APP/Contents/MacOS/CreditCardMac")" = "$ARCH"
    ARCHIVE="CardWallet-${VERSION}-${BUILD}-${ARCH}.zip"
    ditto -c -k --sequesterRsrc --keepParent "$ARCH_APP" "$OUTPUT/$ARCH/$ARCHIVE"
generate_appcast \
    --maximum-deltas 0 \
    --download-url-prefix "https://github.com/$REPOSITORY/releases/download/$TAG/" \
    --link "https://github.com/$REPOSITORY/releases/tag/$TAG" \
    -o "$OUTPUT/$ARCH/appcast.xml" "$OUTPUT/$ARCH"
    mv "$OUTPUT/$ARCH/$ARCHIVE" "$OUTPUT/$ARCHIVE"
done
swift scripts/merge-update-feeds.swift "$OUTPUT/arm64/appcast.xml" "$OUTPUT/x86_64/appcast.xml" "$OUTPUT/appcast.xml"
swift scripts/verify-update.swift "$APP_PATH" "$OUTPUT"
echo "已生成发布附件：$OUTPUT"
echo "Release 标签必须使用：${TAG}；请一并上传 ZIP 和 appcast.xml。"
