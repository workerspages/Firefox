# 步骤 1: 使用一个包含桌面环境和 VNC 的基础镜像
FROM accetto/ubuntu-vnc-xfce-firefox-g3:latest

# 步骤 2: 切换到 root 用户以安装软件
USER root

# 步骤 3: 安装中文字体支持
RUN apt-get update && \
    apt-get install -y \
    fonts-wqy-zenhei \
    fonts-noto-cjk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- 核心修改：使用 Firefox Policy Engine 安装插件 ---
# 步骤 4: 创建 Firefox 的策略目录
# 这是 Firefox 查找策略文件的官方路径
RUN mkdir -p /usr/lib/firefox/distribution/

# 步骤 5: 复制我们定义好的 policies.json 文件到该目录
COPY config/policies.json /usr/lib/firefox/distribution/

# --- 核心修改：使用新的启动脚本 ---
# 步骤 6: 复制我们增强版的启动脚本到镜像的 VNC 启动目录
COPY launch-firefox.sh /dockerstartup/vnc/xstartup.d/

# 步骤 7: 确保我们的脚本有执行权限
RUN chmod +x /dockerstartup/vnc/xstartup.d/launch-firefox.sh

# 步骤 8: 切换回默认用户
USER 1000
