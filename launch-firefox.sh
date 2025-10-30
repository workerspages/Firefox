#!/bin/bash

# --- 调试日志 ---
# 将日志输出到临时文件，方便排查问题
LOG_FILE="/tmp/ff_launch.log"
echo "--- Firefox Launch Script Started at $(date) ---" > $LOG_FILE

# 检查环境变量文件是否存在并加载它，这能增强变量的可用性
if [ -f /etc/environment ]; then
  source /etc/environment
  echo "Loaded /etc/environment" >> $LOG_FILE
fi

echo "URL variable found: [${URL}]" >> $LOG_FILE
echo "DISPLAY variable found: [${DISPLAY}]" >> $LOG_FILE
# --- 调试日志结束 ---

# 等待桌面环境准备就绪
sleep 8

# 检查 URL 环境变量是否为空
if [ -z "${URL}" ]; then
  echo "URL is not set. Launching Firefox with default page." >> $LOG_FILE
  # 如果 URL 为空，则只启动 Firefox
  firefox &
else
  echo "Launching Firefox with URL: ${URL}" >> $LOG_FILE
  # 如果 URL 不为空，则在新窗口中打开它
  firefox --new-window "${URL}" &
fi
