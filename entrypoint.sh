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
  echo "Cookie encoded" >> "$LOG_FILE"
fi

chmod 644 "$ENV_FILE"

# --- 步骤 2: 后台任务 ---
(
  echo "=== Background task started at $(date) ===" >> "$LOG_FILE"
  
  # 等待 VNC
  echo "Waiting for desktop (20 seconds)..." >> "$LOG_FILE"
  sleep 20
  
  export DISPLAY=:1
  echo "DISPLAY set to: $DISPLAY" >> "$LOG_FILE"
  
  # 授权 X11
  xhost +local:headless >> "$LOG_FILE" 2>&1 || true
  
  if [ -f /root/.Xauthority ]; then
    cp /root/.Xauthority /home/headless/.Xauthority
    chown headless:headless /home/headless/.Xauthority
  fi
  
  # 加载环境变量
  source "$ENV_FILE"
  
  # 准备 .mozilla 目录
  mkdir -p /home/headless/.mozilla/firefox
  chown -R headless:headless /home/headless/.mozilla
  
  # 【新】以 headless 用户创建初始 profile
  echo "Creating initial Firefox profile..." >> "$LOG_FILE"
  su - headless -c "timeout 5 firefox --headless -no-remote" >> "$LOG_FILE" 2>&1 &
  sleep 6
  pkill -9 firefox 2>/dev/null || true
  sleep 1
  
  # 查找新创建的 profile
  PROFILE_DIR=$(find /home/headless/.mozilla/firefox -name "*.default-release" -o -name "*.default" 2>/dev/null | head -n 1)
  
  if [ -z "$PROFILE_DIR" ]; then
    # 如果没有自动创建，手动创建
    PROFILE_DIR="/home/headless/.mozilla/firefox/default-release"
    mkdir -p "$PROFILE_DIR"
    echo "Manually created: $PROFILE_DIR" >> "$LOG_FILE"
  fi
  
  echo "✓ Profile: $PROFILE_DIR" >> "$LOG_FILE"
  
  # 修正权限
  chown -R headless:headless /home/headless/.mozilla
  
  # 【关键】创建 cookies.sqlite（这样 Firefox 启动时不会删除它）
  echo "Creating cookies database..." >> "$LOG_FILE"
  sqlite3 "$PROFILE_DIR/cookies.sqlite" <<EOF
CREATE TABLE IF NOT EXISTS moz_cookies (
  id INTEGER PRIMARY KEY,
  name TEXT,
  value TEXT,
  host TEXT,
  path TEXT,
  expiry INTEGER,
  lastAccessed INTEGER,
  creationTime INTEGER,
  isSecure INTEGER,
  isHttpOnly INTEGER,
  inBrowserElement INTEGER,
  sameSite INTEGER
);
EOF
  chown headless:headless "$PROFILE_DIR/cookies.sqlite"
  
  # Cookie 注入
  if [ -n "$WEBSITE_COOKIE_B64" ] && [ -n "$URL" ]; then
    echo "Starting cookie injection..." >> "$LOG_FILE"
    
    WEBSITE_COOKIE_STRING=$(echo "$WEBSITE_COOKIE_B64" | base64 -d)
    COOKIE_DB_PATH="$PROFILE_DIR/cookies.sqlite"
    COOKIE_DOMAIN=".bilibili.com"
    
    echo "$WEBSITE_COOKIE_STRING" | tr ';' '\n' | while IFS= read -r cookie; do
      cookie=$(echo "$cookie" | sed 's/^[ \t]*//')
      [ -z "$cookie" ] && continue
      
      COOKIE_NAME=$(echo "$cookie" | cut -d'=' -f1)
      COOKIE_VALUE_RAW=$(echo "$cookie" | cut -d'=' -f2-)
      COOKIE_VALUE_ESCAPED=$(echo "$COOKIE_VALUE_RAW" | sed "s/'/''/g")
      
      EXPIRY_TIME=$(($(date +%s) + 31536000))
      CREATION_TIME=$(date +%s)
      
      sqlite3 "$COOKIE_DB_PATH" "INSERT INTO moz_cookies (name, value, host, path, expiry, creationTime, isSecure, isHttpOnly, inBrowserElement, sameSite) VALUES ('${COOKIE_NAME}', '${COOKIE_VALUE_ESCAPED}', '${COOKIE_DOMAIN}', '/', ${EXPIRY_TIME}, ${CREATION_TIME}000000, 1, 1, 0, 1);" 2>/dev/null
      echo "  ✓ ${COOKIE_NAME}" >> "$LOG_FILE"
    done
    
    TOTAL=$(sqlite3 "$COOKIE_DB_PATH" "SELECT COUNT(*) FROM moz_cookies WHERE host LIKE '%bilibili%';" 2>/dev/null)
    echo "✓ $TOTAL cookies injected" >> "$LOG_FILE"
  fi
  
  # 启动 Firefox
  sleep 2
  echo "Launching Firefox..." >> "$LOG_FILE"
  
  if [ -n "$URL" ]; then
    su - headless -c "DISPLAY=:1 firefox --new-window '$URL'" >> "$LOG_FILE" 2>&1 &
    echo "✓ Firefox started with URL: $URL" >> "$LOG_FILE"
  else
    su - headless -c "DISPLAY=:1 firefox" >> "$LOG_FILE" 2>&1 &
    echo "✓ Firefox started" >> "$LOG_FILE"
  fi
  
  sleep 3
  if pgrep -u headless firefox > /dev/null 2>&1; then
    echo "✓ Firefox confirmed running" >> "$LOG_FILE"
  else
    echo "⚠ Firefox not found" >> "$LOG_FILE"
  fi
  
  echo "=== Background task completed at $(date) ===" >> "$LOG_FILE"
) &

echo "Background task started" >> "$LOG_FILE"

# --- 步骤 3: 启动 VNC ---
exec /dockerstartup/startup.sh "$@"
