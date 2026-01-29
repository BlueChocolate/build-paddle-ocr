#!/usr/bin/env bash
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 支持的镜像配置
declare -A IMAGE_FILES
IMAGE_FILES["hpi"]="paddlex-ocr-hpi.tar"
IMAGE_FILES["basic"]="paddlex-ocr-basic.tar"

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  PaddleX OCR 安装脚本${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

# 检查 Docker Compose 是否安装（使用白名单方式检测）
echo -e "${YELLOW}检查 Docker Compose...${NC}"
COMPOSE_VERSION=$(docker compose version 2>/dev/null || true)
if [[ "$COMPOSE_VERSION" == *"Docker Compose version"* ]]; then
    echo -e "  ${GREEN}[OK] $COMPOSE_VERSION${NC}"
else
    echo -e "${RED}错误: Docker Compose 未安装或不可用${NC}"
    echo "请确保已安装 Docker Compose 插件"
    echo "安装方法: https://docs.docker.com/compose/install/"
    exit 1
fi

# 检测目录中存在的镜像文件
echo -e "${YELLOW}检测可用的镜像文件...${NC}"
available_images=()
for tag in "${!IMAGE_FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/${IMAGE_FILES[$tag]}" ]; then
        available_images+=("$tag")
        echo -e "  ${GREEN}[找到] ${IMAGE_FILES[$tag]} -> paddlex-ocr:$tag${NC}"
    fi
done

