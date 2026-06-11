# JSON дашборды Grafana для Data Guard (drill-down)

Импорт этих дашбордов даёт рабочую цепочку переходов: **топология → обзор узла → дашборд по типу проблемы**.

## Импорт

В Grafana: **Dashboards → New → Import** (или **Import** на странице дашбордов). Загрузи JSON-файл или вставь его содержимое.

Рекомендуемый порядок:

1. **dataguard-overview.json** — главный дашборд: топология **WDC (Primary) → CDC (Standby)** уже встроена в панель HTML. Импортируй JSON как есть; в панели Text отключи **Sanitize**, если SVG не отображается.
2. **primary-overview.json**, **standby-overview.json**, **replication-overview.json** — обзорные дашборды по узлам (ссылки на Tablespaces, Jobs, Commit time и т.д.).
3. Остальные JSON в этой папке — дашборды-заглушки, на которые ведут ссылки с обзорных (primary-tablespaces, primary-jobs, standby-tablespaces, replication-lag и т.д.). Их можно потом заменить на полноценные дашборды с метриками.

## UID дашбордов (для ссылок)

- `dataguard-overview` — топология (кликабельная).
- `primary-overview`, `standby-overview`, `replication-overview` — обзоры по узлам.
- `primary-tablespaces`, `primary-jobs`, `primary-commit-time` — Primary drill-down.
- `standby-tablespaces`, `standby-jobs`, `standby-commit-time` — Standby drill-down.
- `replication-lag`, `replication-destinations`, `replication-errors` — Replication drill-down.

Ссылки в топологии и в обзорных дашбордах используют эти UID; не меняй их без правки HTML и панелей.
