#!/usr/bin/env bash
# Проверка Oracle Free без persistent volume. Если падает — проблема в Podman/RAM, не в volume.
set -euo pipefail

IMAGE="${ORACLE_IMAGE:-gvenzl/oracle-free:23-slim}"
TIMEOUT="${ORACLE_SMOKE_TIMEOUT:-900}"

echo "==> Smoke test: ${IMAGE} (без volume, --rm)"
echo "    Жди DATABASE IS READY TO USE (до $((TIMEOUT / 60)) мин на M2)"
echo ""

podman rm -f oracle-smoke 2>/dev/null || true

if ! podman run --rm --name oracle-smoke \
  -e ORACLE_PASSWORD=test \
  -p 1522:1521 \
  --shm-size=2g \
  --cpus=2 \
  "${IMAGE}" 2>&1 | tee /tmp/radar-oracle-smoke.log &
then
  echo "podman run failed to start"
  exit 1
fi

pid=$!
deadline=$((SECONDS + TIMEOUT))
ok=0
while [ "${SECONDS}" -lt "${deadline}" ]; do
  if grep -q "DATABASE IS READY TO USE" /tmp/radar-oracle-smoke.log 2>/dev/null; then
    ok=1
    break
  fi
  if ! kill -0 "${pid}" 2>/dev/null; then
    break
  fi
  sleep 5
done

kill "${pid}" 2>/dev/null || true
wait "${pid}" 2>/dev/null || true

echo ""
if [ "${ok}" -eq 1 ]; then
  echo "OK: Oracle стартует без volume → делай reset-oracle-volumes.sh и run-oracle-wdc-foreground.sh"
  exit 0
fi

echo "FAIL: Oracle не поднялся. Последние строки лога:"
tail -30 /tmp/radar-oracle-smoke.log 2>/dev/null || true
grep -iE 'ORA-|LRM-|ERROR|exit' /tmp/radar-oracle-smoke.log 2>/dev/null | tail -15 || true
exit 1
