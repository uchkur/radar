# Radar

**Версия 1.0.0** — см. [CHANGELOG.md](CHANGELOG.md), тег `v1.0.0`.

Мониторинг Oracle Data Guard: **Oracle 11 XE (WDC/CDC)** → **oracledb_exporter** → **Grafana Alloy** → **Prometheus** → **Grafana**.

Доступ к Oracle — только SQL. Локально симулируются два датацентра и switchover через `monitor.dg_sim`.

## Архитектура (текущий стек)

```
┌─────────────┐     ┌──────────────────────┐     ┌─────────┐     ┌──────────┐
│ Oracle WDC  │────►│ oracledb_exporter    │     │         │     │          │
│  :1521      │     │  (Docker :9161)      │────►│  Alloy  │────►│Prometheus│──► Grafana
└─────────────┘     └──────────────────────┘     │ :12345  │     │  :9090   │    (дашборд
┌─────────────┐     ┌──────────────────────┐     │         │     │          │     Data Guard
│ Oracle CDC  │────►│ oracledb_exporter    │────►│remote_  │     └──────────┘     Overview)
│  :1522      │     │  (Docker :9162)      │     │ write   │
└─────────────┘     └──────────────────────┘     └─────────┘
```

- **oracledb_exporter** (образ `ghcr.io/iamseth/oracledb_exporter:0.6.0`) — SQL → метрики Prometheus, custom metrics в `oracle/custom-metrics.toml`.
- **Alloy** — scrape экспортеров + `remote_write` в Prometheus (отдельный процесс oracledb_exporter не нужен на хосте).
- **Grafana** — Overview (топология, live из Prometheus каждые 5s) + Switchover History.

> **oracle-meta-server** (Python) — устаревший dev-обход; для работы используй стек ниже.

## Быстрый старт

### 1. Oracle (WDC + CDC)

```bash
docker compose -f docker/oracle-local.yml up -d   # если ещё не подняты
# WDC: monitor.dg_sim на compassionate_jepsen / oracle-wdc :1521
# CDC: выполни oracle/sql/02_monitor_cdc.sql при необходимости
```

### 2. Мониторинг (Docker)

```bash
./scripts/start-stack.sh
```

Поднимает: `radar-exporter-wdc`, `radar-exporter-cdc`, `radar-alloy`, `radar-prometheus`.

- Prometheus: http://localhost:9090  
- Alloy UI: http://localhost:12345  
- Метрики экспортеров: http://localhost:9161/metrics , http://localhost:9162/metrics  

### 3. Grafana

```bash
brew services start grafana
./scripts/setup-grafana-prometheus.sh
brew services restart grafana   # подхватить provisioning
```

Дашборд: http://localhost:3000/d/dataguard-overview/data-guard-overview

### 4. История switchover

```bash
./scripts/build-switchover-dashboard.py   # или ./scripts/setup-grafana-prometheus.sh
```

Дашборд **Data Guard Switchover History** — timeline кто был Primary, оранжевые метки в момент `changes()`, счётчик смен за выбранный период (по умолчанию 7 дней).

### 5. Switchover (автообновление ~5 с)

```bash
# Только WDC (compassionate_jepsen / :1521) — там monitor.dg_sim
docker exec -i compassionate_jepsen sqlplus -s monitor/monitor@localhost/XE <<'SQL'
UPDATE dg_sim SET primary_site = 'CDC';
COMMIT;
SQL
```

Меняй `primary_site` на `WDC` / `CDC` — дашборд обновится после следующего scrape (~5–15 с). CDC (:1522) **не** хранит dg_sim для топологии.

## Метрики (custom)

| Метрика | Назначение |
|---------|------------|
| `oracledb_radar_primary_site_info{site, datacenter}` | Кто Primary (из `dg_sim`) |
| `oracledb_radar_primary_code_code` | 1=WDC Primary, 2=CDC (для истории / `changes()`) |
| `oracledb_radar_standby_site_info{site}` | Standby ДЦ |
| `oracledb_radar_version_info{version, datacenter}` | Версия Oracle из `v$version` |
| `oracledb_radar_db_role_info{role}` | `V$DATABASE.DATABASE_ROLE` |

## Структура репозитория

```
radar/
├── alloy/config.alloy              # Alloy: scrape → Prometheus
├── alloy/config.alloy.native       # вариант с встроенным exporter (нужен Oracle Instant Client)
├── docker/docker-compose.stack.yml
├── docker/oracle-local.yml
├── oracle/custom-metrics.toml
├── oracle/sql/
├── prometheus/prometheus.yml
├── grafana/provisioning/datasources/
├── grafana/dashboards-json/dataguard-overview.json
└── scripts/
    ├── start-stack.sh
    ├── setup-grafana-prometheus.sh
    └── build-grafana-dashboard.py
```

## Нативный Alloy (опционально)

Если установлен Oracle Instant Client на macOS:

```bash
brew install alloy prometheus
alloy run alloy/config.alloy.native
```

Иначе используй Docker-стек из `docker-compose.stack.yml`.
