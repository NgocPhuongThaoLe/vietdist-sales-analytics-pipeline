-- DQ01 – Grain of SRC01 sales transactions
-- Question: is one row = one order line (order_id + product_id)?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/grain_src01.sql
-- Pass: duplicate_rows = 0 and null_key_rows = 0

-- 1. Summary
SELECT
    count(*)                                                          AS total_rows,
    count(DISTINCT order_id)                                          AS distinct_orders,
    count(DISTINCT (order_id, product_id))                            AS distinct_order_lines,
    count(*) - count(DISTINCT (order_id, product_id))                 AS duplicate_rows,
    count(*) FILTER (WHERE order_id IS NULL OR product_id IS NULL)    AS null_key_rows
FROM raw.src01_sales_transactions;

-- 2. Examples of duplicated keys (empty if the grain holds)
SELECT order_id, product_id, count(*) AS n, array_agg(_row_number ORDER BY _row_number) AS source_rows
FROM raw.src01_sales_transactions
GROUP BY order_id, product_id
HAVING count(*) > 1
ORDER BY n DESC, order_id
LIMIT 10;
