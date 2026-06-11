#!/usr/bin/env bash
# Полный сброс Oracle volumes. ORA-01078/LRM-00109 = прерванная инициализация на битом volume.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"

echo "==> Остановка стека и портов..."
"${REPO_ROOT}/scripts/free-ports.sh" || true

echo "==> compose down -v..."
${COMPOSE} -f docker/podman-network.stack.yml down -v --remove-orphans 2>/dev/null || true
${COMPOSE} -f docker/podman-network.stack.m2.yml down -v --remove-orphans 2>/dev/null || true

podman rm -f oracle-wdc oracle-cdc 2>/dev/null || true

echo "==> Удаление всех oracle/radar volumes..."
while read -r vol; do
  [ -n "${vol}" ] && podman volume rm -f "${vol}" 2>/dev/null && echo "  removed ${vol}" || true
done < <(podman volume ls -q 2>/dev/null | grep -iE 'oracle|radar' || true)

# явные имена (разные compose project name)
for v in oracle-wdc-volume oracle-cdc-volume radar_oracle-wdc-volume radar_oracle-cdc-volume \
         docker_oracle-wdc-volume docker_oracle-cdc-volume; do
  podman volume rm -f "${v}" 2>/dev/null && echo "  removed ${v}" || true
done

echo ""
echo "==> Оставшиеся volumes:"
podman volume ls 2>/dev/null | grep -iE 'oracle|radar' || echo "  (нет)"
echo ""
echo "Готово. Дальше:"
echo "  ./scripts/oracle-smoke-test.sh     # проверка образа без volume"
echo "  ./scripts/run-oracle-wdc-foreground.sh"
echo "  ./scripts/start-stack.sh"
