#!/usr/bin/env bash
set -euo pipefail

# Скачивает .deb-пакеты coopos из GitHub Releases (coopenomics/coopos).
# Требует gh CLI с аутентификацией.

cd "$(dirname "$0")/.."

REPO="${COOPOS_REPO:-coopenomics/coopos}"
DEST="debs"
mkdir -p "$DEST"

declare -A WANT=(
  [v5.1.0]="coopos_5.1.0-dev-ubuntu22.04_amd64.deb"
  [v5.2.0]="coopos_5.2.0-dev-ubuntu22.04_amd64.deb"
)

for tag in "${!WANT[@]}"; do
  asset="${WANT[$tag]}"
  if [ -s "$DEST/$asset" ]; then
    echo "✓ $asset уже есть"
    continue
  fi
  echo "→ скачиваю $asset из релиза $tag"
  gh release download "$tag" --repo "$REPO" --pattern "$asset" --dir "$DEST" --clobber
done

echo
ls -la "$DEST"/*.deb
