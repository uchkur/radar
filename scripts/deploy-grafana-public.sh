#!/usr/bin/env bash
# Копирует grafana/public/radar → каталог public Grafana (Homebrew).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${REPO_ROOT}/grafana/public/radar"
PREFIX="$(brew --prefix grafana 2>/dev/null || true)"
if [[ -z "$PREFIX" ]]; then
  echo "Grafana не найден через brew. Скопируй вручную: ${SRC} → <grafana>/public/radar/"
  exit 1
fi
DEST="${PREFIX}/share/grafana/public/radar"
mkdir -p "$DEST"
for f in "${SRC}/"*; do
  [[ -f "$f" ]] && cp -f "$f" "$DEST/"
done
echo "Deployed to ${DEST}"
ls -la "$DEST"
