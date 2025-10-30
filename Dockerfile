# 步骤 1: 使用一个包含桌面环境和 VNC 的基础镜像
# 强烈建议：将 :latest 替换为一个具体的版本号，例如 :G3.24.04.1
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

# 步骤 5: 复制 Firefox VNC 启动脚本 (这个钩子是安全的，可以保留)
COPY launch-firefox.sh /dockerstartup/vnc/xstartup.d/
RUN chmod +x /dockerstartup/vnc/xstartup.d/launch-firefox.sh

# 步骤 6: 复制我们新的、唯一的 Entrypoint 脚本
COPY entrypoint.sh /custom_entrypoint.sh
RUN chmod +x /custom_entrypoint.sh

# 步骤 7: 切换回默认用户
USER 1000

# 步骤 8: 将我们的脚本设置为容器的入口点
ENTRYPOINT ["/custom_entrypoint.sh"]
