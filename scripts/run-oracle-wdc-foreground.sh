#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
STACK_FILE="${STACK_FILE:-$("${REPO_ROOT}/scripts/stack-file.sh")}"

echo "==> Foreground: ${STACK_FILE}"
podman rm -f oracle-wdc 2>/dev/null || true
exec ${COMPOSE} -f "${STACK_FILE}" up --no-deps oracle-wdc
