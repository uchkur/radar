-- CDC (localhost:1522): тот же monitor.dg_sim для симуляции (как на WDC).
CREATE USER monitor IDENTIFIED BY monitor;
GRANT CONNECT, RESOURCE TO monitor;

-- от имени MONITOR:
-- CREATE TABLE dg_sim (primary_site VARCHAR2(3) NOT NULL);
-- INSERT INTO dg_sim VALUES ('WDC');
-- COMMIT;
