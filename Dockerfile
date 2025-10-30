# 步骤 1: 使用一个包含桌面环境和 VNC 的基础镜像
# 强烈建议：将 :latest 替换为一个具体的版本号，例如 :G3.24.04.1，以避免未来更新带来的破坏
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

# --- 核心修改：使用官方钩子脚本 ---

# 步骤 5: 复制环境变量设置脚本到 /dockerstartup/ 目录
# 这个目录下的脚本会在容器启动的最开始阶段被自动执行
COPY 01-set-env.sh /dockerstartup/
RUN chmod +x /dockerstartup/01-set-env.sh

# 步骤 6: 复制 Firefox 启动脚本到 VNC 的自启动目录
# 这个目录下的脚本会在 VNC 桌面环境启动后被自动执行
COPY launch-firefox.sh /dockerstartup/vnc/xstartup.d/
RUN chmod +x /dockerstartup/vnc/xstartup.d/launch-firefox.sh

# 步骤 7: 切换回默认用户
USER 1000

# 我们不再需要定义 ENTRYPOINT 或 CMD。
# 容器将使用基础镜像默认的启动逻辑，这才是最稳定的方式。
