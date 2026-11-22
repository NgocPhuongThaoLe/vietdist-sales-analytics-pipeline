-- Three-layer architecture
CREATE SCHEMA IF NOT EXISTS raw;       -- Layer 1: Bronze (Python loaders)
CREATE SCHEMA IF NOT EXISTS staging;   -- Layer 2: Silver (dbt views)
CREATE SCHEMA IF NOT EXISTS dwh;       -- Layer 3: Gold  (dbt star schema + marts)
CREATE SCHEMA IF NOT EXISTS snapshots; -- dbt snapshot (dim_employee SCD2)

-- One row per file load, written by the Python loaders
CREATE TABLE IF NOT EXISTS raw.ingest_log (
    ingest_id      BIGSERIAL PRIMARY KEY,
    batch_id       UUID         NOT NULL,
    source_file    TEXT         NOT NULL,
    sheet_name     TEXT,
    target_table   TEXT         NOT NULL,
    rows_loaded    INTEGER,
    status         TEXT         NOT NULL CHECK (status IN ('success', 'failed')),
    error_message  TEXT,
    started_at     TIMESTAMPTZ  NOT NULL,
    finished_at    TIMESTAMPTZ
);

-- Read-only role for Power BI
CREATE ROLE powerbi_reader WITH LOGIN PASSWORD 'change_me_reader';
GRANT CONNECT ON DATABASE vietdist TO powerbi_reader;
GRANT USAGE ON SCHEMA dwh TO powerbi_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA dwh GRANT SELECT ON TABLES TO powerbi_reader;