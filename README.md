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

- **Grafana, Python** — нативный `arm64` (`/opt/homebrew`).
- **Oracle XE 11** — только `amd64`; в compose указано `platform: linux/amd64` (Rosetta в Podman VM).
- **Prometheus, Alloy, exporter** — `arm64`.
- VM Podman: **≥ 12 GB RAM**; первый старт Oracle **до 20 минут** (`waiting` в compose — нормально).

```bash
podman run --rm --platform linux/amd64 alpine uname -m   # → x86_64
```

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

Скрипт поднимает `docker/podman-network.stack.yml` и **останавливает предыдущий стек**, если порты `9161`/`9162`/`9090` заняты (типичная ошибка `bind: address already in use`).

Ручной запуск:

```bash
podman compose -f docker/podman-network.stack.yml down
podman compose -f docker/podman-network.stack.yml up -d
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

```bash
podman exec -i oracle-wdc sqlplus -s system/test@localhost/XE <<'SQL'
CREATE USER monitor IDENTIFIED BY monitor;
GRANT CONNECT, RESOURCE TO monitor;
SQL

podman exec -i oracle-wdc sqlplus -s monitor/monitor@localhost/XE <<'SQL'
CREATE TABLE dg_sim (primary_site VARCHAR2(3) NOT NULL);
INSERT INTO dg_sim VALUES ('WDC');
COMMIT;
SQL

podman exec -i oracle-cdc sqlplus -s system/test@localhost/XE <<'SQL'
CREATE USER monitor IDENTIFIED BY monitor;
GRANT CONNECT, RESOURCE TO monitor;
SQL
```

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
podman exec -i oracle-wdc sqlplus -s monitor/monitor@localhost/XE <<'SQL'
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

**`oracle-wdc exited (187)` / `ORA-00443: PMON did not start`**

Код **187** — Oracle не смог запустить фоновый процесс (часто PMON). На M2 типичные причины:

1. **Битый volume** после прошлых падений или смены образа (`slim` ↔ `faststart`)
2. **Мало RAM** в Podman VM (нужно **16 GB** для двух XE)
3. Раньше стоял `mem_limit: 3g` — слишком мало для XE

Полный сброс и перезапуск:

```bash
./scripts/reset-oracle-volumes.sh
podman machine stop
podman machine set --memory 16384
podman machine start
./scripts/start-stack.sh
podman logs -f oracle-wdc
```

**`oracle-cdc exited (54)`**

Код 54 — ошибка инициализации БД. См. `./scripts/reset-oracle-volumes.sh` выше.

VM Podman: **16 GB RAM** рекомендуется на M2 (два Oracle XE + Rosetta + мониторинг).

**Oracle не стартует на M2 (Rosetta)**

```bash
podman machine stop && podman machine rm
podman machine init --cpus 4 --memory 16384 --disk-size 60
podman machine start
```

## Нативный Alloy (опционально)

Если установлен Oracle Instant Client на macOS:

```bash
brew install alloy prometheus
alloy run alloy/config.alloy.native
```

Иначе используй Podman-стек: `./scripts/start-stack.sh`.
