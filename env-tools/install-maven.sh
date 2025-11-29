#!/bin/bash
# 脚本名称: install-maven-complete.sh
# 功能: 完整安装 Apache Maven 并配置内部镜像。

INSTALL_DIR="$HOME/soft"
FINAL_DIR_NAME="maven"
MAVEN_FINAL_PATH="$INSTALL_DIR/$FINAL_DIR_NAME"
MAVEN_DOWNLOAD_PAGE="https://maven.apache.org/download.cgi"
TEMP_FILE="maven.tar.gz"
PROFILE_FILE="$HOME/.bashrc"
if [ -f "$HOME/.zshrc" ]; then
    PROFILE_FILE="$HOME/.zshrc"
fi
MAVEN_START="# === START APACHE MAVEN CONFIG (Managed by install-maven-complete.sh) ==="
MAVEN_END="# === END APACHE MAVEN CONFIG (Managed by install-maven-complete.sh) ==="

MAVEN_MIRROR_URL="http://172.23.23.10:51001/repository/maven-public"
MAVEN_USER_CONFIG_DIR="$HOME/.m2"
MAVEN_USER_CONFIG_FILE="$MAVEN_USER_CONFIG_DIR/settings.xml"


echo "-------------------------------------------------"
echo "开始安装 Apache Maven..."
echo "-------------------------------------------------"

if [ -d "$MAVEN_FINAL_PATH" ]; then
    echo "Maven 已存在。跳过下载和解压。"
else
    if ! command -v curl > /dev/null; then
        echo "错误: 系统未安装 curl。"
        exit 1
    fi

    MAVEN_URL=$(
        curl -s $MAVEN_DOWNLOAD_PAGE | \
        grep -oP 'https?://dlcdn\.apache\.org/maven/maven-3/[0-9.]+/binaries/apache-maven-[0-9.]+-bin\.tar\.gz' | \
        head -n 1
    )

    if [ -z "$MAVEN_URL" ]; then
        echo "错误: 无法获取 Maven 下载链接。"
        exit 1
    fi

    MAVEN_VERSION=$(echo "$MAVEN_URL" | grep -oP 'maven-([0-9.]+)-bin.tar.gz$' | sed 's/maven-//; s/-bin.tar.gz//')
    echo "正在安装 Maven ${MAVEN_VERSION}..."

    mkdir -p "$INSTALL_DIR"
    curl -Lo "$INSTALL_DIR/$TEMP_FILE" "$MAVEN_URL"

    if [ $? -ne 0 ]; then
        echo "错误: Maven 下载失败。"
        rm -f "$INSTALL_DIR/$TEMP_FILE"
        exit 1
    fi

    tar -xzf "$INSTALL_DIR/$TEMP_FILE" -C "$INSTALL_DIR"
    rm "$INSTALL_DIR/$TEMP_FILE"

    EXTRACTED_DIR=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "apache-maven-*" | head -n 1)

    if [ -z "$EXTRACTED_DIR" ]; then
        echo "警告: 无法找到解压后的 Maven 文件夹。"
        exit 1
    fi

    mv "$EXTRACTED_DIR" "$MAVEN_FINAL_PATH"
fi


# 设置并清理环境变量
CONFIG_BLOCK=$(cat << EOF
${MAVEN_START}
export MAVEN_HOME="${MAVEN_FINAL_PATH}"
export PATH=\$MAVEN_HOME/bin:\$PATH
${MAVEN_END}
EOF
)

if sed --version 2>/dev/null | grep -q 'GNU'; then
    sed -i "/${MAVEN_START}/,/${MAVEN_END}/d" "$PROFILE_FILE"
else
    sed -i '' "/${MAVEN_START}/,/${MAVEN_END}/d" "$PROFILE_FILE"
fi

echo "$CONFIG_BLOCK" >> "$PROFILE_FILE"


# 配置内部镜像仓库
mkdir -p "$MAVEN_USER_CONFIG_DIR"

echo "正在生成 settings.xml 并配置镜像 ${MAVEN_MIRROR_URL}..."

cat << EOF > "$MAVEN_USER_CONFIG_FILE"
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              https://maven.apache.org/xsd/settings-1.0.0.xsd">

  <mirrors>
    <mirror>
      <id>nexus-mirror</id>
      <name>Nexus Mirror</name>
      <url>${MAVEN_MIRROR_URL}</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>
</settings>
EOF

if [ $? -ne 0 ]; then
    echo "错误: 生成 settings.xml 文件失败。"
    exit 1
fi

echo "-------------------------------------------------"
echo "Maven 安装和配置完成!"
echo "请执行 'source ${PROFILE_FILE}' 使新配置生效。"
echo "-------------------------------------------------"