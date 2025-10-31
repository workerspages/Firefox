#!/bin/bash
set -e

LOG_FILE="/tmp/ff_launch.log"
echo "=== Entrypoint Started at $(date) ===" > "$LOG_FILE"

# --- 步骤 1: 设置环境变量 (此部分保持不变) ---
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

# --- 步骤 2: 后台任务 - Firefox 配置和启动 ---
(
  echo "=== Background task started at $(date) ===" >> "$LOG_FILE"
  
  # 等待 VNC 和桌面环境完全启动
  echo "Waiting for desktop environment (20 seconds)..." >> "$LOG_FILE"
  sleep 20
  
  export DISPLAY=:1
  echo "DISPLAY set to: $DISPLAY" >> "$LOG_FILE"
  
  # 授权 headless 用户访问 X11 display
  echo "Setting X11 permissions..." >> "$LOG_FILE"
  xhost +local:headless >> "$LOG_FILE" 2>&1 || echo "xhost command failed (may be OK)" >> "$LOG_FILE"
  
  if [ -f /root/.Xauthority ]; then
    cp /root/.Xauthority /home/headless/.Xauthority
    chown headless:headless /home/headless/.Xauthority
    echo "Copied .Xauthority to headless user" >> "$LOG_FILE"
  fi
  
  # 【核心修正】: 将所有 Profile 操作都以 headless 用户执行
  # ----------------------------------------------------------------
  su - headless -c '
    set -e
    LOG_FILE="/tmp/ff_launch.log"
    ENV_FILE="/tmp/custom_env.sourceme"
    
    # 加载环境变量
    source "$ENV_FILE"
    echo "[headless] Environment variables loaded" >> "$LOG_FILE"

    # 确保 .mozilla 目录存在
    mkdir -p /home/headless/.mozilla/firefox
    
    # 创建 Firefox profile
    echo "[headless] Creating Firefox profile..." >> "$LOG_FILE"
    timeout 5 firefox --headless -no-remote >> "$LOG_FILE" 2>&1 &
    PROFILE_PID=$!
    sleep 6
    
    if kill -0 $PROFILE_PID 2>/dev/null; then
      kill -9 $PROFILE_PID 2>/dev/null || true
    fi
    pkill -9 firefox 2>/dev/null || true
    sleep 1
    
    # 查找 profile 目录
    PROFILE_DIR=$(find /home/headless/.mozilla/firefox -name "*.default-release" -o -name "*.default" 2>/dev/null | head -n 1)
    
    if [ -z "$PROFILE_DIR" ]; then
      echo "[headless] ERROR: Firefox profile not found!" >> "$LOG_FILE"
    else
      echo "[headless] ✓ Profile found: $PROFILE_DIR" >> "$LOG_FILE"
      
      COOKIE_DB_PATH="$PROFILE_DIR/cookies.sqlite"
      
      # 注入 Cookie (如果需要)
      if [ -n "$WEBSITE_COOKIE_B64" ] && [ -n "$URL" ]; then
        echo "[headless] Starting cookie injection..." >> "$LOG_FILE"
        
        # 创建 cookies.sqlite (如果不存在)
        if [ ! -f "$COOKIE_DB_PATH" ]; then
          echo "[headless] Creating cookies database..." >> "$LOG_FILE"
          sqlite3 "$COOKIE_DB_PATH" "CREATE TABLE moz_cookies (id INTEGER PRIMARY KEY, name TEXT, value TEXT, host TEXT, path TEXT, expiry INTEGER, lastAccessed INTEGER, creationTime INTEGER, isSecure INTEGER, isHttpOnly INTEGER, inBrowserElement INTEGER, sameSite INTEGER);"
        fi

        WEBSITE_COOKIE_STRING=$(echo "$WEBSITE_COOKIE_B64" | base64 -d)
        COOKIE_DOMAIN=".bilibili.com"
        
        sqlite3 "$COOKIE_DB_PATH" "DELETE FROM moz_cookies WHERE host LIKE '\''%bilibili%'\'';" 2>/dev/null
        
        echo "$WEBSITE_COOKIE_STRING" | tr ";" "\n" | while IFS= read -r cookie; do
          cookie=$(echo "$cookie" | sed "s/^[ \t]*//; s/[ \t]*$//")
          [ -z "$cookie" ] && continue
          
          COOKIE_NAME=$(echo "$cookie" | cut -d"=" -f1)
          COOKIE_VALUE_RAW=$(echo "$cookie" | cut -d"=" -f2-)
          COOKIE_VALUE_ESCAPED=$(echo "$COOKIE_VALUE_RAW" | sed "s/'\''/''\''/g") # Corrected sed for single quotes
          
          EXPIRY_TIME=$(($(date +%s) + 31536000))
          CREATION_TIME=$(date +%s)
          
          sqlite3 "$COOKIE_DB_PATH" "INSERT INTO moz_cookies (name, value, host, path, expiry, creationTime, isSecure, isHttpOnly, inBrowserElement, sameSite) VALUES ('\''${COOKIE_NAME}'\'', '\''${COOKIE_VALUE_ESCAPED}'\'', '\''${COOKIE_DOMAIN}'\'', '\''/'\'', ${EXPIRY_TIME}, ${CREATION_TIME}000000, 1, 1, 0, 1);" >> "$LOG_FILE" 2>&1
        done
        
        TOTAL=$(sqlite3 "$COOKIE_DB_PATH" "SELECT COUNT(*) FROM moz_cookies WHERE host LIKE '\''%bilibili%'\'';" 2>/dev/null)
        echo "[headless] ✓ Cookie injection completed: $TOTAL cookies for .bilibili.com" >> "$LOG_FILE"
      else
        echo "[headless] Skipping cookie injection (no data)" >> "$LOG_FILE"
      fi
    fi
    
    # 等待一下
    sleep 3
    
    # 启动 Firefox
    echo "[headless] Launching Firefox..." >> "$LOG_FILE"
    if [ -n "$URL" ]; then
      DISPLAY=:1 firefox --new-window "$URL" >> "$LOG_FILE" 2>&1 &
    else
      DISPLAY=:1 firefox >> "$LOG_FILE" 2>&1 &
    fi
  '
  # ----------------------------------------------------------------
  
  sleep 3
  
  if pgrep -u headless firefox > /dev/null 2>&1; then
    echo "✓ Firefox process confirmed running as headless user" >> "$LOG_FILE"
  else
    echo "⚠ WARNING: Firefox process not found!" >> "$LOG_FILE"
  fi
  
  echo "=== Background task completed at $(date) ===" >> "$LOG_FILE"
) &

BACKGROUND_PID=$!
echo "Background task started with PID: $BACKGROUND_PID" >> "$LOG_FILE"
echo "Starting VNC server..." >> "$LOG_FILE"

# --- 步骤 3: 启动 VNC 服务器 (此部分保持不变) ---
exec /dockerstartup/startup.sh "$@"
