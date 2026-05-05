#!/usr/bin/env bash
set -euo pipefail

# Поднимает coopos-node по docker-compose.
#
# Флаги:
#   --image <name>     имя образа (по умолчанию dicoop/blockchain)
#   --tag <tag>        тег образа (по умолчанию latest)
#   --from-snapshot    добавить --snapshot к nodeos (требует пустой data/)
#   --replay           добавить --replay-blockchain (пересобирает state из blocks.log)
#   --hard-replay      добавить --hard-replay-blockchain (если blocks.log повреждён)
#   --clean            предварительно удалить data/ (для применения снапшота)
#   --follow           tail логов после старта
#   --extra "<args>"   произвольные доп.аргументы к nodeos
#
# Снапшот применяется один раз — при пустом data/. Replay — когда меняется
# версия nodeos и shared_memory не совместим со стейтом старой версии.

cd "$(dirname "$0")/.."

IMAGE="dicoop/blockchain"
TAG="latest"
FROM_SNAPSHOT=0
REPLAY=""
CLEAN=0
FOLLOW=0
USER_EXTRA=""

while [ $# -gt 0 ]; do
  case "$1" in
    --image)          IMAGE="$2"; shift 2 ;;
    --tag)            TAG="$2"; shift 2 ;;
    --from-snapshot)  FROM_SNAPSHOT=1; shift ;;
    --replay)         REPLAY="--replay-blockchain"; shift ;;
    --hard-replay)    REPLAY="--hard-replay-blockchain"; shift ;;
    --clean)          CLEAN=1; shift ;;
    --follow|-f)      FOLLOW=1; shift ;;
    --extra)          USER_EXTRA="$2"; shift 2 ;;
    -h|--help)
      sed -n '3,18p' "$0"; exit 0 ;;
    *)
      echo "неизвестный флаг: $1" >&2; exit 2 ;;
  esac
done

if [ "$CLEAN" -eq 1 ]; then
  echo "→ очищаю data/"
  docker compose down 2>/dev/null || true
  if [ -d data ]; then
    # Файлы внутри созданы root в контейнере, поэтому чистим через одноразовый контейнер.
    docker run --rm -v "$(pwd)/data:/d" --entrypoint sh "${IMAGE}:${TAG}" -c 'rm -rf /d/* /d/.[!.]* /d/..?* 2>/dev/null || true'
  fi
fi

mkdir -p data

EXTRA_ARGS=""
if [ "$FROM_SNAPSHOT" -eq 1 ]; then
  if [ ! -s snapshot.bin ]; then
    echo "→ snapshot.bin отсутствует, качаю"
    ./scripts/fetch-snapshot.sh
  fi
  if [ -n "$(ls -A data 2>/dev/null)" ]; then
    echo "✗ data/ непустой — снапшот применить нельзя. Запусти с --clean." >&2
    exit 1
  fi
  EXTRA_ARGS="--snapshot /root/blockchain/snapshot.bin"
fi
if [ -n "$REPLAY" ]; then
  EXTRA_ARGS="${EXTRA_ARGS} ${REPLAY}"
fi
if [ -n "$USER_EXTRA" ]; then
  EXTRA_ARGS="${EXTRA_ARGS} ${USER_EXTRA}"
fi
EXTRA_ARGS="$(echo "$EXTRA_ARGS" | sed 's/^ *//;s/ *$//')"

cat > .env <<EOF
BLOCKCHAIN_IMAGE=${IMAGE}
BLOCKCHAIN_TAG=${TAG}
EXTRA_ARGS=${EXTRA_ARGS}
NODE_HTTP_PORT=${NODE_HTTP_PORT:-8888}
NODE_P2P_PORT=${NODE_P2P_PORT:-9876}
NODE_HISTORY_PORT=${NODE_HISTORY_PORT:-8088}
EOF

# pull только для образов, которые есть в реестре (для self-built coopos-deb это не нужно).
if [ "$IMAGE" = "dicoop/blockchain" ]; then
  echo "→ pull ${IMAGE}:${TAG}"
  docker compose pull node
fi

echo "→ up (image=${IMAGE}:${TAG}, extra='${EXTRA_ARGS}')"
docker compose up -d

if [ "$FOLLOW" -eq 1 ]; then
  exec docker compose logs -f node
fi

echo "✓ нода запущена. Логи: docker compose logs -f node"
echo "  status: ./scripts/status.sh"
