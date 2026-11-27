-- DQ19 – Data period of every date column
-- Question: which date columns fall outside 2024, and how far must dim_date reach?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/data_period.sql
-- Raw dates are text (YYYY-MM-DD), so min/max on text is chronological
-- as long as bad_format = 0.

WITH d(source, col, v) AS (
              SELECT 'SRC01', 'order_date',             order_date             FROM raw.src01_sales_transactions
    UNION ALL SELECT 'SRC02', 'version_date',           version_date           FROM raw.src02_sales_target
    UNION ALL SELECT 'SRC02', 'effective_from',         effective_from         FROM raw.src02_sales_target
    UNION ALL SELECT 'SRC02', 'effective_to',           effective_to           FROM raw.src02_sales_target
    UNION ALL SELECT 'SRC03', 'join_date',              join_date              FROM raw.src03_customer_master
    UNION ALL SELECT 'SRC04', 'launch_date',            launch_date            FROM raw.src04_product_master
    UNION ALL SELECT 'SRC05', 'order_date',             order_date             FROM raw.src05_distributor_orders
    UNION ALL SELECT 'SRC05', 'expected_delivery_date', expected_delivery_date FROM raw.src05_distributor_orders
    UNION ALL SELECT 'SRC05', 'actual_delivery_date',   actual_delivery_date   FROM raw.src05_distributor_orders
    UNION ALL SELECT 'SRC06', 'join_date',              join_date              FROM raw.src06_distributor_master
    UNION ALL SELECT 'SRC07', 'date_of_birth',          date_of_birth          FROM raw.src07_employee_master
    UNION ALL SELECT 'SRC07', 'join_date',              join_date              FROM raw.src07_employee_master
    UNION ALL SELECT 'SRC07', 'effective_date',         effective_date         FROM raw.src07_employee_master
    UNION ALL SELECT 'SRC07', 'resign_date',            resign_date            FROM raw.src07_employee_master
    UNION ALL SELECT 'SRC07 Change_Log', 'effective_date', effective_date      FROM raw.src07_employee_change_log
    UNION ALL SELECT 'SRC08', 'effective_date',         effective_date         FROM raw.src08_territory_mapping
    UNION ALL SELECT 'SRC08', 'expiry_date',            expiry_date            FROM raw.src08_territory_mapping
    UNION ALL SELECT 'SRC09', 'return_date',            return_date            FROM raw.src09_return_transactions
    UNION ALL SELECT 'SRC10', 'start_date',             start_date             FROM raw.src10_promotion_program
    UNION ALL SELECT 'SRC10', 'end_date',               end_date               FROM raw.src10_promotion_program
)
SELECT
    source,
    col,
    count(v)                                                   AS non_null,
    count(*) FILTER (WHERE v !~ '^\d{4}-\d{2}-\d{2}$')         AS bad_format,
    min(v)                                                     AS min_date,
    max(v)                                                     AS max_date,
    count(*) FILTER (WHERE v < '2024-01-01')                   AS before_2024,
    count(*) FILTER (WHERE v > '2024-12-31')                   AS after_2024
FROM d
GROUP BY source, col
ORDER BY source, col;
