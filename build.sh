#!/bin/bash
set -e

# 设置输出颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "${YELLOW}=== 开始打包 macOS 原生信用卡管理客户端 ===${NC}"

# 1. 自动利用 sips 和 iconutil 生成系统级 .icns 图标
ICON_PNG="/Users/yuangy/.gemini/antigravity/brain/fef3b05a-cb7e-4268-8a5a-e5fd66a3bbbb/macos_app_icon_1779544958337.png"
if [ -f "$ICON_PNG" ]; then
    echo -e "${GREEN}发现精美 App 图标，开始制作 macOS 原生图标包 (.icns)...${NC}"
    mkdir -p build/AppIcon.iconset
    
    # 强制以 -s format png 输出真正的 PNG 图片，以避开 iconutil 校验失败
    sips -s format png -z 16 16     "$ICON_PNG" --out build/AppIcon.iconset/icon_16x16.png > /dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out build/AppIcon.iconset/icon_16x16@2x.png > /dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out build/AppIcon.iconset/icon_32x32.png > /dev/null 2>&1
    sips -s format png -z 64 64     "$ICON_PNG" --out build/AppIcon.iconset/icon_32x32@2x.png > /dev/null 2>&1
    sips -s format png -z 128 128   "$ICON_PNG" --out build/AppIcon.iconset/icon_128x128.png > /dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out build/AppIcon.iconset/icon_128x128@2x.png > /dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out build/AppIcon.iconset/icon_256x256.png > /dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out build/AppIcon.iconset/icon_256x256@2x.png > /dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out build/AppIcon.iconset/icon_512x512.png > /dev/null 2>&1
    sips -s format png -z 1024 1024 "$ICON_PNG" --out build/AppIcon.iconset/icon_512x512@2x.png > /dev/null 2>&1
    
    # 编译成原生图标文件
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
    echo -e "${GREEN}系统图标 (AppIcon.icns) 编译成功！${NC}"
fi

# 2. 调用 XcodeGen 重新生成最新工程
echo -e "${YELLOW}正在刷新并生成 Xcode 工程...${NC}"
xcodegen generate

# 3. 运行 xcodebuild 编译归档
echo -e "${YELLOW}正在编译归档并输出可执行包 (CODE_SIGNING_ALLOWED=NO)...${NC}"
rm -rf build/CreditCardMac.xcarchive
xcodebuild archive \
    -project CreditCardMac.xcodeproj \
    -scheme CreditCardMac \
    -archivePath ./build/CreditCardMac.xcarchive \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGN_ENTITLEMENTS="" \
    > /dev/null 2>&1

# 4. 提取生成的 .app 包到规范输出目录 dist/
APP_PATH="./build/CreditCardMac.xcarchive/Products/Applications/CreditCardMac.app"
if [ -d "$APP_PATH" ]; then
    echo -e "${GREEN}编译成功！正在提取并规范部署应用程序至 dist/ 目录...${NC}"
    mkdir -p ./dist
    rm -rf ./dist/CreditCardMac.app
    cp -R "$APP_PATH" ./dist/CreditCardMac.app
    
    # 5. 注入系统图标资产并配置 plist
    if [ -f "build/AppIcon.icns" ]; then
        echo -e "${GREEN}正在为应用注入专属 3D 霓虹卡标...${NC}"
        mkdir -p ./dist/CreditCardMac.app/Contents/Resources
        cp build/AppIcon.icns ./dist/CreditCardMac.app/Contents/Resources/AppIcon.icns
        
        # 强制配置 Info.plist 识别 AppIcon.icns
        plutil -replace CFBundleIconFile -string AppIcon ./dist/CreditCardMac.app/Contents/Info.plist
        # 触摸刷新访达缓存
        touch ./dist/CreditCardMac.app
    fi
    
    # 💡 6. 施加 Ad-Hoc 本地自签名，彻底解决未签名程序导致 macOS 钥匙串“始终允许”失效、频繁强制弹窗的严重可用性缺陷！
    if command -v codesign >/dev/null 2>&1; then
        echo -e "${GREEN}正在为可执行程序施加 Ad-Hoc 本地代码签名 (Ad-Hoc Code Signing)...${NC}"
        codesign --force --deep --sign - ./dist/CreditCardMac.app > /dev/null 2>&1
        echo -e "${GREEN}本地临时自签名注入成功！${NC}"
    fi
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}🎉 恭喜！macOS 原生客户端一键打包构建成功！${NC}"
    echo -e "${GREEN}📁 规范应用程序物理路径: $(pwd)/dist/CreditCardMac.app${NC}"
    echo -e "${YELLOW}👉 体验方式：您现在可以直接在 Finder 中双击 dist/ 目录下的 'CreditCardMac.app' 进行无感运行体验！${NC}"
    echo -e "${GREEN}================================================${NC}"
else
    echo -e "${RED}❌ 提取编译包失败，归档未能成功生成，请检查 Xcode 编译日志。${NC}"
    exit 1
fi
