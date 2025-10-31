FROM accetto/ubuntu-vnc-xfce-firefox-g3:latest

USER root

# 安装依赖
RUN apt-get update && \
    apt-get install -y \
    fonts-wqy-zenhei \
    fonts-noto-cjk \
    sqlite3 \
    jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 复制 Firefox 策略文件
RUN mkdir -p /usr/lib/firefox/distribution/
COPY config/policies.json /usr/lib/firefox/distribution/

# 复制入口点脚本
COPY entrypoint.sh /custom_entrypoint.sh
RUN chmod +x /custom_entrypoint.sh

# ❌ 不再需要 launch-firefox.sh,因为逻辑已移到 entrypoint.sh

ENTRYPOINT ["/custom_entrypoint.sh"]
