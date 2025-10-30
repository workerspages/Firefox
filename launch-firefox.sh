#!/bin/bash

LOG_FILE="/tmp/ff_launch.log"
echo "--- Firefox Launch Script Started at $(date) ---" > $LOG_FILE

# 加载由 entrypoint 注入的环境变量
if [ -f /etc/profile.d/custom_env.sh ]; then
  source /etc/profile.d/custom_env.sh
  echo "Loaded custom environment variables." >> $LOG_FILE
fi

# Cookie 注入逻辑
if [ -n "$WEBSITE_COOKIE_JSON" ]; then
  echo "Found WEBSITE_COOKIE_JSON variable. Attempting to inject cookie." >> $LOG_FILE
  
  # 步骤 1: 确保 Firefox 配置文件存在
  # 短暂地无头运行 Firefox 会强制创建配置文件和数据库结构
  echo "Ensuring Firefox profile exists..." >> $LOG_FILE
  firefox --headless &
  sleep 3
  pkill firefox
  sleep 1
  
  # 步骤 2: 找到配置文件目录和 cookie 数据库路径
  PROFILE_DIR=$(find /home/headless/.mozilla/firefox -name "*.default-release")
  COOKIE_DB_PATH="${PROFILE_DIR}/cookies.sqlite"
  
  if [ -f "$COOKIE_DB_PATH" ]; then
    echo "Found cookie database at: $COOKIE_DB_PATH" >> $LOG_FILE
    
    # 步骤 3: 使用 jq 解析 JSON
    # 注意：我们假设 JSON 格式是 {"name":"...", "value":"...", "domain":"...", "path":"/"}
    COOKIE_NAME=$(echo $WEBSITE_COOKIE_JSON | jq -r '.name')
    COOKIE_VALUE=$(echo $WEBSITE_COOKIE_JSON | jq -r '.value')
    COOKIE_DOMAIN=$(echo $WEBSITE_COOKIE_JSON | jq -r '.domain')
    COOKIE_PATH=$(echo $WEBSITE_COOKIE_JSON | jq -r '.path')
    
    # 步骤 4: 从数据库中删除旧的同名 cookie，以确保能成功更新
    echo "Deleting old cookie with name: $COOKIE_NAME" >> $LOG_FILE
    sqlite3 $COOKIE_DB_PATH "DELETE FROM moz_cookies WHERE name = '${COOKIE_NAME}' AND host = '${COOKIE_DOMAIN}';"
    
    # 步骤 5: 插入新的 cookie
    # expiry 和 creationTime 使用当前的 Unix 时间戳 + 1年
    EXPIRY_TIME=$(($(date +%s) + 31536000))
    CREATION_TIME=$(date +%s)
    
    echo "Inserting new cookie..." >> $LOG_FILE
    sqlite3 $COOKIE_DB_PATH "INSERT INTO moz_cookies (name, value, host, path, expiry, creationTime, isSecure, isHttpOnly, inBrowserElement, sameSite) VALUES ('${COOKIE_NAME}', '${COOKIE_VALUE}', '${COOKIE_DOMAIN}', '${COOKIE_PATH}', ${EXPIRY_TIME}, ${CREATION_TIME}000000, 1, 1, 0, 1);"
    
    echo "Cookie injection complete." >> $LOG_FILE
  else
    echo "ERROR: Cookie database not found!" >> $LOG_FILE
  fi
fi

# 等待桌面环境就绪
echo "Waiting for desktop environment..." >> $LOG_FILE
sleep 5

# 启动 Firefox
if [ -z "${URL}" ]; then
  echo "URL not set. Launching Firefox with default page." >> $LOG_FILE
  firefox &
else
  echo "Launching Firefox with URL: ${URL}" >> $LOG_FILE
  firefox --new-window "${URL}" &
fi
