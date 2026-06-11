#!/usr/bin/env python3
"""Собирает dataguard-overview.json с переменными Prometheus."""
import base64
import json
import os
import shutil
import urllib.error
import urllib.request
from pathlib import Path
from typing import Optional

REPO = Path(__file__).resolve().parents[1]
PROV = Path(os.environ.get("GRAFANA_ETC", "/usr/local/etc/grafana")) / "provisioning"

PANEL = """<style>
@keyframes radar-flow { to { stroke-dashoffset: 0; } }
.radar-rep-flow { stroke-dashoffset: 24; animation: radar-flow 1.2s linear infinite; }
</style>
<div style="text-align:center;">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 520 220" style="max-width:100%;height:auto;">
  <defs>
    <linearGradient id="primaryCylTop" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" style="stop-color:#a7f3d0"/><stop offset="100%" style="stop-color:#6ee7b7"/></linearGradient>
    <linearGradient id="primaryCylBody" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" style="stop-color:#5eead4"/><stop offset="50%" style="stop-color:#99f6e4"/><stop offset="100%" style="stop-color:#5eead4"/></linearGradient>
    <linearGradient id="standbyCylTop" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" style="stop-color:#7dd3fc"/><stop offset="100%" style="stop-color:#38bdf8"/></linearGradient>
    <linearGradient id="standbyCylBody" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" style="stop-color:#38bdf8"/><stop offset="50%" style="stop-color:#bae6fd"/><stop offset="100%" style="stop-color:#38bdf8"/></linearGradient>
    <marker id="arrowhead" markerWidth="12" markerHeight="8" refX="10" refY="4" orient="auto"><polygon points="0 0, 12 4, 0 8" fill="#0ea5e9"/></marker>
    <filter id="shadow" x="-20%" y="-10%" width="140%" height="120%"><feDropShadow dx="0" dy="3" stdDeviation="4" flood-opacity="0.12"/></filter>
    <linearGradient id="arrowGrad" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" style="stop-color:#059669"/><stop offset="100%" style="stop-color:#0ea5e9"/></linearGradient>
  </defs>
  <a xlink:href="/d/primary-overview/primary-overview"><g>
    <rect x="15" y="30" width="155" height="165" fill="transparent"/>
    <g filter="url(#shadow)" transform="translate(50, 35)">
      <path d="M 35 25 L 35 95 A 35 12 0 0 0 105 95 L 105 25 Z" fill="url(#primaryCylBody)" stroke="#059669" stroke-width="2"/>
      <ellipse cx="70" cy="25" rx="35" ry="12" fill="url(#primaryCylTop)" stroke="#059669" stroke-width="2"/>
      <ellipse cx="70" cy="48" rx="32" ry="4" fill="none" stroke="#047857" stroke-width="1.2" opacity="0.7"/>
      <ellipse cx="70" cy="72" rx="32" ry="4" fill="none" stroke="#047857" stroke-width="1.2" opacity="0.7"/>
      <ellipse cx="70" cy="96" rx="32" ry="4" fill="none" stroke="#047857" stroke-width="1.2" opacity="0.5"/>
    </g>
    <text x="110" y="155" text-anchor="middle" font-size="11" font-weight="600" fill="#065f46">PRIMARY</text>
    <text id="radar-primary-site" x="110" y="172" text-anchor="middle" font-size="14" font-weight="700" fill="#047857">…</text>
    <text id="radar-version-primary" x="110" y="190" text-anchor="middle" font-size="9" fill="#6b7280">Oracle …</text>
  </g></a>
  <a xlink:href="/d/replication-overview/replication-overview"><g>
    <rect x="170" y="92" width="180" height="36" fill="transparent"/>
    <path d="M 175 110 L 345 110" stroke="#cbd5e1" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M 175 110 L 345 110" stroke="url(#arrowGrad)" stroke-width="3" fill="none" stroke-linecap="round" marker-end="url(#arrowhead)"/>
    <path class="radar-rep-flow" d="M 175 110 L 332 110" stroke="#0ea5e9" stroke-width="2" fill="none" stroke-dasharray="8 16" stroke-linecap="round"><animate attributeName="stroke-dashoffset" from="24" to="0" dur="1.2s" repeatCount="indefinite"/></path>
    <circle r="5" fill="#059669"><animateMotion dur="2s" repeatCount="indefinite" path="M 175 110 L 332 110"/></circle>
    <circle r="4" fill="#0ea5e9"><animateMotion dur="2s" repeatCount="indefinite" path="M 175 110 L 332 110" begin="0.5s"/></circle>
    <circle r="4" fill="#0ea5e9"><animateMotion dur="2s" repeatCount="indefinite" path="M 175 110 L 332 110" begin="1s"/></circle>
    <text x="260" y="98" text-anchor="middle" font-size="10" fill="#64748b">Data Guard (replication)</text>
  </g></a>
  <a xlink:href="/d/standby-overview/standby-overview"><g>
    <rect x="318" y="30" width="195" height="165" fill="transparent"/>
    <g filter="url(#shadow)" transform="translate(360, 35)">
      <path d="M 35 25 L 35 95 A 35 12 0 0 0 105 95 L 105 25 Z" fill="url(#standbyCylBody)" stroke="#0284c7" stroke-width="2"/>
      <ellipse cx="70" cy="25" rx="35" ry="12" fill="url(#standbyCylTop)" stroke="#0284c7" stroke-width="2"/>
      <ellipse cx="70" cy="48" rx="32" ry="4" fill="none" stroke="#0369a1" stroke-width="1.2" opacity="0.7"/>
      <ellipse cx="70" cy="72" rx="32" ry="4" fill="none" stroke="#0369a1" stroke-width="1.2" opacity="0.7"/>
      <ellipse cx="70" cy="96" rx="32" ry="4" fill="none" stroke="#0369a1" stroke-width="1.2" opacity="0.5"/>
    </g>
    <text x="410" y="155" text-anchor="middle" font-size="11" font-weight="600" fill="#075985">STANDBY</text>
    <text id="radar-standby-site" x="410" y="172" text-anchor="middle" font-size="14" font-weight="700" fill="#0369a1">…</text>
    <text id="radar-version-standby" x="410" y="190" text-anchor="middle" font-size="9" fill="#6b7280">Oracle …</text>
  </g></a>
</svg>
<p id="radar-topology-status" style="font-size:11px;color:#94a3b8;">Prometheus · Alloy · refresh 5s</p>
</div>
<script>
(function() {
  var prom = '/api/datasources/proxy/uid/prometheus/api/v1/query?query=';
  function setText(id, t) { var el = document.getElementById(id); if (el) el.textContent = t; }
  function query(q, cb) {
    fetch(prom + encodeURIComponent(q), { credentials: 'same-origin' })
      .then(function(r) { return r.json(); })
      .then(function(d) { cb((d.data && d.data.result) || []); })
      .catch(function() { cb([]); });
  }
  function latestPrimary(results) {
    if (!results.length) return null;
    var best = results[0];
    for (var i = 1; i < results.length; i++) {
      if (parseFloat(results[i].value[0]) > parseFloat(best.value[0])) best = results[i];
    }
    if (best.metric && best.metric.site) return best.metric.site;
    return best.value[1] === '2' ? 'CDC' : 'WDC';
  }
  function refresh() {
    query('oracledb_radar_primary_code_code{datacenter="WDC"}', function(res) {
      var site = latestPrimary(res);
      if (!site) return;
      var stby = site === 'WDC' ? 'CDC' : 'WDC';
      setText('radar-primary-site', site);
      setText('radar-standby-site', stby);
      query('oracledb_radar_version_info{datacenter="' + site + '"}', function(vr) {
        var ver = vr[0] && vr[0].metric.version ? vr[0].metric.version : '';
        setText('radar-version-primary', ver ? 'Oracle ' + ver : 'Oracle');
      });
      query('oracledb_radar_version_info{datacenter="' + stby + '"}', function(vr) {
        var ver = vr[0] && vr[0].metric.version ? vr[0].metric.version : '';
        setText('radar-version-standby', ver ? 'Oracle ' + ver : 'Oracle');
      });
      setText('radar-topology-status', 'Primary ' + site + ' → Standby ' + stby + ' · live');
    });
  }
  refresh();
  setInterval(refresh, 5000);
})();
</script>"""


