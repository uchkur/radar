#!/usr/bin/env bash
# Поднимает Oracle WDC/CDC + exporters + Alloy + Prometheus в одной Podman-сети.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
STACK_FILE="docker/podman-network.stack.yml"

echo "==> Radar stack (Podman network): ${STACK_FILE}"
${COMPOSE} -f "${STACK_FILE}" up -d

echo "==> Ожидание Prometheus..."
for i in $(seq 1 60); do
  if curl -sf http://localhost:9090/-/ready >/dev/null 2>&1; then
    echo "Prometheus ready"
    break
  fi
  sleep 2
done

echo ""
echo "Oracle WDC:  localhost:1521  (system/test, monitor/monitor)"
echo "Oracle CDC:  localhost:1522"
echo "Prometheus:  http://localhost:9090"
echo "Alloy UI:    http://localhost:12345"
echo "Exporters:   http://localhost:9161/metrics  http://localhost:9162/metrics"
echo ""
echo "Если Oracle только что поднялся — выполни инициализацию monitor.dg_sim (см. README)."
echo "Grafana: brew services start grafana && ./scripts/setup-grafana-prometheus.sh"