if [ ${#available_images[@]} -eq 0 ]; then
    echo -e "${RED}错误: 未找到任何镜像文件${NC}"
    echo "请确保以下文件之一存在:"
    for tag in "${!IMAGE_FILES[@]}"; do
        echo "  - ${IMAGE_FILES[$tag]}"
    done
    exit 1
fi

# 选择要安装的镜像
if [ ${#available_images[@]} -eq 1 ]; then
    SELECTED_TAG="${available_images[0]}"
    echo -e "${BLUE}只检测到一个镜像文件，将自动安装: paddlex-ocr:$SELECTED_TAG${NC}"
else
    echo ""
    echo -e "${BLUE}检测到多个可用镜像，请选择要安装的版本:${NC}"
    for i in "${!available_images[@]}"; do
        tag="${available_images[$i]}"
        echo "  $((i+1)). paddlex-ocr:$tag (${IMAGE_FILES[$tag]})"
    done
    echo ""
    while true; do
        read -p "请输入选项 [1-${#available_images[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#available_images[@]} ]; then
            SELECTED_TAG="${available_images[$((choice-1))]}"
            break
        else
            echo -e "${RED}无效的选项，请重新输入${NC}"
        fi
    done
fi

SELECTED_IMAGE_FILE="${IMAGE_FILES[$SELECTED_TAG]}"
echo ""
echo -e "${GREEN}已选择: paddlex-ocr:$SELECTED_TAG${NC}"

# 检查是否已有其他版本的容器在运行
echo -e "${YELLOW}检查已安装的版本...${NC}"
for tag in "${!IMAGE_FILES[@]}"; do
    container_name="paddlex-ocr-$tag"
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        if [ "$tag" != "$SELECTED_TAG" ]; then
            echo -e "${RED}错误: 检测到已安装其他版本 (paddlex-ocr:$tag)${NC}"
            echo "请先运行卸载脚本移除已安装的版本:"
            echo "  sudo bash uninstall.sh"
            exit 1
        else
            echo -e "${YELLOW}检测到相同版本已安装，将进行更新${NC}"
        fi
    fi
done
echo -e "  ${GREEN}[OK] 版本检查通过${NC}"

# 检查端口是否被占用（排除当前版本的容器）
echo -e "${YELLOW}[1/7] 检查端口占用...${NC}"
SERVICE_PORT=25601
current_container="paddlex-ocr-$SELECTED_TAG"

# 检查端口占用，但排除当前要安装的容器
if ss -tuln 2>/dev/null | grep -q ":$SERVICE_PORT " || netstat -tuln 2>/dev/null | grep -q ":$SERVICE_PORT "; then
    # 检查是否是当前容器占用的端口
    if docker ps --format '{{.Names}}' | grep -q "^${current_container}$"; then
        echo "  [OK] 端口 $SERVICE_PORT 被当前容器使用，将进行更新"
    else
        echo -e "${RED}错误: 端口 $SERVICE_PORT 已被占用${NC}"
        echo "请先停止占用该端口的服务"
        exit 1
    fi
else
    echo "  [OK] 端口 $SERVICE_PORT 可用"
fi

# 检查必需文件是否存在
echo -e "${YELLOW}[2/7] 检查必需文件...${NC}"
required_files=("$SELECTED_IMAGE_FILE" "docker-compose.yml" "pipeline.yaml")
for file in "${required_files[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        echo -e "${RED}错误: 找不到文件 $file${NC}"
        exit 1
    fi
    echo "  [OK] $file"
done

if [ ! -d "$SCRIPT_DIR/cache" ]; then
    echo -e "${YELLOW}警告: cache 目录不存在，将创建空目录${NC}"
fi

# 创建安装目录
echo -e "${YELLOW}[3/7] 创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"
echo "  [OK] 创建目录: $INSTALL_DIR"

# 复制文件到安装目录
echo -e "${YELLOW}[4/7] 复制文件到安装目录...${NC}"
cp -f "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_DIR/"
echo "  [OK] docker-compose.yml"
cp -f "$SCRIPT_DIR/pipeline.yaml" "$INSTALL_DIR/"
echo "  [OK] pipeline.yaml"
cp -f "$SCRIPT_DIR/$SELECTED_IMAGE_FILE" "$INSTALL_DIR/"
echo "  [OK] $SELECTED_IMAGE_FILE"

# 保存当前安装的版本信息
echo "$SELECTED_TAG" > "$INSTALL_DIR/.installed_tag"
echo "  [OK] 记录安装版本: $SELECTED_TAG"

if [ -d "$SCRIPT_DIR/cache" ]; then
    cp -rf "$SCRIPT_DIR/cache" "$INSTALL_DIR/"
    echo "  [OK] cache/"
else
    mkdir -p "$INSTALL_DIR/cache"
    echo "  [OK] 创建空的 cache/"
fi

# 加载 Docker 镜像
echo -e "${YELLOW}[5/7] 加载 Docker 镜像...${NC}"
echo "  这可能需要几分钟，请耐心等待..."
if docker load -i "$INSTALL_DIR/$SELECTED_IMAGE_FILE"; then
    echo -e "  ${GREEN}[OK] 镜像加载成功: paddlex-ocr:$SELECTED_TAG${NC}"
else
    echo -e "${RED}错误: 镜像加载失败${NC}"
    exit 1
fi

# 启动 Docker 服务
echo -e "${YELLOW}[6/7] 启动 PaddleX OCR 服务...${NC}"
cd "$INSTALL_DIR"

# 停止并删除旧容器（如果存在）
docker stop "paddlex-ocr-$SELECTED_TAG" 2>/dev/null || true
docker rm "paddlex-ocr-$SELECTED_TAG" 2>/dev/null || true

# 使用环境变量启动对应版本的容器
if PADDLEX_TAG="$SELECTED_TAG" docker compose up -d; then
    echo -e "  ${GREEN}[OK] 服务启动成功${NC}"
else
    echo -e "${RED}错误: 服务启动失败${NC}"
    echo "请检查 docker-compose.yml 配置或查看日志: docker compose logs"
    exit 1
fi

# 启用 Docker 开机自启
echo -e "${YELLOW}[7/7] 配置 Docker 开机自启...${NC}"
if systemctl is-enabled docker &> /dev/null; then
    echo "  [OK] Docker 服务已设置为开机自启"
else
    if systemctl enable docker; then
        echo -e "  ${GREEN}[OK] 已启用 Docker 开机自启${NC}"
    else
        echo -e "  ${YELLOW}[WARN] 无法启用 Docker 开机自启，请手动配置${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  安装完成！${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "安装版本: paddlex-ocr:$SELECTED_TAG"
echo "安装位置: $INSTALL_DIR"
echo "服务地址: http://localhost:25601"
echo ""
echo "服务管理命令:"
echo "  启动服务: cd $INSTALL_DIR && PADDLEX_TAG=$SELECTED_TAG docker compose up -d"
echo "  停止服务: cd $INSTALL_DIR && PADDLEX_TAG=$SELECTED_TAG docker compose down"
echo "  查看日志: cd $INSTALL_DIR && PADDLEX_TAG=$SELECTED_TAG docker compose logs -f"
echo "  查看状态: docker ps | grep paddlex-ocr"
echo ""
echo -e "${YELLOW}说明:${NC}"
echo "  - 服务已配置为崩溃自动重启 (restart: unless-stopped)"
echo "  - Docker 开机自启后，容器会自动启动"
echo "  - PaddleX 缓存目录: $INSTALL_DIR/cache/"
echo ""
