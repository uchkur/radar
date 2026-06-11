#!/usr/bin/env bash
# Поднимает: oracledb_exporter (WDC/CDC) → Alloy → Prometheus
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

echo "==> Oracle exporters + Alloy + Prometheus"
docker compose -f docker/docker-compose.stack.yml up -d

echo "==> Ожидание Prometheus..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:9090/-/ready >/dev/null 2>&1; then
    echo "Prometheus ready"
    break
  fi
  sleep 1
done

echo "==> Проверка метрик (через ~15s после старта экспортеров)..."
sleep 5
curl -sf "http://localhost:9090/api/v1/query?query=oracledb_radar_primary_site_info" | python3 -m json.tool 2>/dev/null | head -20 || echo "(метрики ещё не появились — подожди и проверь: docker logs radar-exporter-wdc)"

echo ""
echo "Prometheus: http://localhost:9090"
echo "Alloy UI:   http://localhost:12345"
echo "Exporters:  http://localhost:9161/metrics  http://localhost:9162/metrics"
echo ""
echo "Grafana (brew): убедись что запущена — brew services start grafana"
echo "  provisioning: ${REPO_ROOT}/grafana/provisioning → /usr/local/etc/grafana/provisioning"
echo "  затем: ./scripts/setup-grafana-prometheus.sh"
