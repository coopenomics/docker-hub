#!/usr/bin/env bash
set -euo pipefail

# Качает свежий snapshot.bin с прод-эндпоинта.
# Атомарная замена: пишем в .tmp, на успех переименовываем.

cd "$(dirname "$0")/.."

URL="${SNAPSHOT_URL:-https://snapshot.coopenomics.world}"
DEST="snapshot.bin"
TMP="snapshot.bin.tmp"

echo "→ скачиваю снапшот: $URL"
curl -fL --retry 3 --retry-delay 5 --connect-timeout 30 -o "$TMP" "$URL"

if [ ! -s "$TMP" ]; then
  echo "✗ снапшот пустой, прерываю" >&2
  rm -f "$TMP"
  exit 1
fi

mv "$TMP" "$DEST"
SIZE_MB=$(( $(stat -c%s "$DEST") / 1024 / 1024 ))
echo "✓ $DEST готов (${SIZE_MB} MB)"
