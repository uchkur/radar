#!/usr/bin/env bash
# Один раз настраивает дашборд: iframe на live oracle-meta-server (без статического JSON).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PORT="${RADAR_META_PORT:-8765}"
export GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
export GRAFANA_USER="${GRAFANA_USER:-admin}"
export GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

python3 << PY
import base64, json, os, urllib.request
from pathlib import Path

port = os.environ.get("RADAR_META_PORT", "8765")
iframe = (
    f'<iframe src="http://127.0.0.1:{port}/topology" width="100%" height="280" '
    'frameborder="0" style="border:0;min-height:280px;background:transparent;"></iframe>'
    f'<p style="font-size:11px;color:#94a3b8;margin:8px 0 0;text-align:center;">'
    f'Live из Oracle каждые 5 с · сервер <code>oracle-meta-server</code> :{port}</p>'
)
repo = Path("${REPO_ROOT}")
dash_path = repo / "grafana/dashboards-json/dataguard-overview.json"
dash = json.loads(dash_path.read_text()) if dash_path.exists() else {
    "title": "Data Guard Overview", "uid": "dataguard-overview", "schemaVersion": 39, "version": 0
}
dash["refresh"] = "5s"
dash["panels"] = [{
    "gridPos": {"h": 16, "w": 24, "x": 0, "y": 0},
    "id": 1,
    "options": {"code": {"language": "html"}, "content": iframe, "mode": "html"},
    "title": "Data Guard topology (live)",
    "type": "text",
}]
dash["title"] = "Data Guard Overview"
dash["uid"] = "dataguard-overview"
dash_path.write_text(json.dumps(dash, indent=2) + "\n")

body = json.dumps({"dashboard": dash, "overwrite": True}).encode()
req = urllib.request.Request(
    os.environ["GRAFANA_URL"] + "/api/dashboards/db",
    data=body, method="POST",
    headers={
        "Content-Type": "application/json",
        "Authorization": "Basic " + base64.b64encode(
            f"{os.environ['GRAFANA_USER']}:{os.environ['GRAFANA_PASSWORD']}".encode()
        ).decode(),
    },
)
with urllib.request.urlopen(req, timeout=15) as r:
    print(r.read().decode())
PY
