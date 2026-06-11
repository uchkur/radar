# Data Guard topology — SVG для Grafana

Схема топологии Oracle Data Guard для вставки в панель **Text** в Grafana: два узла в виде цилиндров БД, стрелка репликации с анимацией потока. Поддержка **кликов и drill-down**: клик по узлу открывает обзорный дашборд, оттуда — дашборды по типам проблем (Tablespaces, Jobs, Commit time и т.д.).

## Тест кликов (без Grafana)

Чтобы проверить клики и переходы по топологии **локально в браузере**:

1. Открой в браузере файл **`dataguard-topology-click-test.html`** (двойной клик или `file:///.../dataguard-topology-click-test.html`).
2. Кликни по **Primary**, **Standby** или по **стрелке** (Data Guard) — под схемой появится панель «Узел: … / Выберите дашборд» с кнопками (Tablespaces, Jobs, Commit time и т.д.).
3. Нажми на нужный дашборд — в новой вкладке откроется **`drill-target.html`** с подписью вида «Drill-down: Primary → Tablespaces» (страница-заглушка для проверки перехода).

Так можно убедиться, что области клика и логика drill-down работают, без запуска Grafana.

## Файлы

| Файл | Описание |
|------|----------|
| **dataguard-topology.svg** | Статичная схема: Primary (DC1) и Standby (DC2), подпись «Data Guard (replication)», анимация потока до начала наконечника стрелки. |
| **dataguard-topology-with-vars.html** | Та же схема с переменными Grafana `{{ $datacenter_primary }}` и `{{ $datacenter_standby }}` вместо имён датацентров. |
| **dataguard-topology-wdc-cdc.html** | Топология **WDC (Primary) → CDC (Standby)** — используется в главном дашборде `dataguard-overview.json`. |
| **dataguard-topology-grafana-links.html** | Кликабельная топология с переменными `{{ $datacenter_* }}` (альтернатива). |
| **dataguard-topology-click-test.html** | Локальный тест кликов: та же схема + панель выбора дашборда и переход на `drill-target.html`. |
| **drill-target.html** | Страница-заглушка для теста: показывает «Drill-down: узел → дашборд» по query-параметрам. |

## Содержимое схемы

- **Primary** и **Standby** нарисованы как цилиндры БД (иконка базы данных), с градиентами и «слоями» данных.
- Между ними — линия с наконечником стрелки и подписью **«Data Guard (replication)»**.
- Анимация: бегущий пунктир и движущиеся точки (поток данных) от Primary к Standby; поток заканчивается у начала стрелки, не заходя в остриё.
- Цвета: Primary — зелёные/бирюзовые (#059669, #5eead4…), Standby — синие (#0284c7, #38bdf8…), стрелка — градиент зелёный → синий.

## Как использовать в Grafana

### Вариант 1: статичная схема

1. Создай панель типа **Text**.
2. Режим отображения — **HTML**.
3. Скопируй содержимое `dataguard-topology.svg` в тело панели.
4. В настройках панели → **Options** при необходимости отключи **Sanitize**, чтобы SVG и анимация отображались.

### Вариант 2: с переменными (имена ДЦ с дашборда)

1. На дашборде создай переменные, например:
   - `datacenter_primary` (Constant или Query к Prometheus).
   - `datacenter_standby`.
2. Панель **Text** → режим **HTML**.
3. Вставь содержимое `dataguard-topology-with-vars.html`.
4. Отключи **Sanitize**, если SVG не отображается.

Переменные можно заполнять из метрик Prometheus (например, по label `datacenter` для primary/standby из Oracle DB Exporter).

### Вариант 3: кликабельная топология (drill-down в Grafana)

1. Импортируй дашборды из папки **`../dashboards-json/`** (см. README там): Data Guard Overview, Primary/Standby/Replication Overview, а также дашборды-заглушки Tablespaces, Jobs, Commit time, Lag, Destinations, Errors.
2. В дашборде **Data Guard Overview** (uid: `dataguard-overview`) замени содержимое панели на HTML из файла **`dataguard-topology-grafana-links.html`** (панель Text → режим HTML, Sanitize отключён).
3. Клик по **Primary** откроет дашборд Primary Overview, по **Standby** — Standby Overview, по **стрелке** — Replication Overview. С этих дашбордов по ссылкам можно перейти в дашборды Tablespaces, Jobs, Commit time и т.д.

## Цвета (для правок в SVG)

- Primary: обводка/акценты #059669, #047857, #065f46; заливки #ecfdf5, #d1fae5, #5eead4, #99f6e4.
- Standby: #0284c7, #0369a1, #075985; заливки #f0f9ff, #e0f2fe, #38bdf8, #bae6fd.
- Стрелка и поток: #0ea5e9, #059669 (градиент), подложка #cbd5e1.

При необходимости отредактируй атрибуты `fill` и `stroke` прямо в SVG/HTML.
