#!/usr/bin/env bash
set -euo pipefail

# Тест snapshot-совместимости двух версий nodeos.
#
# Между v5.1.0-dev и v5.2.0-dev формат shared_memory несовместим — нельзя
# просто переключить тег на том же data/. Зато формат снапшота одинаковый,
# поэтому миграция возможна через снапшот:
#   1) старая версия поднимается из снапшота, синхронит блоки;
#   2) останавливаем, чистим data/;
#   3) новая версия поднимается из ТОГО ЖЕ снапшота, тоже синхронит.
# Если оба этапа проходят — для миграции достаточно: остановить прод,
# создать снапшот, очистить state, запустить новую версию --snapshot.

cd "$(dirname "$0")/.."

OLD_TAG="${OLD_TAG:-v5.1.0-dev}"
NEW_TAG="${NEW_TAG:-latest}"
WAIT_SECONDS="${WAIT_SECONDS:-180}"
MIN_BLOCKS="${MIN_BLOCKS:-50}"

PORT="${NODE_HTTP_PORT:-8888}"
URL="http://127.0.0.1:${PORT}/v1/chain/get_info"

get_head() {
  curl -fsS --max-time 5 "$URL" 2>/dev/null | sed -n 's/.*"head_block_num":\([0-9]*\).*/\1/p'
}
get_version() {
  curl -fsS --max-time 5 "$URL" 2>/dev/null | sed -n 's/.*"server_version_string":"\([^"]*\)".*/\1/p'
}
get_chain_id() {
  curl -fsS --max-time 5 "$URL" 2>/dev/null | sed -n 's/.*"chain_id":"\([^"]*\)".*/\1/p'
}

wait_progress() {
  local label="$1" target="$2"
  local deadline=$(( SECONDS + WAIT_SECONDS )) head last=""
  while [ $SECONDS -lt $deadline ]; do
    head=$(get_head || true)
    if [ -n "$head" ] && [ "$head" -ge "$target" ]; then
      echo "  [$label] head=$head ✓"
      return 0
    fi
    if [ -n "$head" ] && [ "$head" != "$last" ]; then
      echo "  [$label] head=$head (target ≥ $target)"
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
    echo "✗ [$label] критические ошибки в логах" >&2
    return 1
  fi
}

run_stage() {
  local label="$1" tag="$2"
  echo "═══ $label: $tag со снапшота ═══"
  ./scripts/start.sh --tag "$tag" --from-snapshot --clean
  echo "→ ждём API..."
  local t=0 head=""
  while [ -z "$head" ] && [ $t -lt 120 ]; do
    head=$(get_head || true); sleep 3; t=$((t+3))
  done
  if [ -z "$head" ]; then
    echo "✗ [$label] API не поднялся" >&2
    docker compose logs --tail=80 node
    return 1
  fi
  echo "  [$label] версия: $(get_version), chain_id: $(get_chain_id)"
  echo "  [$label] стартовый head: $head"
  wait_progress "$label" $((head + MIN_BLOCKS))
  assert_no_fatal "$label"
}

if [ ! -s snapshot.bin ]; then
  ./scripts/fetch-snapshot.sh
fi

run_stage "OLD" "$OLD_TAG"
./scripts/stop.sh
run_stage "NEW" "$NEW_TAG"
./scripts/stop.sh

echo
echo "✅ SNAPSHOT-COMPAT: оба тега подняты со снапшота, голова растёт."
echo "   Миграция: stop OLD → snapshot → clean data/ → start NEW --from-snapshot."
