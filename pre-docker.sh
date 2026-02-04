#!/bin/bash

# 环境准备脚本
echo "========================================"
echo "        环境准备脚本"
echo "========================================"
echo ""

# 检查是否以root用户运行
if [ "$(id -u)" != "0" ]; then
    echo "[错误] 请以root用户运行此脚本"
    exit 1
fi

# 安装Docker
echo "install Docker and docker-compose..."
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，正在安装..."
    # 安装Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    chmod +x get-docker.sh
    sh get-docker.sh
    # 添加当前用户到docker组
    usermod -aG docker $SUDO_USER
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    echo "Docker安装完成"
    echo "Docker已自动添加到环境变量中"
else
    echo "Docker已安装"
    echo "Docker命令路径: $(which docker)"
fi

# 配置Docker中国代理
echo "配置Docker中国代理..."
docker_config="/etc/docker/daemon.json"
mkdir -p /etc/docker

# 生成daemon.json配置
echo '{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://proxy.1panel.live",
    "https://docker.1panel.top",
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://docker.ketches.cn",
    "https://docker.xuanyuan.me/"
  ]
}' > $docker_config

echo "Docker代理配置已更新"
echo "配置文件: $docker_config"
echo "使用的代理地址:"
echo "  - https://docker.mirrors.ustc.edu.cn"
echo "  - https://hub-mirror.c.163.com"
echo "  - https://mirror.baidubce.com"
echo "  - https://proxy.1panel.live"
echo "  - https://docker.1panel.top"
echo "  - https://docker.m.daocloud.io"
echo "  - https://docker.1ms.run"
echo "  - https://docker.ketches.cn"
echo "  - https://docker.xuanyuan.me/"

# 重启Docker服务使配置生效
echo "重启Docker服务..."
systemctl restart docker
echo "Docker服务已重启，代理配置生效"

# 验证Docker状态
echo "验证Docker状态..."
systemctl status docker --no-pager | head -20

echo "docker installed!"