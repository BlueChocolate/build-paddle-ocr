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
    echo "使用: sudo bash install.sh"
    exit 1
fi

# 定义变量
INSTALL_DIR="/opt/qzwb/paddlex-ocr"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="paddlex-ocr.tar"

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  PaddleX OCR 安装脚本${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}错误: Docker Compose 未安装，请先安装 Docker Compose${NC}"
    exit 1
fi

# 检查必需文件是否存在
echo -e "${YELLOW}[1/6] 检查必需文件...${NC}"
required_files=("$IMAGE_FILE" "docker-compose.yml" "pipeline.yaml")
for file in "${required_files[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        echo -e "${RED}错误: 找不到文件 $file${NC}"
        exit 1
    fi
    echo "  ✓ $file"
done

if [ ! -d "$SCRIPT_DIR/models" ]; then
    echo -e "${YELLOW}警告: models 目录不存在，将创建空目录${NC}"
fi

# 创建安装目录
echo -e "${YELLOW}[2/6] 创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"
echo "  ✓ 创建目录: $INSTALL_DIR"

# 复制文件到安装目录
echo -e "${YELLOW}[3/6] 复制文件到安装目录...${NC}"
cp -f "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_DIR/"
echo "  ✓ docker-compose.yml"
cp -f "$SCRIPT_DIR/pipeline.yaml" "$INSTALL_DIR/"
echo "  ✓ pipeline.yaml"
cp -f "$SCRIPT_DIR/$IMAGE_FILE" "$INSTALL_DIR/"
echo "  ✓ $IMAGE_FILE"

if [ -d "$SCRIPT_DIR/models" ]; then
    cp -rf "$SCRIPT_DIR/models" "$INSTALL_DIR/"
    echo "  ✓ models/"
else
    mkdir -p "$INSTALL_DIR/models"
    echo "  ✓ 创建空的 models/"
fi

# 加载 Docker 镜像
echo -e "${YELLOW}[4/6] 加载 Docker 镜像...${NC}"
echo "  这可能需要几分钟，请耐心等待..."
if docker load -i "$INSTALL_DIR/$IMAGE_FILE"; then
    echo -e "  ${GREEN}✓ 镜像加载成功${NC}"
    # 加载完成后删除 tar 文件以节省空间
    rm -f "$INSTALL_DIR/$IMAGE_FILE"
    echo "  ✓ 已删除镜像文件以节省空间"
else
    echo -e "${RED}错误: 镜像加载失败${NC}"
    exit 1
fi

# 启动 Docker Compose 服务
echo -e "${YELLOW}[5/6] 启动 PaddleX OCR 服务...${NC}"
cd "$INSTALL_DIR"
if command -v docker compose &> /dev/null; then
    docker compose up -d
else
    docker-compose up -d
fi
echo -e "  ${GREEN}✓ 服务启动成功${NC}"

# 启用 Docker 开机自启
echo -e "${YELLOW}[6/6] 配置 Docker 开机自启...${NC}"
if systemctl is-enabled docker &> /dev/null; then
    echo "  ✓ Docker 服务已设置为开机自启"
else
    if systemctl enable docker; then
        echo -e "  ${GREEN}✓ 已启用 Docker 开机自启${NC}"
    else
        echo -e "  ${YELLOW}⚠ 无法启用 Docker 开机自启，请手动配置${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  安装完成！${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "安装位置: $INSTALL_DIR"
echo "服务地址: http://localhost:25601"
echo ""
echo "服务管理命令:"
echo "  启动服务: cd $INSTALL_DIR && docker compose up -d"
echo "  停止服务: cd $INSTALL_DIR && docker compose down"
echo "  查看日志: cd $INSTALL_DIR && docker compose logs -f"
echo "  查看状态: docker ps | grep paddlex-ocr"
echo ""
echo -e "${YELLOW}说明:${NC}"
echo "  - 服务已配置为崩溃自动重启 (restart: unless-stopped)"
echo "  - Docker 开机自启后，容器会自动启动"
echo "  - 模型文件位于: $INSTALL_DIR/models/"
echo ""
