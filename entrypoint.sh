#!/usr/bin/env bash
set -e

PIPELINE_FILE=${PIPELINE_FILE:-/data/pipeline.yaml}
DEFAULT_PIPELINE=${DEFAULT_PIPELINE:-OCR}
HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8080}
DEVICE=${DEVICE:-cpu}

echo "==== PaddleX OCR Service ===="
echo "Pipeline file: $PIPELINE_FILE"
echo "Default pipeline: $DEFAULT_PIPELINE"
echo "Device: $DEVICE"
echo "Listening on: $HOST:$PORT"
echo "============================="

if [ -f "$PIPELINE_FILE" ]; then
    echo "✔ Found pipeline config, using file"
    exec paddlex --serve \
        --pipeline "$PIPELINE_FILE" \
        --device "$DEVICE" \
        --host "$HOST" \
        --port "$PORT"
else
    echo "⚠ Pipeline file not found, fallback to pipeline name: $DEFAULT_PIPELINE"
    exec paddlex --serve \
        --pipeline "$DEFAULT_PIPELINE" \
        --device "$DEVICE" \
        --host "$HOST" \
        --port "$PORT"
fi
