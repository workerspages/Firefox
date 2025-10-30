#!/bin/bash
# 这个脚本会在容器启动时由 accetto 基础镜像自动执行

# 清理并准备 /etc/environment 文件
# 这个文件是设置系统级环境变量的最佳位置
echo "" > /etc/environment

# 检查并写入 URL 环境变量
if [ -n "$URL" ]; then
  echo "URL=\"${URL}\"" >> /etc/environment
fi

# 检查并写入 Cookie JSON 环境变量
if [ -n "$WEBSITE_COOKIE_JSON" ]; then
  echo "WEBSITE_COOKIE_JSON='${WEBSITE_COOKIE_JSON}'" >> /etc/environment
fi

# 确保文件权限正确
chmod 644 /etc/environment
