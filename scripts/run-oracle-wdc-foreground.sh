#!/usr/bin/env bash
# Запуск только oracle-wdc в foreground — весь вывод Oracle в терминал (для отладки).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
STACK_FILE="docker/podman-network.stack.yml"

echo "==> Остановка oracle-wdc (если был)..."
podman rm -f oracle-wdc 2>/dev/null || true

echo "==> Старт oracle-wdc в foreground (Ctrl+C для остановки)"
echo "    Первый запуск на M2: 15–25 мин, жди DATABASE IS READY TO USE"
echo ""

exec ${COMPOSE} -f "${STACK_FILE}" up --no-deps oracle-wdc
