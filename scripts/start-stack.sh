#!/usr/bin/env bash
# Поднимает Oracle WDC/CDC + exporters + Alloy + Prometheus в Podman-сети radar.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
STACK_FILE="${STACK_FILE:-$("${REPO_ROOT}/scripts/stack-file.sh")}"
RADAR_CONTAINERS=(oracle-wdc oracle-cdc radar-exporter-wdc radar-exporter-cdc radar-prometheus radar-alloy)
ORACLE_WAIT_SEC="${ORACLE_WAIT_SEC:-1500}"

if [ "$(basename "${STACK_FILE}")" = "podman-network.stack.m2.yml" ]; then
  echo "==> Apple Silicon: Oracle 23 Free (arm64), PDB FREEPDB1"
  echo "    (Oracle XE 11 + Rosetta → ORA-00443 на M2)"
else
  echo "==> Intel/Linux: Oracle XE 11 (amd64)"
fi

stop_radar_stack() {
  echo "==> Останавливаем предыдущий стек Radar..."
  ${COMPOSE} -f docker/podman-network.stack.yml down --remove-orphans 2>/dev/null || true
  ${COMPOSE} -f docker/podman-network.stack.m2.yml down --remove-orphans 2>/dev/null || true
  for c in "${RADAR_CONTAINERS[@]}"; do
    podman rm -f "${c}" 2>/dev/null || true
  done
}

port_busy() {
  lsof -iTCP:"$1" -sTCP:LISTEN -P -n >/dev/null 2>&1
}

for port in 9161 9162 9090 12345 1521 1522; do
  if port_busy "${port}"; then
    stop_radar_stack
    break
  fi
done

for c in "${RADAR_CONTAINERS[@]}"; do
  if podman container exists "${c}" 2>/dev/null; then
    stop_radar_stack
    break
  fi
done

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
      if [ "${exit_code}" = "54" ] || [ "${exit_code}" = "187" ]; then
        echo ""
        echo "  ORA-00443 / exit 187 на M2 → сброс и M2-стек:"
        echo "    ./scripts/reset-oracle-volumes.sh"
        echo "    ./scripts/start-stack.sh"
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
wait_oracle_healthy oracle-cdc

echo "==> Ожидание Prometheus..."
for i in $(seq 1 60); do
  if curl -sf http://localhost:9090/-/ready >/dev/null 2>&1; then
    echo "Prometheus ready"
    break
  fi
  sleep 2
done

echo ""
if [ "$(basename "${STACK_FILE}")" = "podman-network.stack.m2.yml" ]; then
  echo "Инициализация (M2, PDB FREEPDB1):"
  echo "  podman exec -i oracle-wdc sqlplus -s system/test@//localhost:1521/FREEPDB1"
else
  echo "Инициализация (XE):"
  echo "  podman exec -i oracle-wdc sqlplus -s system/test@localhost/XE"
fi
echo ""
echo "Oracle WDC:  localhost:1521"
echo "Oracle CDC:  localhost:1522"
echo "Prometheus:  http://localhost:9090"
echo "Grafana:     ./scripts/setup-grafana-prometheus.sh"
