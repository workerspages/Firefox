#!/bin/bash
# 这个脚本会在容器启动时由 accetto 基础镜像自动执行

ENV_FILE="/tmp/custom_env.sourceme"
echo "#!/bin/bash" > $ENV_FILE
echo "# This file is generated at container startup." >> $ENV_FILE

# 检查并写入 URL 环境变量
if [ -n "$URL" ]; then
  # 使用 @Q 操作符来安全地引用变量，防止特殊字符问题
  printf "export URL=%q\n" "$URL" >> $ENV_FILE
fi

# 检查并写入 Cookie 字符串环境变量
if [ -n "$WEBSITE_COOKIE_STRING" ]; then
  # 使用 base64 编码来安全地传递
  COOKIE_B64=$(echo -n "$WEBSITE_COOKIE_STRING" | base64 -w 0)
  printf "export WEBSITE_COOKIE_B64=%q\n" "$COOKIE_B64" >> $ENV_FILE
fi

chmod 644 $ENV_FILE
