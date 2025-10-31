#!/bin/bash
set -e

# --- 步骤 1: 设置我们的环境变量 ---
ENV_FILE="/tmp/custom_env.sourceme"
echo "#!/bin/bash" > "$ENV_FILE"

if [ -n "$URL" ]; then
  printf "export URL=%q\n" "$URL" >> "$ENV_FILE"
fi

if [ -n "$WEBSITE_COOKIE_STRING" ]; then
  COOKIE_B64=$(echo -n "$WEBSITE_COOKIE_STRING" | base64 -w 0)
  printf "export WEBSITE_COOKIE_B64=%q\n" "$COOKIE_B64" >> "$ENV_FILE"
fi

chmod 644 "$ENV_FILE"

# --- 步骤 2: 执行基础镜像的原始 Entrypoint ---
# 将控制权交还给 accetto 镜像的原始启动脚本，让它完成所有后续工作
exec /dockerstartup/startup.sh "$@"
