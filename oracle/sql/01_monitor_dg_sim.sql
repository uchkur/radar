-- WDC (localhost:1521): симуляция направления DG для локальной топологии.
-- После switchover: UPDATE monitor.dg_sim SET primary_site = 'CDC'; COMMIT;

-- Выполнять на WDC (system). Пользователь MONITOR уже может существовать.
CREATE USER monitor IDENTIFIED BY monitor;
GRANT CONNECT, RESOURCE TO monitor;

-- Таблица создаётся от имени MONITOR (см. scripts/fetch-oracle-meta.py):
--   CREATE TABLE dg_sim (primary_site VARCHAR2(3) NOT NULL);
--   INSERT INTO dg_sim VALUES ('WDC'); COMMIT;

-- Смена направления репликации (симуляция switchover):
--   UPDATE monitor.dg_sim SET primary_site = 'CDC'; COMMIT;
--   ./scripts/fetch-oracle-meta.sh && ./scripts/deploy-grafana-public.sh