def build_dashboard():
    return {
        "title": "Data Guard Overview",
        "uid": "dataguard-overview",
        "tags": ["dataguard", "radar"],
        "timezone": "browser",
        "schemaVersion": 39,
        "refresh": "5s",
        "links": [
            {
                "title": "Switchover history",
                "url": "/d/dataguard-switchover-history/data-guard-switchover-history",
                "type": "link",
                "icon": "history",
            }
        ],
        "templating": {"list": []},
        "panels": [
            {
                "gridPos": {"h": 16, "w": 24, "x": 0, "y": 0},
                "id": 1,
                "options": {"content": PANEL, "mode": "html", "sanitize": False},
                "title": "Data Guard topology",
                "type": "text",
            }
        ],
    }


def grafana_request(method: str, path: str, body: Optional[dict] = None) -> tuple[int, str]:
    url = os.environ.get("GRAFANA_URL", "http://localhost:3000")
    auth = base64.b64encode(
        f"{os.environ.get('GRAFANA_USER', 'admin')}:{os.environ.get('GRAFANA_PASSWORD', 'admin')}".encode()
    ).decode()
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{url}{path}",
        data=data,
        method=method,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Basic {auth}",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def ensure_prometheus_datasource() -> None:
    """Создаёт Prometheus с uid=prometheus, если provisioning ещё не подхватился."""
    status, body = grafana_request("GET", "/api/datasources")
    if status != 200:
        print(f"Grafana datasources list: HTTP {status} {body[:200]}")
        return
    for ds in json.loads(body):
        if ds.get("uid") == "prometheus" or ds.get("name") == "Prometheus":
            print(f"Prometheus datasource ok (uid={ds.get('uid')})")
            return

    payload = {
        "name": "Prometheus",
        "type": "prometheus",
        "access": "proxy",
        "url": os.environ.get("PROMETHEUS_URL", "http://localhost:9090"),
        "isDefault": True,
        "uid": "prometheus",
    }
    status, body = grafana_request("POST", "/api/datasources", payload)
    if status in (200, 201):
        print("Created Prometheus datasource (uid=prometheus)")
    else:
        print(f"Create datasource: HTTP {status} {body[:300]}")


def main():
    dash = build_dashboard()
    out = REPO / "grafana/dashboards-json/dataguard-overview.json"
    out.write_text(json.dumps(dash, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {out}")

    PROV.mkdir(parents=True, exist_ok=True)
    (PROV / "datasources").mkdir(exist_ok=True)
    (PROV / "dashboards").mkdir(exist_ok=True)
    shutil.copy(REPO / "grafana/provisioning/datasources/prometheus.yml", PROV / "datasources/radar-prometheus.yml")
    shutil.copy(out, PROV / "dashboards/dataguard-overview.json")
    (PROV / "dashboards/radar.yml").write_text(
        f"""apiVersion: 1
providers:
  - name: radar
    orgId: 1
    folder: Radar
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: {PROV / "dashboards"}
"""
    )

    ensure_prometheus_datasource()
    status, body = grafana_request("POST", "/api/dashboards/db", {"dashboard": dash, "overwrite": True})
    if status == 200:
        print(body)
    else:
        print(f"Grafana dashboard API: HTTP {status} {body[:300]}")


if __name__ == "__main__":
    main()
