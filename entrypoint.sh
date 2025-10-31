#!/bin/bash
set -e

LOG_FILE="/tmp/ff_launch.log"
echo "=== Entrypoint Started at $(date) ===" > "$LOG_FILE"

# --- 步骤 1: 设置环境变量 ---
ENV_FILE="/tmp/custom_env.sourceme"
echo "#!/bin/bash" > "$ENV_FILE"

if [ -n "$URL" ]; then
  printf "export URL=%q\n" "$URL" >> "$ENV_FILE"
  echo "URL set: $URL" >> "$LOG_FILE"
fi

if [ -n "$WEBSITE_COOKIE_STRING" ]; then
  COOKIE_B64=$(echo -n "$WEBSITE_COOKIE_STRING" | base64 -w 0)
  printf "export WEBSITE_COOKIE_B64=%q\n" "$COOKIE_B64" >> "$ENV_FILE"
  echo "Cookie encoded (length: ${#WEBSITE_COOKIE_STRING})" >> "$LOG_FILE"
fi

chmod 644 "$ENV_FILE"

# --- 步骤 2: 后台任务 ---
(
  echo "=== Background task started at $(date) ===" >> "$LOG_FILE"
  
  # 等待 VNC
  echo "Waiting for desktop environment (20 seconds)..." >> "$LOG_FILE"
  sleep 20
  
  export DISPLAY=:1
  echo "DISPLAY set to: $DISPLAY" >> "$LOG_FILE"
  
  # 授权 X11 访问
  echo "Setting X11 permissions..." >> "$LOG_FILE"
  xhost +local:headless >> "$LOG_FILE" 2>&1 || true
  
  # 复制并设置 .Xauthority
  if [ -f /root/.Xauthority ]; then
    cp /root/.Xauthority /home/headless/.Xauthority
    chown headless:headless /home/headless/.Xauthority
    echo "Copied .Xauthority" >> "$LOG_FILE"
  fi
  
  # 加载环境变量
  source "$ENV_FILE"
  
  # 【关键】先确保 .mozilla 目录属于 headless
  mkdir -p /home/headless/.mozilla/firefox
  chown -R headless:headless /home/headless/.mozilla
  echo "Pre-created .mozilla directory with correct ownership" >> "$LOG_FILE"
  
  # 以 headless 用户创建 Firefox profile
  echo "Creating Firefox profile as headless user..." >> "$LOG_FILE"
  su - headless -c "timeout 10 firefox --headless" >> "$LOG_FILE" 2>&1 &
  PROFILE_PID=$!
  sleep 8
  kill -9 $PROFILE_PID 2>/dev/null || true
  pkill -9 firefox 2>/dev/null || true
  sleep 2
  
  # 再次确认权限（防止 root 创建了文件）
  chown -R headless:headless /home/headless/.mozilla
  echo "Confirmed .mozilla ownership" >> "$LOG_FILE"
  
  # 查找 profile
  PROFILE_DIR=$(find /home/headless/.mozilla/firefox -name "*.default-release" 2>/dev/null | head -n 1)
  
  if [ -z "$PROFILE_DIR" ]; then
    echo "ERROR: Firefox profile not found!" >> "$LOG_FILE"
  else
    echo "✓ Profile found: $PROFILE_DIR" >> "$LOG_FILE"
    
    # Cookie 注入
    if [ -n "$WEBSITE_COOKIE_B64" ] && [ -n "$URL" ]; then
      echo "Starting cookie injection..." >> "$LOG_FILE"
      
      WEBSITE_COOKIE_STRING=$(echo "$WEBSITE_COOKIE_B64" | base64 -d)
      COOKIE_DB_PATH="${PROFILE_DIR}/cookies.sqlite"
      
      if [ -f "$COOKIE_DB_PATH" ]; then
        echo "✓ Cookie database found" >> "$LOG_FILE"
        
        HOSTNAME=$(echo "$URL" | awk -F/ '{print $3}')
        COOKIE_DOMAIN=".${HOSTNAME#www.}"
        echo "Target domain: $COOKIE_DOMAIN" >> "$LOG_FILE"
        
        # 注入 Cookie
        echo "$WEBSITE_COOKIE_STRING" | tr ';' '\n' | while IFS= read -r cookie; do
          cookie=$(echo "$cookie" | sed 's/^[ \t]*//')
          [ -z "$cookie" ] && continue
          
          COOKIE_NAME=$(echo "$cookie" | cut -d'=' -f1)
          COOKIE_VALUE_RAW=$(echo "$cookie" | cut -d'=' -f2-)
          COOKIE_VALUE_ESCAPED=$(echo "$COOKIE_VALUE_RAW" | sed "s/'/''/g")
          
          sqlite3 "$COOKIE_DB_PATH" "DELETE FROM moz_cookies WHERE name = '${COOKIE_NAME}' AND host = '${COOKIE_DOMAIN}';" 2>/dev/null
          
          EXPIRY_TIME=$(($(date +%s) + 31536000))
          CREATION_TIME=$(date +%s)
          
          if sqlite3 "$COOKIE_DB_PATH" "INSERT INTO moz_cookies (name, value, host, path, expiry, creationTime, isSecure, isHttpOnly, inBrowserElement, sameSite) VALUES ('${COOKIE_NAME}', '${COOKIE_VALUE_ESCAPED}', '${COOKIE_DOMAIN}', '/', ${EXPIRY_TIME}, ${CREATION_TIME}000000, 1, 1, 0, 1);" 2>/dev/null; then
            echo "  ✓ ${COOKIE_NAME}" >> "$LOG_FILE"
          fi
        done
        
        TOTAL=$(sqlite3 "$COOKIE_DB_PATH" "SELECT COUNT(*) FROM moz_cookies WHERE host = '${COOKIE_DOMAIN}';" 2>/dev/null)
        echo "✓ Cookie injection completed: $TOTAL cookies for $COOKIE_DOMAIN" >> "$LOG_FILE"
        
        # 【关键】确保 Cookie 数据库属于 headless
        chown headless:headless "$COOKIE_DB_PATH"
      fi
    fi
  fi
  
  # 最后一次确认所有权限
  chown -R headless:headless /home/headless/.mozilla
  
  # 启动 Firefox
  sleep 3
  echo "Launching Firefox..." >> "$LOG_FILE"
  
  if [ -n "$URL" ]; then
    su - headless -c "DISPLAY=:1 firefox --new-window '$URL'" >> "$LOG_FILE" 2>&1 &
    echo "✓ Firefox launched with URL: $URL" >> "$LOG_FILE"
  else
    su - headless -c "DISPLAY=:1 firefox" >> "$LOG_FILE" 2>&1 &
    echo "✓ Firefox launched" >> "$LOG_FILE"
  fi
  
  sleep 3
  if pgrep -u headless firefox > /dev/null; then
    echo "✓ Firefox process confirmed running as headless user" >> "$LOG_FILE"
  else
    echo "✗ WARNING: Firefox process not found" >> "$LOG_FILE"
  fi
  
  echo "=== Background task completed at $(date) ===" >> "$LOG_FILE"
) &

BACKGROUND_PID=$!
echo "Background task started with PID: $BACKGROUND_PID" >> "$LOG_FILE"
echo "Starting VNC server..." >> "$LOG_FILE"

exec /dockerstartup/startup.sh "$@"
