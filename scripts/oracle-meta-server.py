#!/usr/bin/env python3
"""
HTTP-сервис: каждый запрос читает Oracle (monitor.dg_sim, v$version).
Grafana (iframe) опрашивает /topology → JS каждые N с запрашивает /render из БД.

Запуск: ./scripts/oracle-meta-server.sh
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "scripts"))
from oracle_meta import collect_meta  # noqa: E402
from topology_svg import build_topology_svg  # noqa: E402

HOST = os.environ.get("RADAR_META_HOST", "127.0.0.1")
PORT = int(os.environ.get("RADAR_META_PORT", "8765"))
POLL_MS = int(os.environ.get("RADAR_POLL_MS", "5000"))


def topology_page(meta: dict) -> str:
    svg = build_topology_svg(meta)
    return f"""<!DOCTYPE html>
<html lang="ru"><head><meta charset="utf-8">
<style>
body{{margin:0;padding:0;background:transparent;font-family:system-ui,sans-serif}}
#wrap{{max-width:560px;margin:0 auto}}
#status{{font-size:11px;color:#64748b;text-align:center;margin-top:4px}}
svg{{display:block;width:100%;height:auto}}
</style></head><body>
<div id="wrap">
  <div id="topology">{svg}</div>
  <div id="status">Primary: <b>{meta["primary_site"]}</b> → Standby: <b>{meta["standby_site"]}</b> · live</div>
</div>
<script>
const POLL = {POLL_MS};
async function refresh() {{
  const st = document.getElementById("status");
  const tp = document.getElementById("topology");
  try {{
    const meta = await (await fetch("/meta?t=" + Date.now())).json();
    tp.innerHTML = await (await fetch("/render?t=" + Date.now())).text();
    st.innerHTML = "Primary: <b>" + meta.primary_site + "</b> → Standby: <b>" + meta.standby_site
      + "</b> · " + meta.updated_at;
  }} catch (e) {{
    st.textContent = "Ошибка: " + e;
  }}
}}
setInterval(refresh, POLL);
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        if os.environ.get("RADAR_META_QUIET") != "1":
            super().log_message(fmt, *args)

    def _headers(self, content_type: str):
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")

    def do_GET(self):
        path = urlparse(self.path).path
        try:
            if path == "/meta":
                body = json.dumps(collect_meta(), ensure_ascii=False).encode()
                self.send_response(200)
                self._headers("application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(body)
                return

            if path == "/render":
                body = build_topology_svg(collect_meta()).encode()
                self.send_response(200)
                self._headers("text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(body)
                return

            if path in ("/topology", "/"):
                body = topology_page(collect_meta()).encode()
                self.send_response(200)
                self._headers("text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(body)
                return

            if path == "/health":
                self.send_response(200)
                self._headers("text/plain")
                self.end_headers()
                self.wfile.write(b"ok")
                return

            self.send_response(404)
            self.end_headers()
        except Exception as e:
            self.send_response(500)
            self._headers("application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.end_headers()


def main():
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"radar oracle-meta-server http://{HOST}:{PORT}/topology  (poll {POLL_MS}ms, live Oracle)")
    server.serve_forever()


if __name__ == "__main__":
    main()
