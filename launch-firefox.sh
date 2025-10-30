#!/bin/bash

LOG_FILE="/tmp/ff_launch.log"
echo "--- Firefox Launch Script Started at $(date) ---" > $LOG_FILE

# Cookie 注入逻辑
# 检查 base64 编码的 Cookie 变量是否存在
if [ -n "$WEBSITE_COOKIE_B64" ]; then
  # 解码 Cookie 字符串
  WEBSITE_COOKIE_STRING=$(echo "$WEBSITE_COOKIE_B64" | base64 -d)
  echo "Found Cookie String. Attempting to inject multiple cookies." >> $LOG_FILE
  
  # 步骤 1: 确保 Firefox 配置文件存在
  echo "Ensuring Firefox profile exists..." >> $LOG_FILE
  firefox --headless &
  sleep 3
  pkill firefox
  sleep 1
  
  # 步骤 2: 找到配置文件目录和 cookie 数据库路径
  PROFILE_DIR=$(find /home/headless/.mozilla/firefox -name "*.default-release")
  COOKIE_DB_PATH="${PROFILE_DIR}/cookies.sqlite"
  
  # 步骤 3: 从 URL 中提取主域名，用于设置 Cookie
  if [ -n "$URL" ] && [ -f "$COOKIE_DB_PATH" ]; then
    # 例如: 从 "https://www.gaoding.art/design" 提取出 ".gaoding.art"
    HOSTNAME=$(echo "$URL" | awk -F/ '{print $3}')
    COOKIE_DOMAIN=".${HOSTNAME#www.}"
    echo "Found cookie database at: $COOKIE_DB_PATH" >> $LOG_FILE
    echo "Cookies will be set for domain: $COOKIE_DOMAIN" >> $LOG_FILE

    # 步骤 4: 循环注入每一个 Cookie
    # 将分号替换为换行符，以便逐行读取
    echo "$WEBSITE_COOKIE_STRING" | tr ';' '\n' | while read -r cookie; do
      # 去除前导空格
      cookie=$(echo "$cookie" | sed 's/^[ \t]*//')
      
      # 跳过空行
      [ -z "$cookie" ] && continue

      # 分割 cookie 名和值
      COOKIE_NAME=$(echo "$cookie" | cut -d'=' -f1)
      COOKIE_VALUE=$(echo "$cookie" | cut -d'=' -f2-) # f2- 支持值中包含等号

      # 删除旧的同名 cookie
      sqlite3 "$COOKIE_DB_PATH" "DELETE FROM moz_cookies WHERE name = '${COOKIE_NAME}' AND host = '${COOKIE_DOMAIN}';"
      
      # 插入新的 cookie
      EXPIRY_TIME=$(($(date +%s) + 31536000)) # 1年后过期
      CREATION_TIME=$(date +%s)
      
      echo "Injecting cookie: ${COOKIE_NAME}" >> $LOG_FILE
      sqlite3 "$COOKIE_DB_PATH" "INSERT INTO moz_cookies (name, value, host, path, expiry, creationTime, isSecure, isHttpOnly, inBrowserElement, sameSite) VALUES ('${COOKIE_NAME}', '${COOKIE_VALUE}', '${COOKIE_DOMAIN}', '/', ${EXPIRY_TIME}, ${CREATION_TIME}000000, 1, 1, 0, 1);"
    done
    echo "All cookies injected successfully." >> $LOG_FILE
  else
    echo "ERROR: Cookie database or URL not found! Skipping injection." >> $LOG_FILE
  fi
fi

# 等待桌面环境就绪
echo "Waiting for desktop environment..." >> $LOG_FILE
sleep 8

# 启动 Firefox
if [ -z "${URL}" ]; then
  echo "URL not set. Launching Firefox with default page." >> $LOG_FILE
  firefox &
else
  echo "Launching Firefox with URL: ${URL}" >> $LOG_FILE
  firefox --new-window "${URL}" &
fi
