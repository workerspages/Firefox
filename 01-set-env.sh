#!/bin/bash
# 这个脚本会在容器启动时由 accetto 基础镜像自动执行

# 清理并准备 /etc/environment 文件
echo "" > /etc/environment

# 检查并写入 URL 环境变量
if [ -n "$URL" ]; then
  echo "URL=\"${URL}\"" >> /etc/environment
fi

# 检查并写入 Cookie 字符串环境变量
if [ -n "$WEBSITE_COOKIE_STRING" ]; then
  # 使用 base64 编码来安全地传递可能包含特殊字符的 Cookie 字符串
  COOKIE_B64=$(echo -n "$WEBSITE_COOKIE_STRING" | base64 -w 0)
  echo "WEBSITE_COOKIE_B64=\"${COOKIE_B64}\"" >> /etc/environment
fi

# 确保文件权限正确
chmod 644 /etc/environment
