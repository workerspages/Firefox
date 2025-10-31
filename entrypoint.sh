#!/bin/bash
set -e

LOG_FILE="/tmp/ff_launch.log"
HEADLESS_SCRIPT_FILE="/tmp/headless_script.sh"
ENV_FILE="/tmp/custom_env.sourceme"

# 清理日志，方便调试
> "$LOG_FILE"
echo "=== Entrypoint Started at $(date) ===" | tee -a "$LOG_FILE"

# --- 步骤 1: 创建环境变量文件 ---
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

# 在 root 环境下预先计算好时间戳
EXPIRY_TIME=$(($(date +%s) + 31536000))
CREATION_TIME=$(date +%s)
printf "export EXPIRY_TIME=%q\n" "$EXPIRY_TIME" >> "$ENV_FILE"
printf "export CREATION_TIME=%q\n" "$CREATION_TIME" >> "$ENV_FILE"
echo "Timestamps calculated and added to env file." >> "$LOG_FILE"

# --- 步骤 2: 创建 headless 用户的执行脚本 ---
# 使用 "here document" (cat <<'EOF') 来创建脚本, 'EOF' 的引号可以防止变量被提前解析
cat <<'EOF' > "$HEADLESS_SCRIPT_FILE"
#!/bin/bash
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
timeout 10 firefox --headless -no-remote >> "$LOG_FILE" 2>&1 || true
pkill -9 -u headless -f firefox 2>/dev/null || true
sleep 1

# 查找 profile 目录
PROFILE_DIR=$(find /home/headless/.mozilla/firefox -name "*.default-release" -o -name "*.default" 2>/dev/null | head -n 1)

if [ -z "$PROFILE_DIR" ]; then
  echo "[headless] ERROR: Firefox profile not found!" >> "$LOG_FILE"
  exit 1
fi

echo "[headless] ✓ Profile found: $PROFILE_DIR" >> "$LOG_FILE"
COOKIE_DB_PATH="$PROFILE_DIR/cookies.sqlite"

# Cookie 注入逻辑
if [ -n "$WEBSITE_COOKIE_B64" ] && [ -n "$URL" ]; then
  echo "[headless] Starting robust cookie injection..." >> "$LOG_FILE"
  
  SQL_SCRIPT_FILE="/tmp/cookies.sql"
  
  if [ ! -f "$COOKIE_DB_PATH" ]; then
    echo "CREATE TABLE moz_cookies (id INTEGER PRIMARY KEY, name TEXT, value TEXT, host TEXT, path TEXT, expiry INTEGER, lastAccessed INTEGER, creationTime INTEGER, isSecure INTEGER, isHttpOnly INTEGER, inBrowserElement INTEGER, sameSite INTEGER);" > "$SQL_SCRIPT_FILE"
  else
    echo "DELETE FROM moz_cookies WHERE host LIKE '%bilibili%';" > "$SQL_SCRIPT_FILE"
  fi

  WEBSITE_COOKIE_STRING=$(echo "$WEBSITE_COOKIE_B64" | base64 -d)
  COOKIE_DOMAIN=".bilibili.com"
  
  echo "$WEBSITE_COOKIE_STRING" | tr ";" "\n" | while IFS= read -r cookie; do
    cookie=$(echo "$cookie" | sed 's/^[ \t]*//; s/[ \t]*$//')
    [ -z "$cookie" ] && continue
    
    COOKIE_NAME=$(echo "$cookie" | cut -d"=" -f1)
    COOKIE_VALUE_RAW=$(echo "$cookie" | cut -d"=" -f2-)
    COOKIE_VALUE_ESCAPED=$(echo "$COOKIE_VALUE_RAW" | sed "s/'/''/g")
    
    echo "INSERT INTO moz_cookies (name, value, host, path, expiry, creationTime, isSecure, isHttpOnly, inBrowserElement, sameSite) VALUES ('${COOKIE_NAME}', '${COOKIE_VALUE_ESCAPED}', '${COOKIE_DOMAIN}', '/', ${EXPIRY_TIME}, ${CREATION_TIME}000000, 1, 1, 0, 1);" >> "$SQL_SCRIPT_FILE"
  done
  
  if sqlite3 "$COOKIE_DB_PATH" < "$SQL_SCRIPT_FILE"; then
     COUNT_QUERY="SELECT COUNT(*) FROM moz_cookies WHERE host LIKE '%bilibili%';"
     TOTAL=$(sqlite3 "$COOKIE_DB_PATH" "$COUNT_QUERY")
     echo "[headless] ✓ Cookie injection SUCCEEDED. Total cookies injected: ${TOTAL:-0}" >> "$LOG_FILE"
  else
     echo "[headless] ✗ Cookie injection FAILED." >> "$LOG_FILE"
  fi
  
  rm "$SQL_SCRIPT_FILE"
fi

sleep 2

# 启动 Firefox
echo "[headless] Launching Firefox..." >> "$LOG_FILE"
if [ -n "$URL" ]; then
  echo "[headless] URL found: $URL. Launching..." >> "$LOG_FILE"
  exec env DISPLAY=:1 firefox --new-window "$URL"
else
  echo "[headless] URL not set. Launching default page." >> "$LOG_FILE"
  exec env DISPLAY=:1 firefox
fi
EOF

# --- 步骤 3: 设置权限并启动后台任务 ---
chmod +x "$HEADLESS_SCRIPT_FILE"
chown headless:headless "$HEADLESS_SCRIPT_FILE" "$ENV_FILE"
echo "Headless script created at $HEADLESS_SCRIPT_FILE" >> "$LOG_FILE"

(
  echo "=== Background task started at $(date) ===" >> "$LOG_FILE"
  
  sleep 20
  
  export DISPLAY=:1
  echo "DISPLAY set to: $DISPLAY" >> "$LOG_FILE"
  
  xhost +local:headless >> "$LOG_FILE" 2>&1 || true
  
  if [ -f /root/.Xauthority ]; then
    cp /root/.Xauthority /home/headless/.Xauthority
    chown headless:headless /home/headless/.Xauthority
    echo "Copied .Xauthority to headless user" >> "$LOG_FILE"
  fi
  
  # 用最简单的方式执行新脚本
  su - headless -c "$HEADLESS_SCRIPT_FILE" >> "$LOG_FILE" 2>&1
  
) &

echo "Background task started with PID: $!" >> "$LOG_FILE"
echo "Starting VNC server..." >> "$LOG_FILE"

# --- 步骤 4: 启动 VNC 服务器 ---
exec /dockerstartup/startup.sh "$@"
