"""Чтение топологии Data Guard из Oracle (WDC/CDC)."""
import os
import re
import subprocess
from datetime import datetime, timezone

WDC = os.environ.get("WDC_CONTAINER", "compassionate_jepsen")
CDC = os.environ.get("CDC_CONTAINER", "oracle-cdc")
PASS = os.environ.get("ORACLE_PASSWORD", "test")


def run_sql(container: str, user: str, password: str, sql: str) -> str:
    r = subprocess.run(
        ["docker", "exec", "-i", container, "sqlplus", "-s", f"{user}/{password}@localhost/XE"],
        input=sql.strip() + "\n",
        capture_output=True,
        text=True,
    )
    for line in r.stdout.replace("\r", "").split("\n"):
        line = line.strip()
        if not line or line.startswith("-") or "SQL>" in line:
            continue
        if line in ("Connected.", "Disconnected from Oracle"):
            continue
        if re.match(r"^[A-Z][A-Z0-9_ ]+$", line) and " " in line and len(line) < 40:
            continue
        return line
    return ""


def site_info(container: str, site: str) -> dict:
    banner = run_sql(
        container, "system", PASS,
        "SET HEADING OFF\nSET FEEDBACK OFF\nSET PAGESIZE 0\n"
        "SELECT banner FROM v$version WHERE banner LIKE 'Oracle Database%';",
    )
    version = run_sql(
        container, "system", PASS,
        "SET HEADING OFF\nSET FEEDBACK OFF\nSET PAGESIZE 0\n"
        "SELECT REGEXP_SUBSTR(banner, '[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+') "
        "FROM v$version WHERE banner LIKE 'Oracle Database%';",
    )
    role = run_sql(
        container, "system", PASS,
        "SET HEADING OFF\nSET FEEDBACK OFF\nSET PAGESIZE 0\n"
        "SELECT database_role FROM v$database;",
    )
    return {
        "site": site,
        "version": version or None,
        "banner": banner or None,
        "database_role": role or None,
    }


def collect_meta() -> dict:
    primary = run_sql(
        WDC, "monitor", "monitor",
        "SET HEADING OFF\nSET FEEDBACK OFF\nSET PAGESIZE 0\nSELECT primary_site FROM dg_sim;",
    )
    if primary not in ("WDC", "CDC"):
        primary = "WDC"
    standby = "CDC" if primary == "WDC" else "WDC"
    return {
        "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "primary_site": primary,
        "standby_site": standby,
        "sites": {
            "WDC": site_info(WDC, "WDC"),
            "CDC": site_info(CDC, "CDC"),
        },
    }
