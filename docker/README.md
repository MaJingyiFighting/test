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

### 4. 构建环境依赖缺失问题

**问题描述**：
```
devDependencies: skipped because NODE_ENV is set to production
sh: 1: ts-node: not found
ELIFECYCLE  Command failed.
```

**原因分析**：
1. 在生产环境模式下，pnpm 跳过了开发依赖的安装
2. 构建脚本依赖于 `ts-node` 等开发工具
3. 环境变量设置不当导致构建失败

**解决方案**：
1. 构建阶段使用开发环境模式
2. 全局安装必要的构建工具
3. 构建完成后再切换到生产环境模式
4. 分阶段设置环境变量

**具体改进**：
```dockerfile
# 设置开发环境进行构建
ENV NODE_ENV=development

# 安装必要的全局工具
RUN npm install -g pnpm@8.15.4 ts-node typescript \
    && pnpm config set registry https://registry.npmjs.org/

# 构建完成后切换到生产环境
ENV NODE_ENV=production
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

### 4. 构建环境依赖缺失问题

**问题描述**：
```
devDependencies: skipped because NODE_ENV is set to production
sh: 1: ts-node: not found
ELIFECYCLE  Command failed.
```

**原因分析**：
1. 在生产环境模式下，pnpm 跳过了开发依赖的安装
2. 构建脚本依赖于 `ts-node` 等开发工具
3. 环境变量设置不当导致构建失败

**解决方案**：
1. 构建阶段使用开发环境模式
2. 全局安装必要的构建工具
3. 构建完成后再切换到生产环境模式
4. 分阶段设置环境变量

**具体改进**：
```dockerfile
# 设置开发环境进行构建
ENV NODE_ENV=development

# 安装必要的全局工具
RUN npm install -g pnpm@8.15.4 ts-node typescript \
    && pnpm config set registry https://registry.npmjs.org/

# 构建完成后切换到生产环境
ENV NODE_ENV=production
```

### 5. pnpm 全局工具路径问题

**问题描述**：
```
sh: 1: ts-node: not found
ELIFECYCLE  Command failed.
devDependencies: skipped because NODE_ENV is set to production
```

**原因分析**：
1. 全局安装的工具无法在 PATH 中找到
2. pnpm 全局安装路径未正确配置
3. 构建脚本执行顺序问题
4. electron 相关依赖下载导致构建失败

**解决方案**：
1. 添加 pnpm 全局路径到 PATH 环境变量
2. 使用 `pnpm setup` 初始化环境
3. 分步骤安装和重建依赖
4. 跳过 electron 二进制下载

**具体改进**：
```dockerfile
# 配置 pnpm 全局路径
ENV PATH="/root/.local/share/pnpm:$PATH"

# 安装和配置 pnpm
RUN npm install -g pnpm@8.15.4 \
    && pnpm setup \
    && pnpm install -g ts-node typescript electron-builder

# 优化依赖安装
RUN ELECTRON_SKIP_BINARY_DOWNLOAD=1 pnpm install --no-frozen-lockfile --ignore-scripts \
    && pnpm rebuild
```

### 6. pnpm Shell 环境检测问题

**问题描述**：
```
ERR_PNPM_UNKNOWN_SHELL  Could not infer shell type.

Set the SHELL environment variable to your active shell.
Supported shell languages are bash, zsh, fish, ksh, dash, and sh.
```

**原因分析**：
1. Docker 容器中未设置 SHELL 环境变量
2. pnpm setup 命令需要正确的 shell 环境
3. pnpm 全局安装路径未正确导出
4. shell 配置文件未被正确加载

**解决方案**：
1. 显式设置 SHELL 环境变量为 /bin/bash
2. 使用 bash -c 执行 pnpm setup
3. 正确设置和导出 PNPM_HOME
4. 确保加载 shell 配置文件

**具体改进**：
```dockerfile
# 设置必要的环境变量
ENV SHELL="/bin/bash"

# 优化 pnpm 安装和配置
RUN npm install -g pnpm@8.15.4 \
    && bash -c "source ~/.bashrc && pnpm setup" \
    && export PNPM_HOME="/root/.local/share/pnpm" \
    && export PATH="$PNPM_HOME:$PATH"
```

### 7. Electron 运行环境优化

**优化内容**：
1. npm 配置优化
   - 禁用不必要的警告和审计
   - 优化日志级别
   - 配置 Electron 下载镜像

2. 系统依赖优化
   - 添加完整的 Electron 运行依赖
   - 优化构建工具链
   - 添加必要的图形库支持

3. 构建流程优化
   - 使用 `--shamefully-hoist` 优化依赖提升
   - 添加原生模块重建步骤
   - 优化启动脚本

**具体改进**：
```dockerfile
# npm 配置优化
ENV NPM_CONFIG_LOGLEVEL=error \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/

# 完整的系统依赖
RUN apt-get install -y \
    libgbm1 libxshmfence1 libx11-xcb1 \
    libdrm2 libatk1.0-0 libatk-bridge2.0-0 \
    # ... 更多依赖

# 构建优化
RUN pnpm install --shamefully-hoist \
    && npm rebuild sqlite3 --build-from-source \
    && npm rebuild lzma-native --build-from-source
```

### 8. 容器安全性与性能优化

**优化内容**：
1. 系统配置优化
   - 使用国内镜像源加速构建
   - 最小化安装系统依赖
   - 添加网络和安全工具

2. 隐私与安全增强
   - 禁用遥测和数据收集
   - 添加隐私保护补丁
   - 配置安全相关环境变量

3. 目录结构优化
   - 创建完整的应用目录结构
   - 合理设置目录权限
   - 优化数据持久化配置

**具体改进**：
```dockerfile
# 隐私和安全配置
ENV DISABLE_TELEMETRY=true \
    DISABLE_ANALYTICS=true \
    PRIVACY_MODE=strict

# 系统优化
RUN apt-get install -y --no-install-recommends \
    dnsutils iptables ca-certificates \
    libgl1-mesa-dri libgl1-mesa-glx

# 目录结构
RUN mkdir -p /app/data/files /app/data/temp \
    /app/logs /app/plugins /app/config \
    /app/temp /app/cache
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

5. **环境配置**：
   - 区分构建环境和运行环境
   - 合理设置环境变量
   - 确保构建工具可用
   - 优化生产环境配置

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

### 2024-03-15
- 修复构建环境依赖问题
- 优化环境变量配置
- 添加全局构建工具
- 更新构建最佳实践

### 2024-03-16
- 修复 pnpm 全局工具路径问题
- 优化依赖安装流程
- 添加 electron 构建优化
- 更新构建文档

### 2024-03-17
- 修复 pnpm shell 环境检测问题
- 优化 pnpm 安装和配置流程
- 添加 shell 环境变量设置
- 更新构建文档

### 2024-03-18
- 整合历史版本优秀实践
- 优化 Electron 运行环境配置
- 完善系统依赖安装
- 改进构建流程和启动脚本

### 2024-03-19
- 整合容器安全性优化
- 添加隐私保护机制
- 优化系统配置和依赖
- 完善目录结构设计 