#!/usr/bin/env bash
# Поднимает Oracle WDC/CDC + exporters + Alloy + Prometheus в Podman-сети radar.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
STACK_FILE="${STACK_FILE:-$("${REPO_ROOT}/scripts/stack-file.sh")}"
ORACLE_WAIT_SEC="${ORACLE_WAIT_SEC:-1500}"

if [ "$(basename "${STACK_FILE}")" = "podman-network.stack.m2.yml" ]; then
  echo "==> Apple Silicon: Oracle 23 Free (arm64), PDB FREEPDB1"
else
  echo "==> Intel/Linux: Oracle XE 11 (amd64)"
fi

echo "==> Освобождение портов (контейнеры + rootlessport)..."
"${REPO_ROOT}/scripts/free-ports.sh"

echo "==> Radar stack: ${STACK_FILE}"
${COMPOSE} -f "${STACK_FILE}" up -d

wait_oracle_healthy() {
  local name="$1"
  echo "==> Ожидание ${name} (healthy). Логи: podman logs --tail 20 ${name}"
  local i=0
  while [ "${i}" -lt "${ORACLE_WAIT_SEC}" ]; do
    if ! podman container exists "${name}" 2>/dev/null; then
      echo "ОШИБКА: контейнер ${name} не существует"
      return 1
    fi
    local running health
    running="$(podman inspect -f '{{.State.Running}}' "${name}" 2>/dev/null || echo false)"
    health="$(podman inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${name}" 2>/dev/null || echo unknown)"
    if [ "${health}" = "healthy" ]; then
      echo "${name} healthy (${i}s)"
      return 0
    fi
    if [ "${running}" != "true" ]; then
      local exit_code
      exit_code="$(podman inspect -f '{{.State.ExitCode}}' "${name}" 2>/dev/null || echo "?")"
      echo "ОШИБКА: ${name} остановился (exit ${exit_code})."
      podman logs --tail 50 "${name}" 2>&1 || true
      if podman logs "${name}" 2>&1 | grep -qiE 'ORA-01078|LRM-00109'; then
        echo ""
        echo "  ORA-01078/LRM-00109 → битый volume. Выполни:"
        echo "    ./scripts/reset-oracle-volumes.sh"
        echo "    ./scripts/oracle-smoke-test.sh"
        echo "    ./scripts/run-oracle-wdc-foreground.sh"
      fi
      return 1
    fi
    if [ $((i % 60)) -eq 0 ] && [ "${i}" -gt 0 ]; then
      echo "  ... ${i}s, health=${health}"
    fi
    sleep 1
    i=$((i + 1))
  done
  echo "ТАЙМАУТ: ${name} не стал healthy за ${ORACLE_WAIT_SEC}s"
  podman logs --tail 50 "${name}" 2>&1 || true
  return 1
}

wait_oracle_healthy oracle-wdc
if podman container exists oracle-cdc 2>/dev/null; then
  wait_oracle_healthy oracle-cdc
else
  echo "==> M2: один Oracle (oracle-cdc контейнера нет — оба exporter → oracle-wdc)"
fi

echo "==> Ожидание Prometheus..."
for i in $(seq 1 60); do
  if curl -sf http://localhost:9090/-/ready >/dev/null 2>&1; then
    echo "Prometheus ready"
    break
  fi
  sleep 2
done

echo ""
echo "Oracle WDC:  localhost:1521"
echo "Oracle CDC:  localhost:1522"
echo "Prometheus:  http://localhost:9090"
echo "Exporters:   http://localhost:9161/metrics  http://localhost:9162/metrics"
echo "Grafana:     ./scripts/setup-grafana-prometheus.sh"
