#!/bin/bash

# ==============================================================================
# Android 原生卡包客户端 ── Release 自动打包脚本
# ==============================================================================

# 确保在脚本出错时立即停止执行
set -e

# 定义高亮输出颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}🚀 开始执行 Android 原生卡包客户端 Release 自动打包${NC}"
echo -e "${YELLOW}====================================================${NC}"

# 1. 自动检测并修复 Java 环境 (JAVA_HOME)
echo -e "\n🔍 正在检查本地 Java (JDK) 运行环境..."
if [ -x "/usr/libexec/java_home" ]; then
    if /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
        export JAVA_HOME=$(/usr/libexec/java_home -v 17)
    else
        export JAVA_HOME=$(/usr/libexec/java_home)
    fi
    echo -e "${GREEN}✅ 已自动匹配到系统 JDK 路径: $JAVA_HOME${NC}"
else
    if [ -z "$JAVA_HOME" ]; then
        echo -e "${RED}❌ 错误: 未检测到 JAVA_HOME 环境变量，请先安装 Java JDK (推荐 JDK 17)${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ 使用预设的 JDK 路径: $JAVA_HOME${NC}"
    fi
fi

# 2. 清理历史构建缓存，确保代码完全重编译
echo -e "\n🧹 正在清理历史构建缓存..."
./gradlew clean

# 3. 开始进行 Release 安装包编译打包
echo -e "\n📦 正在编译打包 Release 版本的安装包 (assembleRelease)..."
./gradlew assembleRelease

# 4. 建立独立的 releases 目录并拷贝打包出的 APK 文件
APK_PATH="app/build/outputs/apk/release/app-release-unsigned.apk"

# 兼容有些 Gradle 升级后输出带签名或不带签名的变体情况
if [ ! -f "$APK_PATH" ]; then
    # 尝试寻找 outputs 下任何 .apk 文件
    FOUND_APK=$(find app/build/outputs/apk/release -name "*.apk" | head -n 1)
    if [ -n "$FOUND_APK" ]; then
        APK_PATH="$FOUND_APK"
    fi
fi

if [ -f "$APK_PATH" ]; then
    echo -e "\n${GREEN}🎉 编译打包大功告成！${NC}"
    # 确保根目录下的 releases 专用目录存在 (已被 git 忽略)
    mkdir -p releases
    # 每次打包成功后，删除以前的旧打包文件，只保留本次最新的打包文件
    echo -e "🧹 正在清理 releases 目录下的历史打包文件..."
    rm -f ./releases/*
    
    TIMESTAMP=$(date +"%m%d-%H%M")
    UNIQUE_APK_NAME="CardWallet-Release-${TIMESTAMP}.apk"
    cp "$APK_PATH" ./releases/CardWallet-Release.apk
    cp "$APK_PATH" "./releases/${UNIQUE_APK_NAME}"
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}👑 您的 Release 安装包已安全拷贝至专有 releases 目录：${NC}"
    echo -e "${GREEN}👉 默认包: [CardWallet-Release.apk](${PWD}/releases/CardWallet-Release.apk)${NC}"
    echo -e "${GREEN}👉 唯一时间戳防缓存包: [${UNIQUE_APK_NAME}](${PWD}/releases/${UNIQUE_APK_NAME})${NC}"
    echo -e "${GREEN}====================================================${NC}"
    echo -e "💡 终极调试提示：为了彻底避开手机端（如微信/QQ/手机文件管理器）的同名文件传输与安装包缓存天坑，建议您在发送和安装时，【首选带时间戳的唯一包 ${UNIQUE_APK_NAME}】进行安装！"
else
    echo -e "\n${RED}❌ 错误: 未能在编译输出目录找到打包后的 APK 文件，请检查 Gradle 日志。${NC}"
    exit 1
fi
