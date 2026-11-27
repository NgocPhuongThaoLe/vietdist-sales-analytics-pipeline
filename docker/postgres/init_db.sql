-- Single source of truth for the schemas and the ingest log.
-- Docker runs this file on the first start of an empty volume.
-- loaders/loader.py (ensure_log_table) also runs it before every load,
-- so every statement must stay safe to repeat (IF NOT EXISTS).

-- Three-layer architecture
CREATE SCHEMA IF NOT EXISTS raw;       -- Layer 1: Bronze (Python loaders)
CREATE SCHEMA IF NOT EXISTS staging;   -- Layer 2: Silver (dbt views)
CREATE SCHEMA IF NOT EXISTS dwh;       -- Layer 3: Gold  (dbt star schema + marts)
CREATE SCHEMA IF NOT EXISTS snapshots; -- dbt snapshot (dim_employee SCD2)

-- One row per sheet (or CSV file) per run, written by the Python loaders
CREATE TABLE IF NOT EXISTS raw.ingest_log (
    log_id        BIGSERIAL PRIMARY KEY,
    batch_id      TEXT        NOT NULL,
    source_id     TEXT        NOT NULL,
    file_name     TEXT        NOT NULL,
    file_hash     TEXT,
    sheet         TEXT,
    target_table  TEXT,
    row_count     INTEGER,
    status        TEXT        NOT NULL,  -- success | skipped | failed
    error         TEXT,
    started_at    TIMESTAMPTZ NOT NULL,
    finished_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS ix_ingest_log_lookup
    ON raw.ingest_log (source_id, file_hash, status);
