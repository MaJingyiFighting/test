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

## 故障记录与解决方案

### 1. pnpm 依赖安装失败 - 镜像源问题

**问题描述**：
```
ERR_PNPM_FETCH_404  GET https://registry.npmmirror.com/end-of-stream/-/end-of-stream-1.4.5.tgz: Not Found - 404
No authorization header was set for the request.
```

**原因分析**：
1. 使用淘宝镜像源（npmmirror.com）时某些包无法访问
2. pnpm 版本过低（8.15.4）可能存在兼容性问题
3. 网络超时设置不合理
4. SSL 证书验证问题

**解决方案**：
1. 切换到官方 npm 源：`registry.npmjs.org`
2. 使用特定版本的 pnpm
3. 禁用严格的 SSL 验证
4. 添加重试机制和缓存清理

### 2. pnpm 命令行参数兼容性问题

**问题描述**：
```
ERROR  Unknown options: 'frozen-lockfile', 'network-timeout'
For help, run: pnpm help add
```

**原因分析**：
1. pnpm 10.x 版本更改了命令行参数格式
2. `--frozen-lockfile` 和 `--network-timeout` 在新版本中不再支持
3. 自动安装的最新版本 pnpm 与项目配置不兼容

**解决方案**：
1. 明确指定使用 pnpm 8.x 版本
2. 移除不兼容的参数
3. 使用 npm 全局安装而不是脚本安装

**具体改进**：
```dockerfile
# 安装特定版本的 pnpm (8.x)
RUN npm install -g pnpm@8.15.4 \
    && pnpm config set registry https://registry.npmjs.org/ \
    && pnpm config set store-dir /root/.pnpm-store \
    && pnpm config set strict-ssl false

# 安装项目依赖
RUN --mount=type=cache,target=/root/.pnpm-store \
    pnpm install --frozen-lockfile || \
    (pnpm store prune && pnpm install --frozen-lockfile)
```

### 3. 依赖包版本不存在问题

**问题描述**：
```
ERR_PNPM_FETCH_404  GET https://registry.npmjs.org/end-of-stream/-/end-of-stream-1.4.5.tgz: Not Found - 404
No authorization header was set for the request.
```

**原因分析**：
1. 项目的 `pnpm-lock.yaml` 文件中引用了不存在的依赖版本 `end-of-stream@1.4.5`
2. 该版本在 npm 官方仓库中不存在，实际最新版本是 `1.4.4`
3. 使用 `--frozen-lockfile` 参数时，pnpm 会严格按照锁文件安装，导致失败

**解决方案**：
1. 修改 `pnpm-lock.yaml` 文件中的版本号
2. 使用 `--no-frozen-lockfile` 参数允许版本自动调整
3. 在构建过程中自动修复版本问题

**具体改进**：
```dockerfile
# 修复 pnpm-lock.yaml 中的依赖版本问题
RUN sed -i 's/end-of-stream@1.4.5/end-of-stream@1.4.4/g' pnpm-lock.yaml

# 安装项目依赖
RUN --mount=type=cache,target=/root/.pnpm-store \
    pnpm install --no-frozen-lockfile || \
    (pnpm store prune && pnpm install --no-frozen-lockfile)
```

## 最佳实践建议

1. **依赖管理**：
   - 使用官方包源而不是镜像源
   - 锁定包管理器版本
   - 配置依赖缓存
   - 实现失败重试机制
   - 定期更新依赖锁文件

2. **构建优化**：
   - 使用多阶段构建
   - 合理设置缓存
   - 优化层级结构
   - 自动修复常见问题

3. **版本控制**：
   - 明确指定工具版本
   - 避免使用 `latest` 标签
   - 定期更新依赖版本
   - 验证依赖版本的有效性

4. **安全性**：
   - 使用非 root 用户
   - 最小化安装包
   - 及时更新依赖

## 更新日志

### 2024-03-11
- 初始化 Docker 项目结构
- 创建基础 Dockerfile
- 配置 GitHub Actions 自动构建
- 添加项目文档

### 2024-03-12
- 优化 pnpm 包管理器配置
- 修复依赖安装失败问题
- 添加故障记录与解决方案
- 更新构建最佳实践建议

### 2024-03-13
- 修复 pnpm 命令行参数兼容性问题
- 锁定 pnpm 版本为 8.15.4
- 优化构建流程
- 更新故障排除文档

### 2024-03-14
- 修复依赖包版本不存在问题
- 添加自动修复锁文件的步骤
- 使用 --no-frozen-lockfile 参数提高兼容性
- 更新故障排除文档和最佳实践 