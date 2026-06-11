#!/usr/bin/env bash
# Provisioning Prometheus datasource + дашборд Data Guard Overview
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRAFANA_ETC="${GRAFANA_ETC:-/usr/local/etc/grafana}"

echo "==> Provisioning → ${GRAFANA_ETC}/provisioning"
GRAFANA_ETC="${GRAFANA_ETC}" python3 "${REPO_ROOT}/scripts/build-grafana-dashboard.py"
python3 "${REPO_ROOT}/scripts/build-switchover-dashboard.py"

echo ""
echo "Дашборды:"
echo "  http://localhost:3000/d/dataguard-overview/data-guard-overview"
echo "  http://localhost:3000/d/dataguard-switchover-history/data-guard-switchover-history"
