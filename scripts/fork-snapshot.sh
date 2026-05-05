#!/usr/bin/env bash
set -euo pipefail

# Форкает прод-снапшот для локального тестового запуска:
#   1) бинарь → JSON (leap-util snapshot to-json)
#   2) применяет JQ-патч (подмена ключей, producer schedule, и т.п.)
#   3) JSON → бинарь (leap-util snapshot from-json)
#
# Требует образ coopos-deb:<version> с поддержкой 'snapshot from-json'
# (доступна с тега v5.2.0+, после пересборки .deb через CI).
#
# Использование:
#   ./scripts/fork-snapshot.sh                       # round-trip (без патча) — для отладки
#   ./scripts/fork-snapshot.sh --patch patches/dev-fork.jq
#   ./scripts/fork-snapshot.sh --patch patches/dev-fork.jq --in snapshot.bin --out snapshot-fork.bin
#   ./scripts/fork-snapshot.sh --tag 5.2.0 --keep-json   # сохраняет промежуточные .json

cd "$(dirname "$0")/.."

TAG="5.2.0"
IN="snapshot.bin"
OUT="snapshot-fork.bin"
PATCH=""
KEEP_JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --tag)        TAG="$2"; shift 2 ;;
    --in)         IN="$2"; shift 2 ;;
    --out)        OUT="$2"; shift 2 ;;
    --patch)      PATCH="$2"; shift 2 ;;
    --keep-json)  KEEP_JSON=1; shift ;;
    -h|--help)    sed -n '3,17p' "$0"; exit 0 ;;
    *) echo "неизвестный флаг: $1" >&2; exit 2 ;;
  esac
done

if [ ! -s "$IN" ]; then
  echo "✗ входной снапшот $IN не найден или пустой" >&2; exit 1
fi
if ! docker image inspect "coopos-deb:${TAG}" >/dev/null 2>&1; then
  echo "✗ образ coopos-deb:${TAG} не собран. Запусти ./scripts/build-deb-image.sh ${TAG}" >&2; exit 1
fi
if [ -n "$PATCH" ] && [ ! -f "$PATCH" ] && ! [[ "$PATCH" =~ ^[[:space:]]*\. ]]; then
  echo "✗ патч $PATCH не найден (ожидаю файл .jq или JQ-выражение начинающееся с '.')" >&2; exit 1
fi

ABS_IN="$(realpath "$IN")"
WORK="$(mktemp -d -p "$(pwd)" .fork.XXXXXX)"
trap '[ "$KEEP_JSON" -eq 1 ] || rm -rf "$WORK"' EXIT

cp "$ABS_IN" "$WORK/snap.bin"

run_in_image() {
  docker run --rm -v "$WORK:/work" --workdir /work --entrypoint leap-util "coopos-deb:${TAG}" "$@"
}

echo "→ to-json"
run_in_image snapshot to-json -i /work/snap.bin -o /work/snap.json

if [ -n "$PATCH" ]; then
  echo "→ применяю патч: $PATCH"
  if [ -f "$PATCH" ]; then
    jq -f "$PATCH" "$WORK/snap.json" > "$WORK/snap.patched.json"
  else
    jq "$PATCH" "$WORK/snap.json" > "$WORK/snap.patched.json"
  fi
  IN_JSON="snap.patched.json"
else
  echo "→ патч не задан, делаю round-trip"
  IN_JSON="snap.json"
fi

echo "→ from-json"
run_in_image snapshot from-json -i "/work/$IN_JSON" -o /work/snap.fork.bin

cp "$WORK/snap.fork.bin" "$OUT"
SIZE_MB=$(( $(stat -c%s "$OUT") / 1024 / 1024 ))
echo "✓ $OUT готов (${SIZE_MB} MB)"

if [ "$KEEP_JSON" -eq 1 ]; then
  cp "$WORK/snap.json" "${OUT%.bin}.json"
  [ -f "$WORK/snap.patched.json" ] && cp "$WORK/snap.patched.json" "${OUT%.bin}.patched.json"
  echo "  промежуточные JSON: ${OUT%.bin}.json $([ -f "$WORK/snap.patched.json" ] && echo "${OUT%.bin}.patched.json")"
fi
