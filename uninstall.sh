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
    echo "使用: sudo bash uninstall.sh"
    exit 1
fi

# 定义变量
INSTALL_DIR="/opt/qzwb/paddlex-ocr"
IMAGE_NAME="paddlex-ocr"

# 支持的版本标签
SUPPORTED_TAGS=("hpi" "basic")

echo -e "${RED}=====================================${NC}"
echo -e "${RED}  PaddleX OCR 卸载脚本${NC}"
echo -e "${RED}=====================================${NC}"
echo ""

# 检测已安装的容器
echo -e "${YELLOW}检测已安装的版本...${NC}"
installed_containers=()
for tag in "${SUPPORTED_TAGS[@]}"; do
    container_name="paddlex-ocr-$tag"
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        installed_containers+=("$tag")
        echo -e "  ${BLUE}[检测到] $container_name${NC}"
    fi
done

# 也检查旧版本容器（paddlex-ocr，无标签后缀）
if docker ps -a --format '{{.Names}}' | grep -q "^paddlex-ocr$"; then
    installed_containers+=("legacy")
    echo -e "  ${BLUE}[检测到] paddlex-ocr (旧版本)${NC}"
fi

if [ ${#installed_containers[@]} -eq 0 ]; then
    echo -e "${YELLOW}未检测到已安装的 PaddleX OCR 容器${NC}"
    
    # 检查是否有镜像需要清理
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}:"; then
        echo ""
        read -p "检测到残留的镜像，是否清理？[y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            images=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${IMAGE_NAME}:")
            for image in $images; do
                echo "  删除镜像: $image"
                docker rmi "$image" 2>/dev/null || echo "  无法删除镜像 $image"
            done
            echo -e "  ${GREEN}✓ 镜像清理完成${NC}"
        fi
    fi
    
    # 检查安装目录
    if [ -d "$INSTALL_DIR" ]; then
        echo ""
        read -p "是否删除安装目录 ($INSTALL_DIR)？[y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
            echo -e "  ${GREEN}✓ 安装目录已删除${NC}"
        fi
    fi
    
    exit 0
fi

echo ""
echo -e "${YELLOW}将卸载以下容器:${NC}"
for tag in "${installed_containers[@]}"; do
    if [ "$tag" == "legacy" ]; then
        echo "  - paddlex-ocr (旧版本)"
    else
        echo "  - paddlex-ocr-$tag"
    fi
done
echo ""

# 确认卸载
read -p "确认要卸载吗？这将删除容器和镜像 [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消卸载"
    exit 0
fi

# 停止并删除容器
echo -e "${YELLOW}[1/4] 停止并删除容器...${NC}"
for tag in "${installed_containers[@]}"; do
    if [ "$tag" == "legacy" ]; then
        container_name="paddlex-ocr"
    else
        container_name="paddlex-ocr-$tag"
    fi
    
    echo "  处理容器: $container_name"
    
    # 尝试使用 docker compose 停止
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        cd "$INSTALL_DIR"
        if [ "$tag" != "legacy" ]; then
            PADDLEX_TAG="$tag" docker compose down 2>/dev/null || true
        else
            docker compose down 2>/dev/null || true
        fi
    fi
    
    # 确保容器被删除
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
    echo -e "  ${GREEN}✓ $container_name 已停止并删除${NC}"
done

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
DELETED_DIR=false
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[3/4] 删除安装目录...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        DELETED_DIR=true
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
echo "  ✓ 停止并删除容器:"
for tag in "${installed_containers[@]}"; do
    if [ "$tag" == "legacy" ]; then
        echo "    - paddlex-ocr (旧版本)"
    else
        echo "    - paddlex-ocr-$tag"
    fi
done
echo "  ✓ 删除 Docker 镜像"
if [ "$DELETED_DIR" = true ]; then
    echo "  ✓ 删除安装目录"
else
    echo "  - 保留安装目录 (可手动删除: rm -rf $INSTALL_DIR)"
fi
echo ""
