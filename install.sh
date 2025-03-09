#!/bin/bash
set -euxo pipefail  # Включаем строгий режим выполнения

# 🔹 Переменная с именем контейнера и тегом
IMAGE_NAME="dicoop/blockchain_v5.1.1"
TAG="dev"

# 🔹 Проверка, залогинен ли пользователь в Docker Hub
if ! docker info | grep -q "Username"; then
    echo "❌ Вы не залогинены в Docker Hub! Выполните: docker login"
    exit 1
fi

# 🔹 Создаем билдера, если его нет
if ! docker buildx ls | grep -q "multiarchbuilder"; then
    docker buildx create --name multiarchbuilder --use
    docker buildx inspect --bootstrap
fi

# 🔹 Сборка образа для linux/amd64
docker buildx build \
    --platform linux/amd64 \
    -t "${IMAGE_NAME}:${TAG}-amd64" \
    --build-arg PLATFORM=amd64 \
    --load \
    -f Dockerfile .

# 🔹 Сборка образа для linux/arm64
docker buildx build \
    --platform linux/arm64 \
    -t "${IMAGE_NAME}:${TAG}-arm64" \
    --build-arg PLATFORM=arm64 \
    --load \
    -f Dockerfile .

# 🔹 Пуш отдельных архитектур в Docker Hub
docker tag "${IMAGE_NAME}:${TAG}-amd64" "${IMAGE_NAME}:${TAG}-amd64"
docker push "${IMAGE_NAME}:${TAG}-amd64"

docker tag "${IMAGE_NAME}:${TAG}-arm64" "${IMAGE_NAME}:${TAG}-arm64"
docker push "${IMAGE_NAME}:${TAG}-arm64"

# 🔹 Объединение образов в multi-arch
docker buildx imagetools create \
    -t "${IMAGE_NAME}:${TAG}" \
    "${IMAGE_NAME}:${TAG}-amd64" \
    "${IMAGE_NAME}:${TAG}-arm64"

echo "✅ Сборка и пуш образа ${IMAGE_NAME}:${TAG} завершены!"

