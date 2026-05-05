#!/usr/bin/env bash
set -euo pipefail

# Печатает head_block_num / head_block_time / chain_id / connections.
# Использует HTTP API на :8888 (порт берётся из .env, если есть).

cd "$(dirname "$0")/.."

PORT="${NODE_HTTP_PORT:-8888}"
if [ -f .env ]; then
  PORT="$(awk -F= '/^NODE_HTTP_PORT=/{print $2}' .env || true)"
  PORT="${PORT:-8888}"
fi

URL="http://127.0.0.1:${PORT}/v1/chain/get_info"

if ! INFO=$(curl -fsS --max-time 5 "$URL" 2>&1); then
  echo "✗ нода недоступна на ${URL}"
  echo "  ($INFO)"
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  echo "$INFO" | jq '{head_block_num, head_block_time, last_irreversible_block_num, chain_id, server_version_string}'
else
  echo "$INFO"
fi
