#!/usr/bin/env python3
"""Дашборд истории switchover по Prometheus."""
import importlib.util
import json
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location(
    "build_grafana_dashboard",
    REPO / "scripts" / "build-grafana-dashboard.py",
)
_bgd = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_bgd)

DS = {"type": "prometheus", "uid": "prometheus"}
# Одна серия: max схлопывает stale site=WDC/site=CDC (без or — иначе duplicate labelset)
PRIMARY = 'max by (datacenter) (oracledb_radar_primary_code_code{datacenter="WDC"})'
CHANGES = f"changes({PRIMARY}[$__range:])"
EVENTS = f"{CHANGES} > 0"


def prom_target(expr: str, legend: str = "", instant: bool = False) -> dict:
    return {
        "datasource": DS,
        "expr": expr,
        "legendFormat": legend,
        "refId": "A",
        "instant": instant,
        "range": not instant,
    }


def value_mappings_primary() -> list:
    return [
        {
            "type": "value",
            "options": {
                "1": {"color": "green", "index": 0, "text": "WDC (Primary)"},
                "2": {"color": "blue", "index": 1, "text": "CDC (Primary)"},
            },
        }
    ]


def build_dashboard() -> dict:
    return {
        "title": "Data Guard Switchover History",
        "uid": "dataguard-switchover-history",
        "tags": ["dataguard", "radar", "switchover"],
        "timezone": "browser",
        "schemaVersion": 39,
        "refresh": "30s",
        "time": {"from": "now-7d", "to": "now"},
        "links": [
            {
                "title": "Topology (live)",
                "url": "/d/dataguard-overview/data-guard-overview",
                "type": "link",
                "icon": "dashboard",
            }
        ],
        "templating": {"list": []},
        "annotations": {
            "list": [
                {
                    "builtIn": 1,
                    "datasource": {"type": "grafana", "uid": "-- Grafana --"},
                    "enable": True,
                    "hide": True,
                    "iconColor": "rgba(0, 211, 255, 1)",
                    "name": "Annotations & Alerts",
                    "type": "dashboard",
                },
                {
                    "datasource": DS,
                    "enable": True,
                    "expr": EVENTS,
                    "iconColor": "orange",
                    "name": "Switchover",
                    "step": "5m",
                    "tagKeys": "",
                    "textFormat": "Primary role changed",
                    "titleFormat": "Switchover",
                },
            ]
        },
        "panels": [
            {
                "gridPos": {"h": 3, "w": 24, "x": 0, "y": 0},
                "id": 1,
                "options": {
                    "content": (
                        "## История switchover\n"
                        "Метрика `oracledb_radar_primary_code_code`: **1** = WDC Primary, **2** = CDC Primary. "
                        "Оранжевые метки на графиках — момент `changes()` (смена в `monitor.dg_sim`). "
                        "Диапазон по умолчанию: **7 дней** (настрой вверху)."
                    ),
                    "mode": "markdown",
                },
                "title": "",
                "type": "text",
            },
            {
                "gridPos": {"h": 4, "w": 8, "x": 0, "y": 3},
                "id": 2,
                "title": "Сейчас Primary",
                "type": "stat",
                "datasource": DS,
                "targets": [prom_target(PRIMARY, "Primary", instant=True)],
                "fieldConfig": {
                    "defaults": {
                        "mappings": value_mappings_primary(),
                        "thresholds": {
                            "mode": "absolute",
                            "steps": [{"color": "green", "value": None}],
                        },
                    }
                },
                "options": {
                    "colorMode": "background",
                    "graphMode": "none",
                    "textMode": "value",
                },
            },
            {
                "gridPos": {"h": 4, "w": 8, "x": 8, "y": 3},
                "id": 3,
                "title": "Switchover за период",
                "type": "stat",
                "datasource": DS,
                "targets": [
                    prom_target(f"sum({CHANGES}) or vector(0)", "Count", instant=True)
                ],
                "fieldConfig": {
                    "defaults": {
                        "decimals": 0,
                        "thresholds": {
                            "mode": "absolute",
                            "steps": [
                                {"color": "green", "value": None},
                                {"color": "yellow", "value": 1},
                                {"color": "red", "value": 5},
                            ],
                        },
                    }
                },
                "options": {"colorMode": "value", "graphMode": "none"},
            },
            {
                "gridPos": {"h": 4, "w": 8, "x": 16, "y": 3},
                "id": 4,
                "title": "Последний switchover",
                "type": "stat",
                "datasource": DS,
                "targets": [prom_target(PRIMARY, "Primary", instant=True)],
                "fieldConfig": {
                    "defaults": {
                        "mappings": value_mappings_primary(),
                        "noValue": "нет смен за период",
                    }
                },
                "options": {"colorMode": "background", "graphMode": "none", "textMode": "value"},
            },
            {
                "gridPos": {"h": 8, "w": 24, "x": 0, "y": 7},
                "id": 5,
                "title": "Кто был Primary (timeline)",
                "type": "state-timeline",
                "datasource": DS,
                "targets": [prom_target(PRIMARY, "Primary")],
                "fieldConfig": {
                    "defaults": {
                        "mappings": value_mappings_primary(),
                        "custom": {"fillOpacity": 80, "lineWidth": 0},
                    }
                },
                "options": {
                    "mergeValues": True,
                    "rowHeight": 0.9,
                    "showValue": "always",
                },
            },
            {
                "gridPos": {"h": 8, "w": 24, "x": 0, "y": 15},
                "id": 6,
                "title": "Код Primary (ступенчатый график)",
                "type": "timeseries",
                "datasource": DS,
                "targets": [prom_target(PRIMARY, "code")],
                "fieldConfig": {
                    "defaults": {
                        "mappings": value_mappings_primary(),
                        "custom": {
                            "drawStyle": "line",
                            "lineInterpolation": "stepAfter",
                            "lineWidth": 2,
                            "fillOpacity": 20,
                            "showPoints": "auto",
                        },
                        "min": 0,
                        "max": 3,
                    }
                },
            },
            {
                "gridPos": {"h": 8, "w": 24, "x": 0, "y": 23},
                "id": 7,
                "title": "Моменты switchover",
                "type": "timeseries",
                "datasource": DS,
                "targets": [prom_target(EVENTS, "event")],
                "fieldConfig": {
                    "defaults": {
                        "custom": {
                            "drawStyle": "points",
                            "pointSize": 12,
                            "showPoints": "always",
                        },
                        "color": {"fixedColor": "orange", "mode": "fixed"},
                        "max": 1.2,
                        "min": -0.2,
                    }
                },
                "options": {"legend": {"displayMode": "hidden"}},
            },
            {
                "gridPos": {"h": 10, "w": 24, "x": 0, "y": 31},
                "id": 8,
                "title": "Журнал смен (значение Primary по scrape)",
                "type": "table",
                "datasource": DS,
                "targets": [prom_target(PRIMARY, "Primary")],
                "transformations": [
                    {
                        "id": "organize",
                        "options": {
                            "excludeByName": {"Time": False, "Value": False},
                            "renameByName": {
                                "Time": "Время",
                                "Value": "Primary (код)",
                            },
                        },
                    },
                ],
                "fieldConfig": {
                    "defaults": {
                        "mappings": value_mappings_primary(),
                        "custom": {"align": "auto", "displayMode": "color-text"},
                    },
                    "overrides": [
                        {
                            "matcher": {"id": "byName", "options": "Время"},
                            "properties": [
                                {"id": "unit", "value": "dateTimeAsIso"},
                                {"id": "custom.width", "value": 220},
                            ],
                        }
                    ],
                },
            },
        ],
    }


def main():
    dash = build_dashboard()
    out = REPO / "grafana/dashboards-json/dataguard-switchover-history.json"
    out.write_text(json.dumps(dash, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {out}")

    _bgd.ensure_prometheus_datasource()
    status, body = _bgd.grafana_request(
        "POST", "/api/dashboards/db", {"dashboard": dash, "overwrite": True}
    )
    if status == 200:
        print(body)
    else:
        print(f"Grafana API: HTTP {status} {body[:400]}")

    prov = _bgd.PROV / "dashboards"
    prov.mkdir(parents=True, exist_ok=True)
    shutil.copy(out, prov / "dataguard-switchover-history.json")


if __name__ == "__main__":
    main()
