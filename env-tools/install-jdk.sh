#!/bin/bash
# 脚本名称: install-jdk.sh
# 功能: 安装 Temurin JDK 并设置 JAVA_HOME
# 用法: ./install-jdk.sh <版本号: 8, 17, 21>

INSTALL_DIR="$HOME/soft"
TEMP_FILE_BASE="jdk"
PROFILE_FILE="$HOME/.bashrc"
if [ -f "$HOME/.zshrc" ]; then
    PROFILE_FILE="$HOME/.zshrc"
fi
GENERIC_START="# === START MANAGED JDK CONFIG (By install-jdk.sh) ==="
GENERIC_END="# === END MANAGED JDK CONFIG (By install-jdk.sh) ==="

# 自动检测 OS 和 Architecture
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH_NAME=$(uname -m | tr '[:upper:]' '[:lower:]')

case "$OS_NAME" in
    linux*) API_OS="linux";;
    darwin*) API_OS="mac";;
    *) echo "错误: 不支持的操作系统 (${OS_NAME})。"; exit 1;;
esac

case "$ARCH_NAME" in
    x86_64|amd64) API_ARCH="x64";;
    aarch64|arm64) API_ARCH="aarch64";;
    *) echo "错误: 不支持的处理器架构 (${ARCH_NAME})。"; exit 1;;
esac

if [ -z "$1" ]; then
    echo "错误: 请指定要安装的 JDK 主版本 (8, 17, 或 21)。"
    exit 1
fi

JDK_MAJOR_VERSION="$1"
FINAL_DIR_NAME="jdk${JDK_MAJOR_VERSION}"
JDK_FINAL_PATH="$INSTALL_DIR/$FINAL_DIR_NAME"
TEMP_FILE="$TEMP_FILE_BASE-${JDK_MAJOR_VERSION}.tar.gz"

if [ -d "$JDK_FINAL_PATH" ]; then
    echo "JDK ${JDK_MAJOR_VERSION} 已存在。跳过下载和安装。"
else
    echo "正在下载并安装 Temurin JDK ${JDK_MAJOR_VERSION} (${API_OS}_${API_ARCH})..."

    if ! command -v curl > /dev/null; then
        echo "错误: 系统未安装 curl。"
        exit 1
    fi

    API_URL="https://api.adoptium.net/v3/binary/latest/${JDK_MAJOR_VERSION}/ga/${API_OS}/${API_ARCH}/jdk/hotspot/normal/adoptium"

    mkdir -p "$INSTALL_DIR"
    curl -Lo "$INSTALL_DIR/$TEMP_FILE" "$API_URL"

    if [ $? -ne 0 ] || [ ! -s "$INSTALL_DIR/$TEMP_FILE" ]; then
        echo "错误: JDK 下载失败。"
        rm -f "$INSTALL_DIR/$TEMP_FILE"
        exit 1
    fi

    tar -xzf "$INSTALL_DIR/$TEMP_FILE" -C "$INSTALL_DIR"
    rm "$INSTALL_DIR/$TEMP_FILE"

    EXTRACTED_DIR=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "jdk-${JDK_MAJOR_VERSION}*" -o -name "jdk${JDK_MAJOR_VERSION}*" | head -n 1)
    if [ -z "$EXTRACTED_DIR" ]; then
        echo "警告: 无法找到解压后的文件夹。"
        exit 1
    fi

    mv "$EXTRACTED_DIR" "$JDK_FINAL_PATH"
fi

CONFIG_BLOCK=$(cat << EOF
${GENERIC_START}
export JAVA_HOME="${JDK_FINAL_PATH}"
export PATH=\$JAVA_HOME/bin:\$PATH
${GENERIC_END}
EOF
)

if sed --version 2>/dev/null | grep -q 'GNU'; then
    sed -i "/${GENERIC_START}/,/${GENERIC_END}/d" "$PROFILE_FILE"
else
    sed -i '' "/${GENERIC_START}/,/${GENERIC_END}/d" "$PROFILE_FILE"
fi

echo "$CONFIG_BLOCK" >> "$PROFILE_FILE"

echo "-------------------------------------------------"
echo "JDK ${JDK_MAJOR_VERSION} 安装配置完成!"
echo "请执行 'source ${PROFILE_FILE}' 使其生效。"
echo "-------------------------------------------------"