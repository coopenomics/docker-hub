#!/usr/bin/env bash
set -euo pipefail

# Поднимает локальный writable-форк прод-снапшота:
#   1) если нет snapshot.bin — качает с прод-эндпоинта
#   2) если нет snapshot-fork.bin — патчит снапшот dev-ключом
#   3) запускает nodeos с config-fork (без p2p, with producer eosio + dev-key)
#
# Контейнер называется coopos-fork (отдельно от coopos-node, чтобы не путать).
# Порты те же: 8888 (HTTP), 9876 (P2P listen, никуда не подключаемся), 8088→8080 (state-history).

cd "$(dirname "$0")/.."

TAG="5.2.0"
CLEAN=0
FOLLOW=0

while [ $# -gt 0 ]; do
  case "$1" in
    --tag)        TAG="$2"; shift 2 ;;
    --clean)      CLEAN=1; shift ;;
    --follow|-f)  FOLLOW=1; shift ;;
    -h|--help)    sed -n '3,12p' "$0"; exit 0 ;;
    *) echo "неизвестный флаг: $1" >&2; exit 2 ;;
  esac
done

if ! docker image inspect "coopos-deb:${TAG}" >/dev/null 2>&1; then
  echo "✗ образ coopos-deb:${TAG} не найден. Сначала ./scripts/build-deb-image.sh ${TAG}" >&2
  exit 1
fi
if [ ! -f config-fork/config.ini ]; then
  echo "✗ config-fork/config.ini отсутствует" >&2
  exit 1
fi
if [ ! -s snapshot.bin ]; then
  echo "→ snapshot.bin отсутствует, качаю"
  ./scripts/fetch-snapshot.sh
fi
if [ ! -s snapshot-fork.bin ]; then
  echo "→ snapshot-fork.bin отсутствует, патчу dev-fork.jq"
  ./scripts/fork-snapshot.sh --tag "$TAG" --patch patches/dev-fork.jq --out snapshot-fork.bin
fi

# гасим всё, что могло остаться от предыдущих запусков
docker rm -f coopos-fork coopos-node >/dev/null 2>&1 || true
docker compose down >/dev/null 2>&1 || true

if [ "$CLEAN" -eq 1 ] && [ -d data ]; then
  echo "→ очищаю data/"
  docker run --rm -v "$(pwd)/data:/d" --entrypoint sh "coopos-deb:${TAG}" \
    -c 'rm -rf /d/* /d/.[!.]* /d/..?* 2>/dev/null || true'
fi
mkdir -p data

if [ -n "$(ls -A data 2>/dev/null)" ]; then
  echo "✗ data/ непустой. Запусти с --clean чтобы применить snapshot-fork.bin." >&2
  exit 1
fi

echo "→ старт coopos-fork (image=coopos-deb:${TAG})"
docker run -d --name coopos-fork \
  -p "${NODE_HTTP_PORT:-8888}:8888" \
  -p "${NODE_P2P_PORT:-9876}:9876" \
  -p "${NODE_HISTORY_PORT:-8088}:8080" \
  -v "$(pwd)/data:/root/blockchain/data" \
  -v "$(pwd)/config-fork:/root/blockchain/config" \
  -v "$(pwd)/snapshot-fork.bin:/root/blockchain/snapshot.bin:ro" \
  --entrypoint /usr/local/bin/nodeos \
  "coopos-deb:${TAG}" \
  --config-dir /root/blockchain/config \
  --data-dir /root/blockchain/data \
  --snapshot /root/blockchain/snapshot.bin >/dev/null

echo "✓ coopos-fork запущен"
echo "  api:    http://127.0.0.1:${NODE_HTTP_PORT:-8888}"
echo "  logs:   docker logs -f coopos-fork"
echo "  status: ./scripts/status.sh"
echo "  stop:   docker stop coopos-fork && docker rm coopos-fork"
echo
echo "Импортировать dev-key в кошелёк (для cleos):"
echo "  cleos wallet create --to-console"
echo "  cleos wallet import --private-key 5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3"

if [ "$FOLLOW" -eq 1 ]; then
  exec docker logs -f coopos-fork
fi
