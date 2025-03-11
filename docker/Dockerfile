# 使用特定版本的 Node.js
FROM node:18.19.1-bullseye

# 设置环境变量
ENV NODE_ENV=production \
    ELECTRON_DISABLE_SANDBOX=true \
    DISPLAY=:99 \
    DEBIAN_FRONTEND=noninteractive \
    NODE_OPTIONS="--max-old-space-size=4096"

# 系统依赖安装
RUN apt-get update && apt-get install -y \
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 创建应用目录
WORKDIR /app

# 安装 pnpm
RUN npm install -g pnpm@8.15.4 \
    && pnpm config set store-dir /root/.pnpm-store \
    && pnpm config set registry https://registry.npmmirror.com

# 复制 package.json 和 lock 文件
COPY package.json pnpm-lock.yaml ./

# 安装项目依赖
RUN --mount=type=cache,target=/root/.pnpm-store \
    pnpm install --frozen-lockfile || \
    (sleep 5 && pnpm install --frozen-lockfile)

# 复制构建配置文件
COPY .erb/ .erb/
COPY tsconfig.json .
RUN pnpm run build:dll

# 复制源代码
COPY --chown=appuser:appuser . .

# 创建日志目录
RUN mkdir -p /app/logs && chown -R appuser:appuser /app/logs

# 构建应用
RUN pnpm run build

# 复制启动脚本
COPY docker/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

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
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["pnpm", "start"] 