#!/usr/bin/env bash
# Поднимает Oracle WDC/CDC + exporters + Alloy + Prometheus в Podman-сети radar.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
STACK_FILE="docker/podman-network.stack.yml"
RADAR_CONTAINERS=(oracle-wdc oracle-cdc radar-exporter-wdc radar-exporter-cdc radar-prometheus radar-alloy)

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

# На случай «висящих» контейнеров с теми же именами без привязки compose
for c in "${RADAR_CONTAINERS[@]}"; do
  if podman container exists "${c}" 2>/dev/null; then
    stop_radar_stack
    break
  fi
done

echo "==> Radar stack (Podman): ${STACK_FILE}"
${COMPOSE} -f "${STACK_FILE}" up -d

echo "==> Ожидание Prometheus..."
for i in $(seq 1 60); do
  if curl -sf http://localhost:9090/-/ready >/dev/null 2>&1; then
    echo "Prometheus ready"
    break
  fi
  sleep 2
done

echo "==> Проверка метрик (через ~15s после старта экспортеров)..."
sleep 5
curl -sf "http://localhost:9090/api/v1/query?query=oracledb_radar_primary_site_info" \
  | python3 -m json.tool 2>/dev/null | head -20 \
  || echo "(метрики ещё не появились — подожди и проверь: podman logs radar-exporter-wdc)"

echo ""
echo "Oracle WDC:  localhost:1521  (system/test, monitor/monitor)"
echo "Oracle CDC:  localhost:1522"
echo "Prometheus:  http://localhost:9090"
echo "Alloy UI:    http://localhost:12345"
echo "Exporters:   http://localhost:9161/metrics  http://localhost:9162/metrics"
echo ""
echo "Grafana: brew services start grafana && ./scripts/setup-grafana-prometheus.sh"
echo "Остановка: podman compose -f ${STACK_FILE} down"
