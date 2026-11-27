"""Load all raw sources into Postgres (schema raw).

Usage (from the project root):
    python loaders/run_all.py                 # all 10 sources
    python loaders/run_all.py --only SRC01    # one or more sources
    python loaders/run_all.py --force         # reload even if the file is unchanged
"""
# Imports
from __future__ import annotations

import argparse
import logging
import sys
import uuid

from config import DATA_RAW_DIR, SOURCES
from loader import ensure_log_table, get_engine, load_source


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Load raw sources into Postgres")
    parser.add_argument("--only", nargs="+", metavar="SRC",
                        help="source ids to load, e.g. SRC01 SRC05")
    parser.add_argument("--force", action="store_true",
                        help="reload even if the same file was already loaded")
    args = parser.parse_args(argv)
    # .env is already loaded by config.py (project root, any working directory)

    # Vietnamese text in logs/errors must not crash the run when stdout is a
    # pipe with a non-UTF-8 code page (Windows, Airflow, CI)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(levelname)s %(name)s: %(message)s")

    # Pick which sources to run
    sources = SOURCES
    if args.only:
        wanted = {s.upper() for s in args.only}
        unknown = wanted - {c["source_id"] for c in SOURCES}
        if unknown:
            parser.error(f"unknown source(s): {sorted(unknown)}")
        sources = [c for c in SOURCES if c["source_id"] in wanted]

    engine = get_engine()
    ensure_log_table(engine)
    batch_id = uuid.uuid4().hex[:12]  # one id for the whole run

    # Run each source; a failure does not stop the others
    results = []
    for cfg in sources:
        results += load_source(engine, cfg, DATA_RAW_DIR, batch_id, force=args.force)

    # Summary
    print(f"\nBatch {batch_id}")
    for r in results:
        print(f"{r['status']:8} {r['source_id']:6} {str(r['sheet'] or '-'):12} "
              f"{str(r['table'] or '-'):22} rows={r['rows']:>7}"
              + (f"  error={r['error']}" if r.get("error") else ""))

    n_failed = sum(r["status"] == "failed" for r in results)
    print(f"\n{n_failed} failed")
    # Exit code 1 on failure -> Airflow / CI will mark the run as failed later
    return 1 if n_failed else 0


if __name__ == "__main__":
    sys.exit(main())