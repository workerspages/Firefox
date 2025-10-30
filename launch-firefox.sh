#!/bin/bash

# 等待几秒钟，确保桌面环境完全加载完毕
sleep 5

# 启动 Firefox 并打开指定 URL
# 环境变量 $URL 会被这个脚本继承
firefox --new-window "$URL" &
