#!/bin/bash
# 脚本名称: install-mvnd.sh
# 功能: 完整安装 Apache Maven Daemon (mvnd) 指定版本 1.0.3 并配置内部镜像。

INSTALL_DIR="$HOME/soft"
FINAL_DIR_NAME="mvnd"
MVND_FINAL_PATH="$INSTALL_DIR/$FINAL_DIR_NAME"
TEMP_FILE="mvnd.tar.gz"
PROFILE_FILE="$HOME/.bashrc"
if [ -f "$HOME/.zshrc" ]; then
    PROFILE_FILE="$HOME/.zshrc"
fi
MVND_START="# === START APACHE MVND CONFIG (Managed by install-mvnd.sh) ==="
MVND_END="# === END APACHE MVND CONFIG (Managed by install-mvnd.sh) ==="

MVND_MIRROR_URL="http://172.23.23.10:51001/repository/maven-public"
MVND_USER_CONFIG_DIR="$HOME/.m2"
MVND_USER_CONFIG_FILE="$MVND_USER_CONFIG_DIR/settings.xml"

# 指定安装版本
MVND_VERSION="1.0.3"

echo "-------------------------------------------------"
echo "开始安装 Apache Maven Daemon (mvnd) 版本 ${MVND_VERSION}..."
echo "-------------------------------------------------"

# 检测操作系统和架构
OS_TYPE=""
ARCH_TYPE=""

case "$(uname -s)" in
    Linux*)     OS_TYPE="linux" ;;
    Darwin*)    OS_TYPE="darwin" ;;
    CYGWIN*)    OS_TYPE="windows" ;;
    MINGW*)     OS_TYPE="windows" ;;
    *)          OS_TYPE="unknown" ;;
esac

case "$(uname -m)" in
    x86_64)     ARCH_TYPE="amd64" ;;
    aarch64)    ARCH_TYPE="aarch64" ;;
    arm64)      ARCH_TYPE="aarch64" ;;
    *)          ARCH_TYPE="unknown" ;;
esac

if [ "$OS_TYPE" = "unknown" ] || [ "$ARCH_TYPE" = "unknown" ]; then
    echo "错误: 不支持的操作系统或架构: $(uname -s) $(uname -m)"
    exit 1
fi

if [ -d "$MVND_FINAL_PATH" ]; then
    echo "Maven Daemon (mvnd) 已存在。跳过下载和解压。"
else
    if ! command -v curl > /dev/null; then
        echo "错误: 系统未安装 curl。"
        exit 1
    fi

    # 构建指定版本的下载URL
    MVND_URL="https://github.com/apache/maven-mvnd/releases/download/${MVND_VERSION}/maven-mvnd-${MVND_VERSION}-${OS_TYPE}-${ARCH_TYPE}.tar.gz"

    echo "正在安装 Maven Daemon ${MVND_VERSION} (${OS_TYPE}-${ARCH_TYPE})..."
    echo "下载URL: $MVND_URL"

    mkdir -p "$INSTALL_DIR"

    # 下载指定版本
    echo "正在下载 mvnd ${MVND_VERSION}..."
    curl -Lo "$INSTALL_DIR/$TEMP_FILE" "$MVND_URL"

    if [ $? -ne 0 ]; then
        echo "错误: Maven Daemon 版本 ${MVND_VERSION} 下载失败。"
        echo "请检查版本号是否正确或网络连接是否正常。"
        rm -f "$INSTALL_DIR/$TEMP_FILE"
        exit 1
    fi

    # 检查下载文件是否有效
    if ! tar -tzf "$INSTALL_DIR/$TEMP_FILE" > /dev/null 2>&1; then
        echo "错误: 下载的文件损坏或格式不正确。"
        rm -f "$INSTALL_DIR/$TEMP_FILE"
        exit 1
    fi

    # 解压文件
    echo "正在解压文件..."
    tar -xzf "$INSTALL_DIR/$TEMP_FILE" -C "$INSTALL_DIR"
    rm "$INSTALL_DIR/$TEMP_FILE"

    EXTRACTED_DIR=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "maven-mvnd-*" | head -n 1)

    if [ -z "$EXTRACTED_DIR" ]; then
        echo "错误: 无法找到解压后的 mvnd 文件夹。"
        exit 1
    fi

    mv "$EXTRACTED_DIR" "$MVND_FINAL_PATH"
    echo "mvnd ${MVND_VERSION} 解压完成。"
fi

# 设置并清理环境变量
CONFIG_BLOCK=$(cat << EOF
${MVND_START}
export MVND_HOME="${MVND_FINAL_PATH}"
export MVN_HOME="${MVND_FINAL_PATH}/mvn"
export PATH=\$MVND_HOME/bin:\$MVN_HOME/bin:\$PATH
${MVND_END}
EOF
)

# 清理已有的配置
echo "正在配置环境变量..."
if sed --version 2>/dev/null | grep -q 'GNU'; then
    sed -i "/${MVND_START}/,/${MVND_END}/d" "$PROFILE_FILE"
else
    sed -i '' "/${MVND_START}/,/${MVND_END}/d" "$PROFILE_FILE"
fi

echo "$CONFIG_BLOCK" >> "$PROFILE_FILE"

# 配置内部镜像仓库
mkdir -p "$MVND_USER_CONFIG_DIR"

echo "正在生成 settings.xml 并配置镜像 ${MVND_MIRROR_URL}..."

cat << EOF > "$MVND_USER_CONFIG_FILE"
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              https://maven.apache.org/xsd/settings-1.0.0.xsd">

  <mirrors>
    <mirror>
      <id>nexus-mirror</id>
      <name>Nexus Mirror</name>
      <url>${MVND_MIRROR_URL}</url>
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
echo "Maven Daemon ${MVND_VERSION} 安装和配置完成!"
echo "请执行 source ${PROFILE_FILE} 使新配置生效。"
echo "-------------------------------------------------"