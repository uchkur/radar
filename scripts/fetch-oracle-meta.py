#!/usr/bin/env python3
"""Опционально: снимок oracle-meta.json на диск (основной путь — oracle-meta-server)."""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "scripts"))
from oracle_meta import collect_meta  # noqa: E402

OUT = REPO / "grafana/public/radar/oracle-meta.json"


def main() -> None:
    meta = collect_meta()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {OUT}")
    print(f"  {meta['primary_site']} (PRIMARY) → {meta['standby_site']} (STANDBY)")
    print("  Для автообновления дашборда используй: ./scripts/oracle-meta-server.sh")


if __name__ == "__main__":
    main()
