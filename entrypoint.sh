#!/bin/bash
set -e

# 创建 profile 脚本文件，确保 VNC 会话能获取到环境变量
PROFILE_SCRIPT="/etc/profile.d/custom_env.sh"
echo "#!/bin/sh" > $PROFILE_SCRIPT

# 检查并写入 URL 环境变量
if [ -n "$URL" ]; then
  echo "export URL='${URL}'" >> $PROFILE_SCRIPT
fi

# 检查并写入 Cookie JSON 环境变量
if [ -n "$WEBSITE_COOKIE_JSON" ]; then
  echo "export WEBSITE_COOKIE_JSON='${WEBSITE_COOKIE_JSON}'" >> $PROFILE_SCRIPT
fi

# 执行传递给此脚本的任何命令（即 Dockerfile 中的 CMD）
exec "$@"
