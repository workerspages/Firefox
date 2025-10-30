# 步骤 1: 使用一个包含桌面环境和 VNC 的基础镜像
FROM accetto/ubuntu-vnc-xfce-firefox-g3:latest

# 步骤 2: 切换到 root 用户以安装软件
USER root

# 步骤 3: 安装中文字体支持
# 我们安装 "wqy-zenhei" (文泉驿正黑) 和 "fonts-noto-cjk" (思源黑体)
# 这些字体库能覆盖绝大多数中文字符，避免乱码
RUN apt-get update && \
    apt-get install -y \
    fonts-wqy-zenhei \
    fonts-noto-cjk \
    wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 步骤 4: 下载并安装 Firefox 页面自动刷新插件
# 以 "Easy Auto Refresh" 为例，您也可以替换成其他插件的 xpi 文件链接
# 注意：插件的下载链接可能会变化，如果失效需要手动查找新的链接
RUN wget https://addons.mozilla.org/firefox/downloads/file/4207985/easy_auto_refresh-2.6.2.xpi -O /tmp/auto-refresh.xpi && \
    # 将插件安装到 Firefox 的全局扩展目录中
    # 注意：路径中的 firefox 需要和基础镜像中的版本匹配
    mkdir -p /usr/lib/firefox/browser/extensions/ && \
    mv /tmp/auto-refresh.xpi /usr/lib/firefox/browser/extensions/easy-auto-refresh@my-addon.xpi

# 步骤 5: 切换回默认用户
USER 1000

# 步骤 6: (可选) 设置启动时默认打开的 URL
# 我们将通过 docker-compose.yml 传入，这里只是一个示例
ENV URL="https://www.bing.com"

# 覆盖默认的启动命令，以便接受 URL 参数
CMD ["/bin/bash", "-c", "/usr/bin/startup.sh &> /dev/null && sleep 5 && firefox --new-window $URL"]
