#!/bin/bash

APP_PORT=7210
APP_PROFILE=dev

# --- 目录配置 ---
APP_ROOT_DIR="/home/app"
APP_NAME="myapp-service"

APP_DEPLOY_DIR="${APP_ROOT_DIR}/app"
APP_BACKUP_DIR="${APP_ROOT_DIR}/app_bak"
LOG_DIR="${APP_ROOT_DIR}/logs"
DUMP_DIR="${APP_ROOT_DIR}/dump"

APP_JAR_PATH="${APP_DEPLOY_DIR}/${APP_NAME}.jar"
LOG_FILE="${LOG_DIR}/${APP_NAME}.log"
NEW_JAR_PATH="${HOME}/${APP_NAME}.jar"

# --- Java 环境 ---
JAVA_HOME="/usr/local/java/jdk"
JAVA_CMD="${JAVA_HOME}/bin/java"
JPS_CMD="${JAVA_HOME}/bin/jps"

# --- 健康监测配置 ---
HEALTH_CHECK_URL="http://127.0.0.1:${APP_PORT}/actuator/health"
HEALTH_CHECK_TIMEOUT=5
MAX_HEALTH_CHECKS=20

# --- JVM 优化参数 ---
JAVA_MEM_OPTS="-Xms1024m -Xmx2048m"
JAVA_GC_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200"
JAVA_COMMON_OPTS="-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Shanghai"
JAVA_DEBUG_OPTS="-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${DUMP_DIR}/heapdump-$(date +%Y%m%d%H%M%S).hprof"

JAVA_OPTS="${JAVA_MEM_OPTS} ${JAVA_GC_OPTS} ${JAVA_COMMON_OPTS} ${JAVA_DEBUG_OPTS}"

# 应用参数
APP_ARGS="--server.port=${APP_PORT} --spring.profiles.active=${APP_PROFILE}"

# 创建必要的目录
mkdir -p "${LOG_DIR}" "${APP_DEPLOY_DIR}" "${APP_BACKUP_DIR}" "${DUMP_DIR}"

# 获取应用PID
get_pid() {
    echo $("${JPS_CMD}" -l | grep "${APP_JAR_PATH}" | awk '{print $1}')
}

# 状态函数
status() {
    PID=$(get_pid)
    if [ -n "${PID}" ]; then
        echo "正在检查 ${APP_NAME} (${PID}) 健康状态..."
        if curl -s -m "${HEALTH_CHECK_TIMEOUT}" "${HEALTH_CHECK_URL}" | grep -q 'UP'; then
            echo "  健康状态: UP"
            return 0
        else
            return 2
        fi
    else
        echo "${APP_NAME} 未运行。"
        return 1
    fi
}

# 启动函数
start() {
    if [ "$1" == "debug" ]; then
        LOG_REDIRECT="${LOG_FILE}"
        echo "以 DEBUG 模式启动，日志将输出到: ${LOG_FILE}"
    else
        LOG_REDIRECT="/dev/null"
    fi

    stop

    if [ ! -f "${APP_JAR_PATH}" ]; then
        echo "错误: 应用包 ${APP_JAR_PATH} 不存在。"
        return 1
    fi

    echo "启动 ${APP_NAME}..."

    FULL_CMD="${JAVA_CMD} ${JAVA_OPTS} -jar \"${APP_JAR_PATH}\" ${APP_ARGS}"
    echo "启动完整命令: ${FULL_CMD}"

    nohup "${JAVA_CMD}" ${JAVA_OPTS} -jar "${APP_JAR_PATH}" ${APP_ARGS} >> "${LOG_REDIRECT}" 2>&1 &

    echo "等待应用启动..."
    sleep 5

    for i in $(seq 1 "${MAX_HEALTH_CHECKS}"); do
        if status; then
            echo "启动成功! 尝试次数: ${i}"
            return 0
        fi
        sleep 5
    done

    echo "启动失败! 超过 ${MAX_HEALTH_CHECKS} 次尝试。请检查日志文件: ${LOG_FILE}"
    return 1
}

# 停止函数
stop() {
    PID=$(get_pid)
    if [ -n "${PID}" ]; then
        echo "正在停止 ${APP_NAME} (PID: ${PID})..."
        kill "${PID}"

        for i in {1..10}; do
            if ! kill -0 "${PID}" 2>/dev/null; then
                echo "停止完成。"
                return 0
            fi
            sleep 1
        done

        echo "停止失败，正在强制停止 (kill -9)..."
        kill -9 "${PID}"
        if kill -0 "${PID}" 2>/dev/null; then
            echo "错误: 强制停止失败。"
            return 1
        else
            echo "强制停止完成。"
            return 0
        fi
    else
        echo "${APP_NAME} 未运行。"
        return 0
    fi
}

# 部署函数
deploy() {
    if [ ! -f "$NEW_JAR_PATH" ]; then
        echo "错误: 新应用包文件不存在。"
        return 1
    fi

    stop

    if [ -f "${APP_JAR_PATH}" ]; then
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        BACKUP_FILE="${APP_BACKUP_DIR}/${APP_NAME}.jar.${TIMESTAMP}"
        echo "正在备份现有应用到 ${BACKUP_FILE}"
        mv "${APP_JAR_PATH}" "${BACKUP_FILE}"
    fi

    echo "正在部署新应用: ${NEW_JAR_PATH} -> ${APP_JAR_PATH}"
    mv "${NEW_JAR_PATH}" "${APP_JAR_PATH}"

    start
}

# 主执行逻辑
case "$1" in
    start)
        start "$2"
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        stop
        start
        ;;
    deploy)
        deploy
        ;;
    *)
        echo "用法: $0 {start [debug]|stop|status|restart|deploy}"
        exit 1
esac