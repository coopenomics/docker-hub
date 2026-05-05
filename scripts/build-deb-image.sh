#!/usr/bin/env bash
set -euo pipefail

# Собирает coopos-deb:<VERSION> из заранее скачанного .deb-пакета.
# Использование: build-deb-image.sh <version>     # 5.1.0 или 5.2.0
#                build-deb-image.sh --all         # обе версии

cd "$(dirname "$0")/.."

build_one() {
  local v="$1"
  local deb="debs/coopos_${v}-dev-ubuntu22.04_amd64.deb"
  if [ ! -s "$deb" ]; then
    echo "✗ $deb отсутствует. Сначала ./scripts/fetch-debs.sh" >&2
    return 1
  fi
  echo "→ docker build coopos-deb:${v} (${deb})"
  docker build -f Dockerfile.deb-runner --build-arg "DEB=${deb}" -t "coopos-deb:${v}" .
}

case "${1:-}" in
  --all|"")
    build_one 5.1.0
    build_one 5.2.0
    ;;
  *)
    build_one "$1"
    ;;
esac

echo
docker images coopos-deb --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'
