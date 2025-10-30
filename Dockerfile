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

# 步骤 4: 创建 Firefox 的策略目录并复制策略文件
RUN mkdir -p /usr/lib/firefox/distribution/
COPY config/policies.json /usr/lib/firefox/distribution/

# 步骤 5: 复制 Firefox 启动脚本并赋予权限
COPY launch-firefox.sh /dockerstartup/vnc/xstartup.d/
RUN chmod +x /dockerstartup/vnc/xstartup.d/launch-firefox.sh

# --- 核心修改：添加自定义 Entrypoint 来传递环境变量 ---
# 步骤 6: 复制我们新的 entrypoint 脚本并赋予权限
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 步骤 7: 切换回默认用户
USER 1000

# 步骤 8: 设置我们新的 Entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# 步骤 9: 指定 Entrypoint 执行完后要运行的默认命令
# 这会执行基础镜像的原始启动脚本
CMD ["/usr/bin/startup.sh"]
