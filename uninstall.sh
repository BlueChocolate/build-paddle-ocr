#!/usr/bin/env bash
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 请使用 root 权限运行此脚本${NC}"
    echo "使用: sudo bash uninstall.sh"
    exit 1
fi

# 定义变量
INSTALL_DIR="/opt/qzwb/paddlex-ocr"
IMAGE_NAME="paddlex-ocr"
CONTAINER_NAME="paddlex-ocr"

echo -e "${RED}=====================================${NC}"
echo -e "${RED}  PaddleX OCR 卸载脚本${NC}"
echo -e "${RED}=====================================${NC}"
echo ""

# 确认卸载
read -p "确认要卸载 PaddleX OCR 吗？这将删除容器和镜像 [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消卸载"
    exit 0
fi

# 停止并删除容器
echo -e "${YELLOW}[1/4] 停止并删除容器...${NC}"
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
    cd "$INSTALL_DIR"
    docker compose down 2>/dev/null || echo "  容器可能已经停止"
    echo -e "  ${GREEN}✓ 容器已停止并删除${NC}"
else
    # 如果 docker-compose.yml 不存在，直接删除容器
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        echo -e "  ${GREEN}✓ 容器已停止并删除${NC}"
    else
        echo "  ℹ 容器不存在，跳过"
    fi
fi

# 删除 Docker 镜像
echo -e "${YELLOW}[2/4] 删除 Docker 镜像...${NC}"
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}:"; then
    # 获取所有匹配的镜像
    images=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${IMAGE_NAME}:")
    for image in $images; do
        echo "  删除镜像: $image"
        docker rmi "$image" 2>/dev/null || echo "  无法删除镜像 $image"
    done
    echo -e "  ${GREEN}✓ 镜像已删除${NC}"
else
    echo "  ℹ 镜像不存在，跳过"
fi

# 询问是否删除安装目录
echo ""
read -p "是否删除安装目录及所有数据 ($INSTALL_DIR)？[y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[3/4] 删除安装目录...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo -e "  ${GREEN}✓ 安装目录已删除${NC}"
    else
        echo "  ℹ 安装目录不存在，跳过"
    fi
else
    echo -e "${YELLOW}[3/4] 保留安装目录${NC}"
    echo "  ℹ 安装目录保留在: $INSTALL_DIR"
fi

# 清理悬空镜像（可选）
echo -e "${YELLOW}[4/4] 清理悬空镜像...${NC}"
dangling=$(docker images -f "dangling=true" -q)
if [ -n "$dangling" ]; then
    docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
    echo -e "  ${GREEN}✓ 悬空镜像已清理${NC}"
else
    echo "  ℹ 没有悬空镜像需要清理"
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  卸载完成！${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "已完成以下操作:"
echo "  ✓ 停止并删除容器"
echo "  ✓ 删除 Docker 镜像"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  ✓ 删除安装目录"
else
    echo "  - 保留安装目录 (可手动删除: rm -rf $INSTALL_DIR)"
fi
echo ""
