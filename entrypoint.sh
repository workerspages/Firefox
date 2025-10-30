#!/bin/bash
set -e

# 检查 URL 环境变量是否被设置
if [ -n "$URL" ]; then
  # 如果 URL 存在，则将其写入一个 profile 脚本中。
  # /etc/profile.d/ 目录下的脚本会在所有用户登录时被自动执行，
  # 这就确保了 VNC 会话能够获取到这个环境变量。
  echo "export URL='${URL}'" > /etc/profile.d/custom_env.sh
fi

# 执行传递给此脚本的任何命令（即 Dockerfile 中的 CMD）
exec "$@"
