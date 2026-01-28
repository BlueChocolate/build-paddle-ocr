FROM python:3.10-slim-bookworm

WORKDIR /app

# PaddleX / OpenCV 运行时依赖
RUN apt-get update && apt-get install -y \
    libgomp1 \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Python 依赖
RUN pip install --no-cache-dir paddlepaddle==3.2.2 -i https://www.paddlepaddle.org.cn/packages/stable/cpu/

# 拷贝启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
