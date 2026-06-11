# Radar

Мониторинг Oracle Data Guard: **Oracle 11 XE (WDC/CDC)** → **oracledb_exporter** → **Grafana Alloy** → **Prometheus** → **Grafana**.

Инструкция ниже — развёртывание на **macOS** с **Podman** и общей bridge-сетью `radar` (контейнеры ходят друг к другу по DNS-именам, без `host.docker.internal`).

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

Все сервисы в одной сети `radar`. Порты проброшены на macOS-хост для Grafana, `sqlplus` и отладки.

## Требования

| Компонент | Установка |
|-----------|-----------|
| Podman | `brew install podman` |
| Compose (встроен в Podman 4+) | `podman compose version` |
| Grafana | `brew install grafana` |
| Python 3 | обычно уже есть на macOS |
| curl | для проверок |

Рекомендуется Podman **5.3+** (корректный `host.containers.internal`, если понадобится доступ к хосту из контейнера).

## 1. Podman machine (macOS)

Podman на macOS работает внутри Linux VM. Один раз:

```bash
podman machine init --cpus 4 --memory 8192 --disk-size 40
podman machine start
podman info | head -20
```

Проверка:

```bash
podman run --rm hello-world
podman compose version
```

При перезагрузке Mac:

```bash
podman machine start
```

## 2. Клонирование и запуск стека

```bash
git clone https://github.com/uchkur/radar.git
cd radar
chmod +x scripts/start-stack-podman.sh
./scripts/start-stack-podman.sh
```

Скрипт поднимает `docker/podman-network.stack.yml`:

- сеть `radar`
- `oracle-wdc`, `oracle-cdc`
- `radar-exporter-wdc`, `radar-exporter-cdc`
- `radar-prometheus`, `radar-alloy`

Первый запуск Oracle занимает **3–10 минут** (инициализация БД). Следи за логами:

```bash
podman logs -f oracle-wdc
# дождись "DATABASE IS READY TO USE"
```

Ручной запуск без скрипта:

```bash
podman compose -f docker/podman-network.stack.yml up -d
```

Остановка:

```bash
podman compose -f docker/podman-network.stack.yml down
# с удалением данных Oracle:
# podman compose -f docker/podman-network.stack.yml down -v
```

## 3. Инициализация Oracle (monitor + dg_sim)

После готовности WDC выполни на **WDC** (`oracle-wdc`):

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
```

На **CDC** (`oracle-cdc`) — пользователь monitor (dg_sim для топологии не обязателен):

```bash
podman exec -i oracle-cdc sqlplus -s system/test@localhost/XE <<'SQL'
CREATE USER monitor IDENTIFIED BY monitor;
GRANT CONNECT, RESOURCE TO monitor;
SQL
```

Проверка метрик (через ~30 с после инициализации):

```bash
curl -s "http://localhost:9090/api/v1/query?query=oracledb_radar_primary_site_info" | python3 -m json.tool
curl -s http://localhost:9161/metrics | grep oracledb_radar
```

## 4. Grafana на хосте

```bash
brew services start grafana

# Apple Silicon:
export GRAFANA_ETC=/opt/homebrew/etc/grafana
# Intel Mac (по умолчанию):
# export GRAFANA_ETC=/usr/local/etc/grafana

./scripts/setup-grafana-prometheus.sh
brew services restart grafana
```

Дашборды:

- Overview: http://localhost:3000/d/dataguard-overview/data-guard-overview
- Switchover History: http://localhost:3000/d/dataguard-switchover-history/data-guard-switchover-history

Логин Grafana по умолчанию: `admin` / `admin`.

## 5. Switchover (симуляция)

Меняется только `dg_sim` на WDC:

```bash
podman exec -i oracle-wdc sqlplus -s monitor/monitor@localhost/XE <<'SQL'
UPDATE dg_sim SET primary_site = 'CDC';
COMMIT;
SQL
```

Вернуть WDC Primary:

```bash
podman exec -i oracle-wdc sqlplus -s monitor/monitor@localhost/XE <<'SQL'
UPDATE dg_sim SET primary_site = 'WDC';
COMMIT;
SQL
```

Дашборд обновится после следующего scrape (~5–15 с).

## Сеть Podman: как это устроено

| Откуда | Куда | Адрес |
|--------|------|-------|
| exporter-wdc | Oracle WDC | `oracle-wdc:1521` |
| exporter-cdc | Oracle CDC | `oracle-cdc:1521` |
| alloy | exporters | `exporter-wdc:9161`, `exporter-cdc:9161` |
| alloy | prometheus | `prometheus:9090` |
| macOS (Grafana, curl) | prometheus | `localhost:9090` |
| macOS (sqlplus) | Oracle | `localhost:1521`, `localhost:1522` |

Имена резолвятся внутри сети `radar`. Порты `1521`, `1522`, `9090`, `9161`, `9162`, `12345` проброшены на хост через Podman machine.

### Отличие от Docker-варианта

Файл `docker/docker-compose.stack.yml` рассчитан на Oracle **на хосте** и использует `host.docker.internal`. Для Podman на macOS удобнее `docker/podman-network.stack.yml` — весь стек в одной сети.

Если Oracle уже крутится отдельно на хосте, можно использовать старый compose с подстановкой хоста:

```yaml
# в exporter DATA_SOURCE_NAME:
oracle://monitor:monitor@host.containers.internal:1521/XE
extra_hosts:
  - "host.containers.internal:host-gateway"
```

## Устранение неполадок

**Podman machine не стартует**

```bash
podman machine stop
podman machine start
podman machine ssh
```

**Экспортер не видит Oracle**

```bash
podman logs radar-exporter-wdc
podman exec radar-exporter-wdc ping -c1 oracle-wdc
```

Убедись, что `monitor` создан и `dg_sim` заполнена на WDC.

**Нет метрик в Prometheus**

```bash
podman ps --filter network=radar
curl http://localhost:12345/-/healthy
podman logs radar-alloy
```

**Порты заняты**

```bash
lsof -i :1521 -i :9090 -i :3000
```

**Мало памяти для Oracle**

```bash
podman machine stop
podman machine set --memory 12288
podman machine start
```

## Структура репозитория

```
radar/
├── alloy/config.alloy
├── docker/
│   ├── podman-network.stack.yml   # macOS Podman: всё в сети radar
│   ├── docker-compose.stack.yml   # Oracle на хосте + Docker
│   └── oracle-local.yml           # только Oracle (legacy)
├── oracle/custom-metrics.toml
├── prometheus/prometheus.yml
├── grafana/
└── scripts/
    ├── start-stack-podman.sh
    └── setup-grafana-prometheus.sh
```

## Альтернатива: Docker

```bash
./scripts/start-stack.sh   # Oracle должен быть на :1521/:1522
```

См. также `CHANGELOG.md` и теги релизов.
