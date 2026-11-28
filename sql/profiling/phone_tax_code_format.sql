-- DQ12 / DQ13 – Format of phone and tax_code as stored in raw (text)
-- Question: the notebook read phone as int64 and tax_code as float/int64 (leading zero lost, '.0' added).
--           Is that also true in raw, where the loader reads every column as text (dtype=str)?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/phone_tax_code_format.sql
-- Pass: starts_with_0 = non_null for phone; dot_zero = 0 and non_digit = 0 for every column.
--       If so, the issue is read-time only and Silver needs a test, not a fix.

WITH v(source, col, val) AS (
              SELECT 'SRC03', 'phone',    phone    FROM raw.src03_customer_master
    UNION ALL SELECT 'SRC03', 'tax_code', tax_code FROM raw.src03_customer_master
    UNION ALL SELECT 'SRC06', 'phone',    phone    FROM raw.src06_distributor_master
    UNION ALL SELECT 'SRC06', 'tax_code', tax_code FROM raw.src06_distributor_master
    UNION ALL SELECT 'SRC07 ' || _sheet_name, 'phone', phone FROM raw.src07_employee_master
)

-- 1. Summary per source and column
SELECT
    source,
    col,
    count(*)                                            AS total_rows,
    count(val)                                          AS non_null,
    count(*) FILTER (WHERE val IS NULL)                 AS null_rows,
    count(*) FILTER (WHERE val LIKE '0%')               AS starts_with_0,
    count(*) FILTER (WHERE val ~ '[^0-9]')              AS non_digit,
    count(*) FILTER (WHERE val LIKE '%.0')              AS dot_zero,
    min(length(val))                                    AS min_length,
    max(length(val))                                    AS max_length
FROM v
GROUP BY source, col
ORDER BY source, col;

-- 2. Length distribution
WITH v(source, col, val) AS (
              SELECT 'SRC03', 'phone',    phone    FROM raw.src03_customer_master
    UNION ALL SELECT 'SRC03', 'tax_code', tax_code FROM raw.src03_customer_master
    UNION ALL SELECT 'SRC06', 'phone',    phone    FROM raw.src06_distributor_master
    UNION ALL SELECT 'SRC06', 'tax_code', tax_code FROM raw.src06_distributor_master
    UNION ALL SELECT 'SRC07 ' || _sheet_name, 'phone', phone FROM raw.src07_employee_master
)
SELECT source, col, length(val) AS length, count(*) AS rows
FROM v
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
