# 步骤 1: 使用一个包含桌面环境和 VNC 的基础镜像
FROM accetto/ubuntu-vnc-xfce-firefox-g3:latest

# 步骤 2: 切换到 root 用户以安装软件
USER root

# 步骤 3: 安装所有依赖
RUN apt-get update && \
    apt-get install -y \
    fonts-wqy-zenhei \
    fonts-noto-cjk \
    sqlite3 \
    jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 步骤 4: 复制 Firefox 策略文件
RUN mkdir -p /usr/lib/firefox/distribution/
COPY config/policies.json /usr/lib/firefox/distribution/

# 步骤 5: 复制 Firefox VNC 启动脚本
COPY launch-firefox.sh /dockerstartup/vnc/xstartup.d/
RUN chmod +x /dockerstartup/vnc/xstartup.d/launch-firefox.sh

# 步骤 6: 复制自定义 Entrypoint 脚本
COPY entrypoint.sh /custom_entrypoint.sh
RUN chmod +x /custom_entrypoint.sh

# ❌ 删除这两行 - 不要在 Dockerfile 中切换用户
# USER 1000

# 步骤 7: 设置入口点
ENTRYPOINT ["/custom_entrypoint.sh"]
