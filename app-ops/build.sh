#!/bin/bash

USER_HOME="/home/app"
FINAL_JAR_NAME="app.jar"
WORKSPACE_ROOT="${USER_HOME}/build/workspace"
TARGET_ARTIFACT="${WORKSPACE_ROOT}/target/${FINAL_JAR_NAME}"

GIT_REPO_URL=""

JAVA_HOME="${USER_HOME}/soft/jdk8"
MAVEN_HOME="${USER_HOME}/soft/maven"
M2_CMD="${MAVEN_HOME}/bin/mvn"

mkdir -p "${WORKSPACE_ROOT}"

git_fetch() {
    echo "--- 代码克隆 ---"
    if [ ! -d "${WORKSPACE_ROOT}" ]; then
        echo "代码目录不存在，执行克隆..."
        cd "${WORKSPACE_ROOT}" || exit 1
        git clone "${GIT_REPO_URL}" "${WORKSPACE_ROOT}"
    fi

    cd "${WORKSPACE_ROOT}" || exit 1
    git fetch origin

    echo "--- 分支选择 ---"
    BRANCHES=($(git branch -r | grep -v 'HEAD' | sed 's/^[[:space:]]*origin\///'))

    for i in "${!BRANCHES[@]}"; do
        echo "$((i+1)). ${BRANCHES[$i]}"
    done

    while true; do
        read -r -p "输入要部署的分支序号: " BRANCH_NUM
        if [[ "${BRANCH_NUM}" =~ ^[0-9]+$ ]] && [ "${BRANCH_NUM}" -ge 1 ] && [ "${BRANCH_NUM}" -le "${#BRANCHES[@]}" ]; then
            GIT_BRANCH="${BRANCHES[$((BRANCH_NUM-1))]}"
            break
        else
            echo "输入无效，请重新输入序号。"
        fi
    done

    echo "已选择分支: ${GIT_BRANCH}"

    git reset --hard -q
    git clean -dfq
    git checkout "${GIT_BRANCH}" -q
    git pull origin "${GIT_BRANCH}" -q

    if [ $? -ne 0 ]; then
        echo "错误: Git 操作失败。"
        return 1
    fi
    echo "代码更新完成。"
    echo ""

    echo "--- 最近一次提交记录 ---"
    git log -1 --pretty=format:"%h - %an, %ar : %s"
    echo ""
}

maven_build() {
    echo "--- Maven 打包 ---"

    if [ ! -d "${WORKSPACE_ROOT}" ]; then
        echo "错误: 项目代码目录 ${WORKSPACE_ROOT} 不存在。"
        return 1
    fi
    if [ ! -f "${M2_CMD}" ]; then
        echo "错误: Maven 命令 ${M2_CMD} 不存在。"
        return 1
    fi

    cd "${WORKSPACE_ROOT}" || exit 1

    echo "执行 Maven 打包 ..."
    "${M2_CMD}" clean package -DskipTests -q -B

    if [ $? -ne 0 ]; then
        echo "错误: Maven 打包失败。"
        return 1
    fi

    if [ ! -f "${TARGET_ARTIFACT}" ]; then
        echo "错误: 目标产物 ${TARGET_ARTIFACT} 未找到，请检查 pom.xml。"
        return 1
    fi

    echo "Maven 打包成功，产物路径: ${TARGET_ARTIFACT}"
}

git_fetch
maven_build
