#!/bin/bash
set -e

# 设置输出颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "${YELLOW}=== 开始打包 macOS 原生卡包客户端 ===${NC}"
mkdir -p build
BUILD_LOG="./build/xcodebuild-archive.log"

run_xcodebuild_archive() {
    echo -e "${YELLOW}xcodebuild 归档日志: $(pwd)/${BUILD_LOG#./}${NC}"
    set +e
    "$@" 2>&1 | tee "$BUILD_LOG"
    local archive_status=${PIPESTATUS[0]}

    if [ "$archive_status" -ne 0 ] && grep -q "Build operation failed without specifying any errors" "$BUILD_LOG"; then
        echo -e "${YELLOW}Xcode Archive 返回了无具体错误的失败，自动重试一次...${NC}" | tee -a "$BUILD_LOG"
        "$@" 2>&1 | tee -a "$BUILD_LOG"
        archive_status=${PIPESTATUS[0]}
    fi

    set -e

    if [ "$archive_status" -ne 0 ]; then
        echo -e "${RED}❌ xcodebuild 归档失败，退出码: ${archive_status}${NC}"
        echo -e "${RED}最近 120 行日志如下，完整日志见: $(pwd)/${BUILD_LOG#./}${NC}"
        tail -n 120 "$BUILD_LOG"
        exit "$archive_status"
    fi
}

# 1. 归档前刷新 Asset Catalog 图标，避免签名后再改 .app 包
ICON_PNG="$(dirname "$0")/Resources/AppIcon.png"
if [ -f "$ICON_PNG" ]; then
    ICON_SET="$(dirname "$0")/Resources/Assets.xcassets/AppIcon.appiconset"
    echo -e "${GREEN}发现 App 图标，正在刷新 macOS Asset Catalog...${NC}"
    mkdir -p "$ICON_SET"
    
    sips -s format png -z 16 16     "$ICON_PNG" --out "$ICON_SET/icon_16x16.png" > /dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out "$ICON_SET/icon_16x16@2x.png" > /dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out "$ICON_SET/icon_32x32.png" > /dev/null 2>&1
    sips -s format png -z 64 64     "$ICON_PNG" --out "$ICON_SET/icon_32x32@2x.png" > /dev/null 2>&1
    sips -s format png -z 128 128   "$ICON_PNG" --out "$ICON_SET/icon_128x128.png" > /dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out "$ICON_SET/icon_128x128@2x.png" > /dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out "$ICON_SET/icon_256x256.png" > /dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out "$ICON_SET/icon_256x256@2x.png" > /dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out "$ICON_SET/icon_512x512.png" > /dev/null 2>&1
    sips -s format png -z 1024 1024 "$ICON_PNG" --out "$ICON_SET/icon_512x512@2x.png" > /dev/null 2>&1
    echo -e "${GREEN}Asset Catalog 图标刷新完成。${NC}"
fi

# 2. 调用 XcodeGen 重新生成最新工程
echo -e "${YELLOW}正在刷新并生成 Xcode 工程...${NC}"
xcodegen generate

# 3. 运行 xcodebuild 编译归档
rm -rf build/CreditCardMac.xcarchive
if [ "${CLOUDKIT_SIGNED_BUILD:-0}" = "1" ]; then
    if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
        echo -e "${RED}CLOUDKIT_SIGNED_BUILD=1 时必须提供 DEVELOPMENT_TEAM，CloudKit 不能使用 ad-hoc 签名验证。${NC}"
        exit 1
    fi
    echo -e "${YELLOW}正在生成带 CloudKit entitlement 的签名归档...${NC}"
    run_xcodebuild_archive xcodebuild archive \
        -project CreditCardMac.xcodeproj \
        -scheme CreditCardMac \
        -destination "generic/platform=macOS" \
        -archivePath ./build/CreditCardMac.xcarchive \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        CODE_SIGN_STYLE=Automatic
else
    echo -e "${YELLOW}正在编译离线归档；此产物不具备真实 iCloud/CloudKit 验证能力。${NC}"
    run_xcodebuild_archive xcodebuild archive \
        -project CreditCardMac.xcodeproj \
        -scheme CreditCardMac \
        -destination "generic/platform=macOS" \
        -archivePath ./build/CreditCardMac.xcarchive \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGN_ENTITLEMENTS=""
fi

# 4. 提取生成的 .app 包到规范输出目录 dist/
APP_PATH="./build/CreditCardMac.xcarchive/Products/Applications/CreditCardMac.app"
if [ -d "$APP_PATH" ]; then
    echo -e "${GREEN}编译成功！正在提取并规范部署应用程序至 dist/ 目录...${NC}"
    mkdir -p ./dist
    DIST_APP_PATH="./dist/卡包.app"
    rm -rf "$DIST_APP_PATH"
    cp -R "$APP_PATH" "$DIST_APP_PATH"

    # 离线构建使用 Ad-Hoc 签名便于本地打开；CloudKit 签名归档不得被覆盖。
    if [ "${CLOUDKIT_SIGNED_BUILD:-0}" != "1" ] && command -v codesign >/dev/null 2>&1; then
        echo -e "${GREEN}正在为可执行程序施加 Ad-Hoc 本地代码签名 (Ad-Hoc Code Signing)...${NC}"
        codesign --force --deep --sign - "$DIST_APP_PATH" > /dev/null 2>&1
        echo -e "${GREEN}本地临时自签名注入成功！${NC}"
    fi
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}🎉 恭喜！macOS 原生客户端一键打包构建成功！${NC}"
    echo -e "${GREEN}📁 规范应用程序物理路径: $(pwd)/dist/卡包.app${NC}"
    echo -e "${YELLOW}👉 体验方式：您现在可以直接在 Finder 中双击 dist/ 目录下的 '卡包.app' 进行无感运行体验！${NC}"
    echo -e "${GREEN}================================================${NC}"
else
    echo -e "${RED}❌ 提取编译包失败，归档未能成功生成，请检查 Xcode 编译日志。${NC}"
    exit 1
fi
