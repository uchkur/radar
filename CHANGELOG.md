# Changelog

## [1.0.0] — 2026-05-22

Первый рабочий релиз локального стека мониторинга Oracle Data Guard (симуляция на 11 XE).

### Стек

- Oracle WDC/CDC (Docker) + `monitor.dg_sim` для switchover
- oracledb_exporter → Grafana Alloy → Prometheus → Grafana (brew)

### Дашборды

- **Data Guard Overview** — топология WDC↔CDC, анимация репликации, live-обновление из Prometheus (5s)
- **Data Guard Switchover History** — timeline и события `changes()` за выбранный период

### Метрики

- `oracledb_radar_primary_site_info`, `oracledb_radar_standby_site_info`
- `oracledb_radar_primary_code_code` (1=WDC, 2=CDC)
- `oracledb_radar_version_info`, `oracledb_radar_db_role_info`
