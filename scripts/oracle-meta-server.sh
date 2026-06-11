#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export RADAR_META_HOST="${RADAR_META_HOST:-127.0.0.1}"
export RADAR_META_PORT="${RADAR_META_PORT:-8765}"
export RADAR_POLL_MS="${RADAR_POLL_MS:-5000}"
exec python3 "${SCRIPT_DIR}/oracle-meta-server.py"
