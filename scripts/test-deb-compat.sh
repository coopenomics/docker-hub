#!/usr/bin/env bash
set -euo pipefail

# Тест миграции .deb v5.1.0 → v5.2.0 на ОДНОМ data dir, без replay.
# Симулирует продакшн-апгрейд: stop → install new .deb → start.
#
# Этап 1: coopos-deb:5.1.0 со снапшота — ждём прогресс блоков, фиксируем head.
# Этап 2: coopos-deb:5.2.0 на том же data dir БЕЗ --clean и БЕЗ --from-snapshot —
#         если стейт совместим, нода поднимется и продолжит с того же блока.
#
# Перед запуском: ./scripts/fetch-debs.sh && ./scripts/build-deb-image.sh --all

cd "$(dirname "$0")/.."

OLD_TAG="${OLD_TAG:-5.1.0}"
NEW_TAG="${NEW_TAG:-5.2.0}"
WAIT_SECONDS="${WAIT_SECONDS:-180}"
MIN_BLOCKS="${MIN_BLOCKS:-50}"

PORT="${NODE_HTTP_PORT:-8888}"
URL="http://127.0.0.1:${PORT}/v1/chain/get_info"

get_field() { curl -fsS --max-time 5 "$URL" 2>/dev/null | sed -n "s/.*\"$1\":\"\\([^\"]*\\)\".*/\\1/p"; }
get_head()  { curl -fsS --max-time 5 "$URL" 2>/dev/null | sed -n 's/.*"head_block_num":\([0-9]*\).*/\1/p'; }

wait_api() {
  local label="$1" t=0 head=""
  while [ -z "$head" ] && [ $t -lt 120 ]; do
    head=$(get_head || true); sleep 3; t=$((t+3))
  done
  if [ -z "$head" ]; then
    echo "✗ [$label] API не поднялся за 120s" >&2
    docker compose logs --tail=80 node >&2
    exit 1
  fi
  echo "$head"
}

wait_progress() {
  local label="$1" target="$2" deadline=$(( SECONDS + WAIT_SECONDS )) head last=""
  while [ $SECONDS -lt $deadline ]; do
    head=$(get_head || true)
    if [ -n "$head" ] && [ "$head" -ge "$target" ]; then
      echo "  [$label] head=$head ≥ $target ✓" >&2
      echo "$head"
      return 0
    fi
    if [ -n "$head" ] && [ "$head" != "$last" ]; then
      echo "  [$label] head=$head (target ≥ $target)" >&2
      last="$head"
    fi
    sleep 3
  done
  echo "✗ [$label] head не дорос до $target за ${WAIT_SECONDS}s" >&2
  return 1
}

assert_no_fatal() {
  local label="$1"
  if docker compose logs --tail=500 node 2>&1 | grep -Ei 'wrong chain id|protocol feature.*not activated|unlinkable block|database dirty flag set|content of memory does not match' | head -3; then
    echo "✗ [$label] критические ошибки в логах" >&2; return 1
  fi
}

# ── проверка артефактов ──────────────────────────────────────────────
for v in "$OLD_TAG" "$NEW_TAG"; do
  if ! docker image inspect "coopos-deb:${v}" >/dev/null 2>&1; then
    echo "✗ образ coopos-deb:${v} не найден. Сначала ./scripts/build-deb-image.sh --all" >&2
    exit 1
  fi
done
if [ ! -s snapshot.bin ]; then
  ./scripts/fetch-snapshot.sh
fi

# ── ЭТАП 1: старая версия со снапшота ────────────────────────────────
echo "═══ ЭТАП 1: coopos-deb:${OLD_TAG} со снапшота ═══"
./scripts/start.sh --image coopos-deb --tag "$OLD_TAG" --from-snapshot --clean

HEAD_INIT=$(wait_api "OLD")
echo "  [OLD] версия: $(get_field server_version_string), chain_id: $(get_field chain_id)"
echo "  [OLD] стартовый head: $HEAD_INIT"

HEAD_OLD=$(wait_progress "OLD" $((HEAD_INIT + MIN_BLOCKS)))
assert_no_fatal "OLD"

# ── переход на новую версию БЕЗ очистки data ────────────────────────
echo
echo "═══ ЭТАП 2: переключение на coopos-deb:${NEW_TAG} (тот же data/) ═══"
./scripts/stop.sh
./scripts/start.sh --image coopos-deb --tag "$NEW_TAG"

HEAD_RESUME=$(wait_api "NEW")
echo "  [NEW] версия: $(get_field server_version_string), chain_id: $(get_field chain_id)"
echo "  [NEW] head после рестарта: $HEAD_RESUME"

if [ "$HEAD_RESUME" -lt "$HEAD_OLD" ]; then
  echo "✗ head после переключения ($HEAD_RESUME) < до переключения ($HEAD_OLD): стейт не подхвачен" >&2
  exit 1
fi

HEAD_NEW=$(wait_progress "NEW" $((HEAD_RESUME + MIN_BLOCKS)))
assert_no_fatal "NEW"

# ── остановим тестовый контейнер, чтобы не висел ────────────────────
./scripts/stop.sh

echo
echo "✅ DEB-MIGRATION: OK"
echo "   ${OLD_TAG}: $HEAD_INIT → $HEAD_OLD"
echo "   ${NEW_TAG}: $HEAD_RESUME → $HEAD_NEW (продолжил с того же стейта)"
echo
echo "Вывод: апгрейд .deb ${OLD_TAG} → ${NEW_TAG} на проде безопасен,"
echo "       replay не нужен, hot-swap data dir совместим."
