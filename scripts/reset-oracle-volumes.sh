#!/usr/bin/env bash
# Сброс Oracle volumes после exit 54/187 или смены образа (slim ↔ faststart).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
STACK_FILE="docker/podman-network.stack.yml"

echo "==> Остановка стека и удаление volumes Oracle/Prometheus/Alloy..."
${COMPOSE} -f "${STACK_FILE}" down -v --remove-orphans 2>/dev/null || true

for c in oracle-wdc oracle-cdc radar-exporter-wdc radar-exporter-cdc radar-prometheus radar-alloy; do
  podman rm -f "${c}" 2>/dev/null || true
done

for v in radar_oracle-wdc-volume radar_oracle-cdc-volume oracle-wdc-volume oracle-cdc-volume; do
  podman volume rm "${v}" 2>/dev/null || true
done

echo "==> Готово. Запусти: ./scripts/start-stack.sh"
echo "    На M2: podman machine set --memory 16384 && podman machine start"
