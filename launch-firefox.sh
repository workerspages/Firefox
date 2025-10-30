#!/bin/bash

LOG_FILE="/tmp/ff_launch.log"
ENV_FILE="/tmp/custom_env.sourceme"
echo "--- Firefox Launch Script Started at $(date) ---" > $LOG_FILE

# 【核心修改】主动加载我们定义的环境变量文件
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
  echo "Successfully loaded environment variables from $ENV_FILE." >> $LOG_FILE
else
  echo "ERROR: Environment file $ENV_FILE not found!" >> $LOG_FILE
fi

# Cookie 注入逻辑
if [ -n "$WEBSITE_COOKIE_B64" ]; then
  WEBSITE_COOKIE_STRING=$(echo "$WEBSITE_COOKIE_B64" | base64 -d)
  echo "Found Cookie String. Attempting to inject." >> $LOG_FILE
  
  echo "Ensuring Firefox profile exists..." >> $LOG_FILE
  firefox --headless &
  sleep 3
  pkill firefox
  sleep 1
  
  PROFILE_DIR=$(find /home/headless/.mozilla/firefox -name "*.default-release")
  COOKIE_DB_PATH="${PROFILE_DIR}/cookies.sqlite"
  
  if [ -n "$URL" ] && [ -f "$COOKIE_DB_PATH" ]; then
    HOSTNAME=$(echo "$URL" | awk -F/ '{print $3}')
    COOKIE_DOMAIN=".${HOSTNAME#www.}"
    echo "Found cookie DB at: $COOKIE_DB_PATH" >> $LOG_FILE
    echo "Setting cookies for domain: $COOKIE_DOMAIN" >> $LOG_FILE

    echo "$WEBSITE_COOKIE_STRING" | tr ';' '\n' | while read -r cookie; do
      cookie=$(echo "$cookie" | sed 's/^[ \t]*//')
      [ -z "$cookie" ] && continue

      COOKIE_NAME=$(echo "$cookie" | cut -d'=' -f1)
      COOKIE_VALUE_RAW=$(echo "$cookie" | cut -d'=' -f2-)
      COOKIE_VALUE_ESCAPED=$(echo "$COOKIE_VALUE_RAW" | sed "s/'/''/g")
      
      sqlite3 "$COOKIE_DB_PATH" "DELETE FROM moz_cookies WHERE name = '${COOKIE_NAME}' AND host = '${COOKIE_DOMAIN}';"
      
      EXPIRY_TIME=$(($(date +%s) + 31536000))
      CREATION_TIME=$(date +%s)
      
      echo "Injecting cookie: ${COOKIE_NAME}" >> $LOG_FILE
      sqlite3 "$COOKIE_DB_PATH" "INSERT INTO moz_cookies (name, value, host, path, expiry, creationTime, isSecure, isHttpOnly, inBrowserElement, sameSite) VALUES ('${COOKIE_NAME}', '${COOKIE_VALUE_ESCAPED}', '${COOKIE_DOMAIN}', '/', ${EXPIRY_TIME}, ${CREATION_TIME}000000, 1, 1, 0, 1);"
    done
    echo "All cookies injected successfully." >> $LOG_FILE
  else
    echo "ERROR: Cookie database or URL not found! Skipping injection." >> $LOG_FILE
  fi
fi

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
