# Imports
from __future__ import annotations

import csv
import hashlib
import io
import logging
import os
import re
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from sqlalchemy import URL, create_engine, inspect, text
from sqlalchemy.engine import Connection, Engine

from config import DB, INIT_DB_SQL, META_COLS, SCHEMA_RAW
from reader import read_source

logger = logging.getLogger(__name__)

RAW_SCHEMA = SCHEMA_RAW
CHUNK_SIZE = 50_000  # rows per COPY batch


# Connection
def get_engine() -> Engine:
    # Settings come from config.DB (which reads .env).
    # DATABASE_URL, if set, wins (handy for CI / Airflow later).
    url = os.getenv("DATABASE_URL")
    if not url:
        if not DB["password"]:
            raise RuntimeError("POSTGRES_PASSWORD is not set in .env")
        url = URL.create(
            "postgresql+psycopg2",
            username=DB["user"],
            password=DB["password"],  # special chars are escaped
            host=DB["host"],
            port=DB["port"],
            database=DB["dbname"],
        )
    return create_engine(url, connect_args={"connect_timeout": 10})


def ensure_log_table(engine: Engine) -> None:
    # init_db.sql is the single definition of the schemas and raw.ingest_log.
    # Docker runs it only on an empty volume; running it here as well is safe
    # (every statement uses IF NOT EXISTS) and covers an existing database.
    with engine.begin() as conn:
        conn.exec_driver_sql(INIT_DB_SQL.read_text(encoding="utf-8"))


# Main Function
# Load ONE source (all its sheets) into raw.*, and write ingest_log.
# Errors are logged as "failed" so run_all can continue with the next source.
def load_source(engine: Engine, cfg: dict, data_dir: Path,
                batch_id: str, force: bool = False) -> list[dict]:
    sid = cfg["source_id"]
    path = Path(data_dir) / cfg["file"]
    started = _now()
    base_log = {"batch_id": batch_id, "source_id": sid,
                "file_name": path.name, "started_at": started}
    file_hash = None

    try:
        file_hash = file_sha256(path)

        # Same file already loaded OK -> skip (makes the run re-runnable)
        if not force and already_loaded(engine, sid, file_hash):
            logger.info("%s: file unchanged (hash %s...) -> skipped", sid, file_hash[:8])
            with engine.begin() as conn:
                _write_log(conn, **base_log, file_hash=file_hash, status="skipped",
                           finished_at=_now())
            return [{"source_id": sid, "sheet": None, "table": None,
                     "rows": 0, "status": "skipped"}]

        frames = read_source(path, cfg)
        loaded_at = _now()
        results = []

        # Group sheets by target table: SRC02/SRC07 v1 + v2 go into ONE table
        by_table: dict[str, list[pd.DataFrame]] = {}
        for sheet, df in frames.items():
            table = target_table(cfg, sheet)
            by_table.setdefault(table, []).append(
                add_metadata(df, path, sheet, file_hash, batch_id, loaded_at))
            results.append({"source_id": sid, "sheet": sheet, "table": table,
                            "rows": len(df), "status": "success"})

        # One transaction per file: all sheets load, or none do
        with engine.begin() as conn:
            for table, dfs in by_table.items():
                # concat aligns columns; a column missing in one version -> NULL
                write_table(conn, pd.concat(dfs, ignore_index=True), table)
            for r in results:
                _write_log(conn, **base_log, file_hash=file_hash, sheet=r["sheet"],
                           target_table=f"{RAW_SCHEMA}.{r['table']}", row_count=r["rows"],
                           status="success", finished_at=_now())
        return results

    except Exception as e:
        logger.exception("%s: load failed", sid)
        try:
            with engine.begin() as conn:
                _write_log(conn, **base_log, file_hash=file_hash, status="failed",
                           error=str(e)[:2000], finished_at=_now())
        except Exception:
            # e.g. the database itself is down: still report, do not crash the run
            logger.exception("%s: could not write the failed row to ingest_log", sid)
        return [{"source_id": sid, "sheet": None, "table": None,
                 "rows": 0, "status": "failed", "error": str(e)}]


