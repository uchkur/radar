#!/usr/bin/env bash
# Диагностика Radar/Podman — когда podman logs пустой или контейнер падает.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

COMPOSE="${COMPOSE:-podman compose}"
STACK_FILE="${STACK_FILE:-$("${REPO_ROOT}/scripts/stack-file.sh")}"

section() { echo ""; echo "=== $* ==="; }

section "Stack file"
echo "${STACK_FILE}"
if [ "$(basename "${STACK_FILE}")" = "podman-network.stack.m2.yml" ]; then
  echo "Apple Silicon → Oracle 23 Free arm64 (избегает ORA-00443 от XE 11 + Rosetta)"
else
  echo "Intel/Linux → Oracle XE 11 amd64"
fi

section "Podman machine"
podman machine list 2>&1 || echo "podman machine: недоступно"

section "Podman info"
podman info --format 'OS={{.Host.Os}} arch={{.Host.Arch}} cpus={{.Host.Cpus}} mem={{.Host.MemTotal}}' 2>&1 \
  || echo "podman info: ошибка (machine запущена?)"

section "Контейнеры oracle / radar"
podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>&1 \
  | grep -E 'NAMES|oracle|radar' || echo "(контейнеров нет)"

for name in oracle-wdc oracle-cdc; do
  section "${name}"
  if ! podman container exists "${name}" 2>/dev/null; then
    echo "НЕ СУЩЕСТВУЕТ — стек не поднят или контейнер удалён."
    echo "  Запуск: ./scripts/start-stack.sh"
    echo "  Отладка в foreground: ./scripts/run-oracle-wdc-foreground.sh"
    continue
  fi
  podman inspect -f \
    'Status={{.State.Status}} Running={{.State.Running}} ExitCode={{.State.ExitCode}} Started={{.State.StartedAt}} Finished={{.State.FinishedAt}}' \
    "${name}" 2>&1 || true
  echo "--- podman logs --tail 50 (stdout/stderr) ---"
  if out="$(podman logs --tail 50 "${name}" 2>&1)" && [ -n "${out}" ]; then
    echo "${out}"
  else
    echo "(пусто — контейнер ещё не писал в stdout или только что создан)"
  fi
  echo "--- podman compose logs --tail 50 ---"
  ${COMPOSE} -f "${STACK_FILE}" logs --tail 50 "${name}" 2>&1 \
    || echo "(compose logs пусто)"
done

section "Volumes Oracle"
podman volume ls 2>&1 | grep -E 'oracle|radar|VOLUME' || echo "(volumes нет)"

section "Образ Oracle"
podman images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' 2>&1 \
  | grep -E 'REPOSITORY|oracle-' || echo "(образ не скачан)"

section "Порты на хосте"
for port in 1521 1522 9090 9161; do
  if lsof -iTCP:"${port}" -sTCP:LISTEN -P -n >/dev/null 2>&1; then
    echo ":${port} занят — $(lsof -iTCP:"${port}" -sTCP:LISTEN -P -n 2>/dev/null | tail -1)"
  else
    echo ":${port} свободен"
  fi
done

echo ""
echo "Если oracle-wdc нет или exit 54/187:"
echo "  ./scripts/reset-oracle-volumes.sh"
echo "  podman machine set --memory 16384 && podman machine start"
echo "  ./scripts/run-oracle-wdc-foreground.sh   # вывод прямо в терминал"
