#!/bin/bash
set -e

# 捕获退出信号
trap 'kill $(jobs -p)' EXIT

# 启动 X 虚拟帧缓冲
Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &

# 等待 X 服务器启动
sleep 1

# 执行传入的命令
exec "$@" 