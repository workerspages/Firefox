# 步骤 1: 使用一个包含桌面环境和 VNC 的基础镜像
FROM accetto/ubuntu-vnc-xfce-firefox-g3:latest

# 步骤 2: 切换到 root 用户以安装软件
USER root

# 步骤 3: 安装中文字体支持
RUN apt-get update && \
    apt-get install -y \
    fonts-wqy-zenhei \
    fonts-noto-cjk \
    wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 步骤 4: 下载并安装 Firefox 页面自动刷新插件
RUN wget https://addons.mozilla.org/firefox/downloads/file/4207985/easy_auto_refresh-2.6.2.xpi -O /tmp/auto-refresh.xpi && \
    mkdir -p /usr/lib/firefox/browser/extensions/ && \
    mv /tmp/auto-refresh.xpi /usr/lib/firefox/browser/extensions/easy-auto-refresh@my-addon.xpi

# --- 以下是核心修改 ---

# 步骤 5: 复制我们自定义的启动脚本到镜像的 VNC 启动目录
# 这个目录下的脚本会在 VNC 服务启动后自动执行
COPY launch-firefox.sh /dockerstartup/vnc/xstartup.d/

# 步骤 6: 确保我们的脚本有执行权限
RUN chmod +x /dockerstartup/vnc/xstartup.d/launch-firefox.sh

# 步骤 7: 切换回默认用户
USER 1000

# 步骤 8: 移除自定义的 CMD
# 我们不再需要自定义 CMD。镜像将回退使用 accetto 基础镜像的默认 CMD，
# 它会正确地在前台运行 VNC 服务，保持容器存活。
# (这里什么都不用写，即为移除)
