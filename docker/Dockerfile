# 使用特定版本的 Node.js
FROM node:18.19.1-bullseye

# 设置环境变量
ENV NODE_ENV=development \
    ELECTRON_DISABLE_SANDBOX=true \
    DISPLAY=:99 \
    DEBIAN_FRONTEND=noninteractive \
    NODE_OPTIONS="--max-old-space-size=4096" \
    PATH="/root/.local/share/pnpm:$PATH" \
    SHELL="/bin/bash" \
    # 优化 npm 配置
    NPM_CONFIG_LOGLEVEL=error \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    # Electron 相关配置
    ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ \
    ELECTRON_CUSTOM_DIR="{{ version }}" \
    ELECTRON_SKIP_BINARY_DOWNLOAD=1 \
    PYTHON=/usr/bin/python3 \
    # 禁用其他不必要的下载
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    # 隐私和安全设置
    ELECTRON_NO_ATTACH_CONSOLE=1 \
    DISABLE_TELEMETRY=true \
    DISABLE_ANALYTICS=true \
    PRIVACY_MODE=strict

# 系统依赖安装 - 优化依赖列表
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    libgtk-3-0 \
    libnotify-dev \
    libgconf-2-4 \
    libnss3 \
    libxss1 \
    libasound2 \
    libxtst6 \
    xauth \
    git \
    python3 \
    make \
    g++ \
    curl \
    # 添加额外的 Electron 运行依赖
    libgbm1 \
    libxshmfence1 \
    libx11-xcb1 \
    libdrm2 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libglu1-mesa \
    libpci3 \
    libnspr4 \
    libxcursor1 \
    libxi6 \
    libsecret-1-0 \
    pkg-config \
    build-essential \
    # 添加 Mesa 相关依赖
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    # 添加网络和安全工具
    dnsutils \
    iptables \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 创建应用目录
WORKDIR /app

# 安装特定版本的 pnpm (8.x) 和全局依赖
RUN npm install -g pnpm@8.15.4 \
    && bash -c "source ~/.bashrc && pnpm setup" \
    && export PNPM_HOME="/root/.local/share/pnpm" \
    && export PATH="$PNPM_HOME:$PATH" \
    && pnpm install -g ts-node typescript electron-builder \
    && pnpm config set registry https://registry.npmjs.org/ \
    && pnpm config set store-dir /root/.pnpm-store \
    && pnpm config set strict-ssl false

# 复制 package.json 和 lock 文件
COPY package.json pnpm-lock.yaml ./

# 修复 pnpm-lock.yaml 中的依赖版本问题并清理缓存
RUN sed -i 's/end-of-stream@1.4.5/end-of-stream@1.4.4/g' pnpm-lock.yaml \
    && pnpm store prune

# 安装项目依赖（包括开发依赖）
RUN --mount=type=cache,target=/root/.pnpm-store \
    ELECTRON_SKIP_BINARY_DOWNLOAD=1 pnpm install --no-frozen-lockfile --ignore-scripts --shamefully-hoist \
    && pnpm rebuild \
    && npm rebuild sqlite3 --build-from-source \
    && npm rebuild lzma-native --build-from-source

# 复制构建配置文件
COPY .erb/ .erb/
COPY tsconfig.json .
RUN pnpm run build:dll

# 复制源代码
COPY --chown=appuser:appuser . .

# 创建日志目录
RUN mkdir -p /app/logs && chown -R appuser:appuser /app/logs

# 创建必要的目录并设置权限
RUN mkdir -p /app/data/files /app/data/temp /app/logs /app/plugins /app/config /app/temp /app/cache \
    && chown -R appuser:appuser /app/data /app/logs /app/plugins /app/config /app/temp /app/cache

# 构建应用
RUN pnpm run build

# 生产环境优化
ENV NODE_ENV=production

# 复制启动脚本并设置权限
COPY docker/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && echo '#!/bin/bash\nrm -f /tmp/.X99-lock\nXvfb :99 -screen 0 1024x768x24 &\nsleep 1\nexec "$@"' > /usr/local/bin/start.sh \
    && chmod +x /usr/local/bin/start.sh

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 3000 3001

# 创建数据卷
VOLUME ["/app/logs", "/app/config"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# 设置启动命令
ENTRYPOINT ["/usr/local/bin/start.sh"]
CMD ["pnpm", "start"] 