#!/usr/bin/env bash
# Освобождает порты Radar (9161, 9162, …). Сеть compose не помогает — порт держит
# старый контейнер или зависший rootlessport/gvproxy в Podman machine.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
PORTS=(9161 9162 9090 12345 1521 1522)
RESTART_MACHINE="${RESTART_MACHINE:-auto}"   # auto | yes | no

port_busy() {
  lsof -iTCP:"$1" -sTCP:LISTEN -P -n >/dev/null 2>&1
}

show_port_holders() {
  local port="$1"
  if port_busy "${port}"; then
    echo "  :${port}"
    lsof -iTCP:"${port}" -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2 | sed 's/^/    /' || true
    return 0
  fi
  return 1
}

any_port_busy() {
  local p
  for p in "${PORTS[@]}"; do
    port_busy "${p}" && return 0
  done
  return 1
}

echo "==> Остановка compose-стеков..."
${COMPOSE} -f docker/podman-network.stack.yml down --remove-orphans 2>/dev/null || true
${COMPOSE} -f docker/podman-network.stack.m2.yml down --remove-orphans 2>/dev/null || true

echo "==> Удаление контейнеров radar / oracle / exporter..."
while read -r id; do
  [ -n "${id}" ] && podman rm -f "${id}" 2>/dev/null || true
done < <(podman ps -aq 2>/dev/null || true)

# явные имена на случай частичного удаления
for c in oracle-wdc oracle-cdc radar-exporter-wdc radar-exporter-cdc radar-prometheus radar-alloy; do
  podman rm -f "${c}" 2>/dev/null || true
done

sleep 1

if any_port_busy; then
  echo "==> Порты всё ещё заняты на macOS-хосте:"
  for p in "${PORTS[@]}"; do show_port_holders "${p}" || true; done

  if podman machine list 2>/dev/null | grep -q running; then
    echo "==> Очистка внутри Podman machine (rootlessport)..."
    podman machine ssh -- bash -lc '
      for p in 9161 9162 9090 12345 1521 1522; do
        if command -v fuser >/dev/null 2>&1; then fuser -k ${p}/tcp 2>/dev/null || true; fi
      done
      pkill -f "[r]ootlessport" 2>/dev/null || true
    ' 2>/dev/null || true
    sleep 1
  fi
fi

if any_port_busy; then
  if [ "${RESTART_MACHINE}" = "yes" ] || [ "${RESTART_MACHINE}" = "auto" ]; then
    echo "==> Перезапуск Podman machine (сброс gvproxy/rootlessport)..."
    podman machine stop 2>/dev/null || true
    sleep 2
    podman machine start
    sleep 3
  fi
fi

if any_port_busy; then
  echo ""
  echo "ОШИБКА: порты всё ещё заняты:"
  for p in "${PORTS[@]}"; do show_port_holders "${p}" || true; done
  echo ""
  echo "Вручную: RESTART_MACHINE=yes ./scripts/free-ports.sh"
  echo "Или найди процесс: lsof -iTCP:9161 -sTCP:LISTEN -P -n"
  exit 1
fi

echo "==> Порты Radar свободны: ${PORTS[*]}"
