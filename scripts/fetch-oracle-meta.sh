#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}" WDC_CONTAINER="${WDC_CONTAINER:-oracle-wdc}" CDC_CONTAINER="${CDC_CONTAINER:-oracle-cdc}" ORACLE_PASSWORD="${ORACLE_PASSWORD:-test}"
exec python3 "${REPO_ROOT}/scripts/fetch-oracle-meta.py"
