#!/bin/bash

LOG_FILE="/tmp/ff_launch.log"
echo "--- Firefox Launch Script Started at $(date) ---" > $LOG_FILE
echo "Reading environment variables loaded by the system..." >> $LOG_FILE

# Cookie 注入逻辑 (保持不变)
if [ -n "$WEBSITE_COOKIE_JSON" ]; then
  echo "Found WEBSITE_COOKIE_JSON. Attempting to inject cookie." >> $LOG_FILE
  
  echo "Ensuring Firefox profile exists..." >> $LOG_FILE
  firefox --headless &
  sleep 3
  pkill firefox
  sleep 1
  
  PROFILE_DIR=$(find /home/headless/.mozilla/firefox -name "*.default-release")
  COOKIE_DB_PATH="${PROFILE_DIR}/cookies.sqlite"
  
  if [ -f "$COOKIE_DB_PATH" ]; then
    echo "Found cookie database at: $COOKIE_DB_PATH" >> $LOG_FILE
    COOKIE_NAME=$(echo $WEBSITE_COOKIE_JSON | jq -r '.name')
    COOKIE_VALUE=$(echo $WEBSITE_COOKIE_JSON | jq -r '.value')
    COOKIE_DOMAIN=$(echo $WEBSITE_COOKIE_JSON | jq -r '.domain')
    COOKIE_PATH=$(echo $WEBSITE_COOKIE_JSON | jq -r '.path')
    
    sqlite3 $COOKIE_DB_PATH "DELETE FROM moz_cookies WHERE name = '${COOKIE_NAME}' AND host = '${COOKIE_DOMAIN}';"
    
    EXPIRY_TIME=$(($(date +%s) + 31536000))
    CREATION_TIME=$(date +%s)
    
    sqlite3 $COOKIE_DB_PATH "INSERT INTO moz_cookies (name, value, host, path, expiry, creationTime, isSecure, isHttpOnly, inBrowserElement, sameSite) VALUES ('${COOKIE_NAME}', '${COOKIE_VALUE}', '${COOKIE_DOMAIN}', '${COOKIE_PATH}', ${EXPIRY_TIME}, ${CREATION_TIME}000000, 1, 1, 0, 1);"
    echo "Cookie injection complete." >> $LOG_FILE
  else
    echo "ERROR: Cookie database not found!" >> $LOG_FILE
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
