#!/usr/bin/env bash
# Поднимает Oracle WDC/CDC + exporters + Alloy + Prometheus в Podman-сети radar.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
STACK_FILE="docker/podman-network.stack.yml"
RADAR_CONTAINERS=(oracle-wdc oracle-cdc radar-exporter-wdc radar-exporter-cdc radar-prometheus radar-alloy)
ORACLE_WAIT_SEC="${ORACLE_WAIT_SEC:-1500}"   # 25 мин на M2 при первом старте

stop_radar_stack() {
  echo "==> Останавливаем предыдущий стек Radar (освобождаем порты 1521/1522/9090/9161/9162/12345)..."
  ${COMPOSE} -f "${STACK_FILE}" down --remove-orphans 2>/dev/null || true
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

echo "==> Radar stack (Podman): ${STACK_FILE}"
${COMPOSE} -f "${STACK_FILE}" up -d

wait_oracle_healthy() {
  local name="$1"
  echo "==> Ожидание ${name} (healthy). На M2 первый старт до 20 мин — смотри: podman logs -f ${name}"
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
      echo "ОШИБКА: ${name} остановился (exit ${exit_code}). Логи:"
      podman logs --tail 40 "${name}" 2>&1 || true
      if [ "${exit_code}" = "54" ] || [ "${exit_code}" = "187" ]; then
        echo ""
        echo "  exit 54/187 → битый volume или мало RAM. Выполни:"
        echo "    ./scripts/reset-oracle-volumes.sh"
        echo "    podman machine set --memory 16384 && podman machine start"
      fi
      return 1
    fi
    if [ $((i % 60)) -eq 0 ] && [ "${i}" -gt 0 ]; then
      echo "  ... ${i}s, health=${health}"
      podman logs --tail 1 "${name}" 2>/dev/null | sed 's/^/    /' || true
    fi
    sleep 1
    i=$((i + 1))
  done
  echo "ТАЙМАУТ: ${name} не стал healthy за ${ORACLE_WAIT_SEC}s"
  podman logs --tail 40 "${name}" 2>&1 || true
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

echo "==> Проверка метрик (после инициализации monitor.dg_sim)..."
sleep 5
curl -sf "http://localhost:9090/api/v1/query?query=oracledb_radar_primary_site_info" \
  | python3 -m json.tool 2>/dev/null | head -20 \
  || echo "(метрики появятся после CREATE USER monitor + dg_sim — см. README)"

echo ""
echo "Oracle WDC:  localhost:1521  (system/test)"
echo "Oracle CDC:  localhost:1522"
echo "Prometheus:  http://localhost:9090"
echo "Alloy UI:    http://localhost:12345"
echo "Exporters:   http://localhost:9161/metrics  http://localhost:9162/metrics"
echo ""
echo "Grafana: brew services start grafana && ./scripts/setup-grafana-prometheus.sh"
echo "Остановка: podman compose -f ${STACK_FILE} down"
