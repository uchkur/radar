# Radar

**Версия 1.0.0** — см. [CHANGELOG.md](CHANGELOG.md), тег `v1.0.0`.

Мониторинг Oracle Data Guard: **Oracle 11 XE (WDC/CDC)** → **oracledb_exporter** → **Grafana Alloy** → **Prometheus** → **Grafana**.

Доступ к Oracle — только SQL. Локально симулируются два датацентра и switchover через `monitor.dg_sim`.

## Архитектура

```
┌─────────────┐     ┌──────────────────────┐     ┌─────────┐     ┌──────────┐
│ Oracle WDC  │────►│ oracledb_exporter    │     │         │     │          │
│ oracle-wdc  │     │  radar-exporter-wdc  │────►│  Alloy  │────►│Prometheus│──► Grafana (brew)
│  :1521      │     │  :9161               │     │ :12345  │     │  :9090   │
└─────────────┘     └──────────────────────┘     │         │     └──────────┘
┌─────────────┐     ┌──────────────────────┐     │ radar   │
│ Oracle CDC  │────►│ oracledb_exporter    │────►│ network │
│ oracle-cdc  │     │  radar-exporter-cdc  │     └─────────┘
│  :1522      │     │  :9162               │
└─────────────┘     └──────────────────────┘
```

Все сервисы в одной Podman-сети `radar`. Контейнеры общаются по DNS-именам (`oracle-wdc:1521`, `exporter-wdc:9161`).

## Требования

| Компонент | Установка |
|-----------|-----------|
| Podman | `brew install podman` |
| Compose | `podman compose version` (встроен в Podman 4+) |
| Grafana | `brew install grafana` |
| Python 3 | для provisioning дашбордов |

### Apple Silicon (M1 / M2 / M3)

На M2 **не используй Oracle XE 11** — под Rosetta в Podman падает с **`ORA-00443` (PMON did not start)**.

`start-stack.sh` автоматически выбирает `docker/podman-network.stack.m2.yml`:
- **Oracle Database 23 Free** (`gvenzl/oracle-free:23-slim`) — нативный **arm64**
- PDB: **FREEPDB1** (вместо XE)
- Intel Mac / Linux → `podman-network.stack.yml` (Oracle XE 11)

## Быстрый старт

### 1. Podman machine (macOS)

```bash
podman machine init --cpus 4 --memory 16384 --disk-size 60   # M2: 16 GB RAM (два Oracle XE)
podman machine start
podman run --rm hello-world
```

После перезагрузки Mac: `podman machine start`.

### 2. Запуск стека

```bash
git clone https://github.com/uchkur/radar.git
cd radar
chmod +x scripts/start-stack.sh
./scripts/start-stack.sh
```

Скрипт сам выбирает compose (M2 → `.m2.yml`) и освобождает занятые порты.

Ручной запуск на **M2**:

```bash
./scripts/reset-oracle-volumes.sh   # после ORA-00443 обязательно
podman compose -f docker/podman-network.stack.m2.yml up -d
```

Ожидание Oracle (на M2 до 20 мин, `start-stack.sh` показывает прогресс):

```bash
# сначала проверь, что контейнер есть:
podman ps -a | grep oracle-wdc

# логи (без -f — сразу видно, есть ли что-то):
podman logs --tail 50 oracle-wdc
podman compose -f docker/podman-network.stack.yml logs --tail 50 oracle-wdc

podman inspect -f '{{.State.Health.Status}}' oracle-wdc   # starting → healthy
```

**`podman logs -f oracle-wdc` ничего не выводит**

1. Контейнер **не существует** — `podman ps -a` пустой → запусти `./scripts/start-stack.sh`
2. Контейнер **ещё молчит** (распаковка БД) — `-f` ждёт первой строки; смотри без follow или в foreground:
   ```bash
   ./scripts/diagnose-stack.sh
   ./scripts/run-oracle-wdc-foreground.sh   # весь вывод Oracle в терминал
   ```
3. Podman machine **не запущена** → `podman machine start`

### 3. Инициализация Oracle

**M2 (Oracle 23 Free, PDB FREEPDB1):**

```bash
podman exec -i oracle-wdc sqlplus -s system/test@//localhost:1521/FREEPDB1 <<'SQL'
CREATE USER monitor IDENTIFIED BY monitor;
GRANT CONNECT, RESOURCE TO monitor;
SQL

podman exec -i oracle-wdc sqlplus -s monitor/monitor@//localhost:1521/FREEPDB1 <<'SQL'
CREATE TABLE dg_sim (primary_site VARCHAR2(3) NOT NULL);
INSERT INTO dg_sim VALUES ('WDC');
COMMIT;
SQL

podman exec -i oracle-cdc sqlplus -s system/test@//localhost:1521/FREEPDB1 <<'SQL'
CREATE USER monitor IDENTIFIED BY monitor;
GRANT CONNECT, RESOURCE TO monitor;
SQL
```

**Intel (Oracle XE 11):** замени `@//localhost:1521/FREEPDB1` на `@localhost/XE`.

### 4. Grafana

```bash
brew services start grafana
export GRAFANA_ETC=/opt/homebrew/etc/grafana   # Apple Silicon (M2)
./scripts/setup-grafana-prometheus.sh
brew services restart grafana
```

- Overview: http://localhost:3000/d/dataguard-overview/data-guard-overview
- Switchover History: http://localhost:3000/d/dataguard-switchover-history/data-guard-switchover-history

### 5. Switchover

```bash
# M2:
podman exec -i oracle-wdc sqlplus -s monitor/monitor@//localhost:1521/FREEPDB1 <<'SQL'
# Intel: @localhost/XE
UPDATE dg_sim SET primary_site = 'CDC';
COMMIT;
SQL
```

Вернуть WDC: `primary_site = 'WDC'`.

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
├── alloy/config.alloy
├── docker/podman-network.stack.yml   # полный стек в сети radar
├── docker/oracle-local.yml           # только Oracle (опционально)
├── oracle/custom-metrics.toml
├── prometheus/prometheus.yml
├── grafana/
└── scripts/
    ├── start-stack.sh
    └── setup-grafana-prometheus.sh
```

## Устранение неполадок

**`bind: address already in use` на :9161**

Старые контейнеры ещё держат порт. Останови стек:

```bash
podman compose -f docker/podman-network.stack.yml down
podman rm -f radar-exporter-wdc radar-exporter-cdc radar-prometheus radar-alloy oracle-wdc oracle-cdc
./scripts/start-stack.sh
```

**`ORA-00443: background process "PMON" did not start`**

На **M2** это ожидаемо для **Oracle XE 11 + Rosetta** — PMON не стартует под эмуляцией.

Решение — M2-стек с Oracle 23 Free (arm64):

```bash
./scripts/reset-oracle-volumes.sh
./scripts/start-stack.sh          # подхватит podman-network.stack.m2.yml
./scripts/run-oracle-wdc-foreground.sh   # отладка в терминале
```

Не смешивай volumes от XE 11 (`/u01/...`) и Free 23 (`/opt/oracle/...`) — всегда `reset-oracle-volumes.sh` при смене стека.

## Нативный Alloy (опционально)

Если установлен Oracle Instant Client на macOS:

```bash
brew install alloy prometheus
alloy run alloy/config.alloy.native
```

Иначе используй Podman-стек: `./scripts/start-stack.sh`.