# Helpers
def file_sha256(path: Path) -> str:
    # Read in 1 MB chunks so big files do not fill memory
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def already_loaded(engine: Engine, source_id: str, file_hash: str) -> bool:
    sql = text(f"""
        SELECT 1 FROM {RAW_SCHEMA}.ingest_log
        WHERE source_id = :sid AND file_hash = :h AND status = 'success'
        LIMIT 1
    """)
    with engine.connect() as conn:
        return conn.execute(sql, {"sid": source_id, "h": file_hash}).first() is not None


def target_table(cfg: dict, sheet: str | None) -> str:
    # Table name from config: "table" for CSV, "sheets" mapping for Excel
    if sheet is None and cfg.get("table"):
        return cfg["table"]
    if sheet is not None and cfg.get("sheets", {}).get(sheet):
        return cfg["sheets"][sheet]
    return table_name(cfg["source_id"], sheet)  # fallback


def table_name(source_id: str, sheet: str | None) -> str:
    # ("SRC02", "v1") -> "src02_v1" ; ("SRC01", None) -> "src01"
    name = source_id.lower()
    if sheet:
        name += "_" + re.sub(r"\W+", "_", sheet.lower()).strip("_")
    return name


def add_metadata(df: pd.DataFrame, path: Path, sheet: str | None,
                 file_hash: str, batch_id: str, loaded_at: datetime) -> pd.DataFrame:
    # _row_number is already set by the reader
    df = df.copy()
    df[META_COLS["source_file"]] = path.name
    df[META_COLS["sheet_name"]] = sheet  # None -> NULL for CSV
    df[META_COLS["file_hash"]] = file_hash
    df[META_COLS["batch_id"]] = batch_id
    df[META_COLS["loaded_at"]] = loaded_at
    return df


def write_table(conn: Connection, df: pd.DataFrame, table: str) -> None:
    # Full refresh. TRUNCATE (not DROP) so dbt views built on raw.* keep working.
    insp = inspect(conn)
    if insp.has_table(table, schema=RAW_SCHEMA):
        existing = [c["name"] for c in insp.get_columns(table, schema=RAW_SCHEMA)]
        if set(existing) != set(df.columns):
            raise RuntimeError(
                f"{RAW_SCHEMA}.{table}: columns changed "
                f"(new: {sorted(set(df.columns) - set(existing))}, "
                f"gone: {sorted(set(existing) - set(df.columns))}). "
                f"Drop the table (and any views on it), then rerun with --force."
            )
        conn.execute(text(f'TRUNCATE TABLE {RAW_SCHEMA}."{table}"'))
    # COPY instead of INSERT: ~50-100x faster for 100k+ rows
    df.to_sql(table, conn, schema=RAW_SCHEMA, if_exists="append",
              index=False, method=_copy_insert, chunksize=CHUNK_SIZE)


def _copy_insert(table, conn, keys, data_iter) -> None:
    # pandas calls this once per chunk. Uses Postgres COPY ... FROM STDIN.
    # Runs on the same connection -> stays inside the one-transaction-per-file.
    buf = io.StringIO()
    # QUOTE_NOTNULL: values are quoted, None is written unquoted.
    # In COPY csv, an unquoted empty field is NULL and "" is an empty string.
    csv.writer(buf, quoting=csv.QUOTE_NOTNULL).writerows(data_iter)
    buf.seek(0)
    cols = ", ".join(f'"{k}"' for k in keys)
    sql = f'COPY {table.schema}."{table.name}" ({cols}) FROM STDIN WITH (FORMAT csv)'
    with conn.connection.cursor() as cur:
        cur.copy_expert(sql, buf)


def _write_log(conn: Connection, **row) -> None:
    cols = ", ".join(row)
    vals = ", ".join(f":{k}" for k in row)
    conn.execute(text(f"INSERT INTO {RAW_SCHEMA}.ingest_log ({cols}) VALUES ({vals})"), row)


def _now() -> datetime:
    return datetime.now(timezone.utc)
