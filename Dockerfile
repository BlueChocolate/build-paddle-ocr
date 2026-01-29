FROM python:3.10-slim-bookworm

# 构建参数：模式 (basic/hpi)
ARG MODE=basic

WORKDIR /app

# Paddle / OpenCV 运行时依赖
RUN apt-get update && apt-get install -y \
    libgomp1 \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Python 依赖
RUN pip install --no-cache-dir paddlepaddle==3.2.2 -i https://www.paddlepaddle.org.cn/packages/stable/cpu/ \
 && pip install --no-cache-dir paddlex[ocr]

# 安装 PaddleX 插件（根据 MODE 参数决定是否安装高性能推理）
RUN paddlex --install serving \
 && if [ "$MODE" = "hpi" ]; then \
        paddlex --install paddle2onnx && \
        paddlex --install hpi-cpu; \
    fi

# 拷贝启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
