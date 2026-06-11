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
- **один** Oracle Database 23 Free (`23-slim-faststart`) — нативный **arm64**
- PDB: **FREEPDB1**; оба exporter (WDC/CDC) подключаются к `oracle-wdc`
- два инстанса Oracle на M2 → **exit 54** (не хватает RAM)
- Intel Mac / Linux → два Oracle XE 11 в `podman-network.stack.yml`

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

# M2: один Oracle — CDC-инициализация не нужна (exporter-cdc → тот же oracle-wdc)
```

**Intel (Oracle XE 11):** два контейнера, подключение `@localhost/XE`; на CDC тоже `CREATE USER monitor`.

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

**`rootlessport listen tcp :9161: bind: address already in use`**

Пересоздание сети **не освобождает порт**. Его держит старый контейнер или зависший `rootlessport`/`gvproxy` в Podman machine.

```bash
./scripts/free-ports.sh          # остановка контейнеров + перезапуск machine при необходимости
./scripts/start-stack.sh

# если не помогло — принудительно:
RESTART_MACHINE=yes ./scripts/free-ports.sh

# кто занял порт:
lsof -iTCP:9161 -sTCP:LISTEN -P -n
podman ps -a --format '{{.Names}} {{.Ports}}' | grep 9161
```

**`ORA-01078` / `LRM-00109: could not open parameter file`**

Инициализация БД **прервалась** (exit 54, рестарт, нехватка RAM) — volume остался **битым**. Oracle ищет spfile и не находит.

```bash
./scripts/reset-oracle-volumes.sh      # удалить ВСЕ oracle volumes
./scripts/oracle-smoke-test.sh         # образ без volume — должен пройти
./scripts/run-oracle-wdc-foreground.sh # чистая инициализация с volume
# DATABASE IS READY TO USE → Ctrl+C → ./scripts/start-stack.sh
```

Не переключай `slim` ↔ `faststart` на одном volume.

**`oracle-wdc exited (54)` на M2**

Код 54 — БД не инициализировалась. Частые причины:
1. **Битый volume** после XE 11 или двух инстансов Free
2. **Два Oracle** на M2 — не хватает RAM (M2-стек использует **один** oracle-wdc)
3. Мало памяти Podman VM

```bash
./scripts/free-ports.sh
./scripts/reset-oracle-volumes.sh
podman machine set --memory 16384 && podman machine start
./scripts/run-oracle-wdc-foreground.sh   # смотри вывод в терминале
# после DATABASE IS READY TO USE:
./scripts/start-stack.sh
```

**`ORA-00443` (PMON)** — Oracle XE 11 + Rosetta; на M2 используй только `.m2.yml` (Oracle 23 Free arm64).

## Нативный Alloy (опционально)

Если установлен Oracle Instant Client на macOS:

```bash
brew install alloy prometheus
alloy run alloy/config.alloy.native
```

Иначе используй Podman-стек: `./scripts/start-stack.sh`.
