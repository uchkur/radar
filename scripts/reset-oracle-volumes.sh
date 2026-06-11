#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"

echo "==> Остановка стека, порты и volumes..."
"${REPO_ROOT}/scripts/free-ports.sh" || true
${COMPOSE} -f docker/podman-network.stack.yml down -v --remove-orphans 2>/dev/null || true
${COMPOSE} -f docker/podman-network.stack.m2.yml down -v --remove-orphans 2>/dev/null || true

while read -r vol; do
  [ -n "${vol}" ] && podman volume rm "${vol}" 2>/dev/null || true
done < <(podman volume ls -q 2>/dev/null | grep -E 'oracle|radar' || true)

echo "==> Готово. Запусти: ./scripts/start-stack.sh"
if [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]; then
  echo "    M2: один Oracle 23 Free (arm64), оба exporter → oracle-wdc"
  echo "    Обязательно после exit 54/187 от старого XE 11 или двух инстансов Free"
fi
