# Docker 项目设计与构建文档

## 项目结构

```
.
├── .github/
│   └── workflows/
│       └── docker-build.yml    # GitHub Actions 配置
├── docker/
│   ├── Dockerfile             # Docker 构建文件
│   ├── docker-entrypoint.sh   # 容器启动脚本
│   └── README.md              # 本文档
└── .dockerignore              # Docker 构建排除文件
```

## 构建配置详解

### 1. Dockerfile 配置

```dockerfile
# 基础镜像选择
FROM node:18.19.1-bullseye

# 环境变量配置
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
    g++

# 安全配置
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 应用构建
WORKDIR /app
RUN npm install -g pnpm@8.15.4
COPY . .
RUN pnpm install && pnpm build
```

### 2. 入口脚本 (docker-entrypoint.sh)

```bash
#!/bin/bash
set -e

trap 'kill $(jobs -p)' EXIT
Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
sleep 1
exec "$@"
```

### 3. GitHub Actions 配置

```yaml
name: Docker Build and Push
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
```

## 构建步骤记录

1. 初始环境设置
   - [x] 创建基础目录结构
   - [x] 配置 .dockerignore
   - [x] 设置 GitHub Actions

2. Docker 配置文件创建
   - [x] 编写 Dockerfile
   - [x] 创建启动脚本
   - [x] 配置构建工作流

3. 安全性配置
   - [x] 创建非 root 用户
   - [x] 配置文件权限
   - [x] 设置安全环境变量

4. 构建优化
   - [x] 配置构建缓存
   - [x] 优化层级结构
   - [x] 配置健康检查

## 待办事项

- [ ] 添加多架构支持
- [ ] 优化构建缓存
- [ ] 添加自动化测试
- [ ] 配置监控告警

## 构建命令

```bash
# 本地构建
docker build -t lazy-cs:dev -f docker/Dockerfile .

# 运行测试
docker run -it --rm \
  -p 3000:3000 \
  -p 3001:3001 \
  -v $(pwd):/app \
  lazy-cs:dev
```

## 更新日志

### 2024-03-11
- 初始化 Docker 项目结构
- 创建基础 Dockerfile
- 配置 GitHub Actions 自动构建
- 添加项目文档 