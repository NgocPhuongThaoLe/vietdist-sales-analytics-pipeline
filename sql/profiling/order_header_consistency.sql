-- DQ15 – Order-level fields that vary inside one order (SRC01)
-- Question: for each candidate order-level column, how many orders (order_id) have more than
--           one distinct value across their lines? 0 = the column is order-level (header);
--           > 0 = the column is line-level and must not be used to build an order header.
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/order_header_consistency.sql
-- Pass: read the counts (no pass/fail). A column is order-level only if its count = 0.
-- None of these columns has NULLs in raw (checked 2026-11-28), so count(DISTINCT) is exact.

WITH per_order AS (
    SELECT
        order_id,
        count(*)                            AS lines,
        count(DISTINCT order_date)          AS n_order_date,
        count(DISTINCT customer_id)         AS n_customer_id,
        count(DISTINCT employee_id)         AS n_employee_id,
        count(DISTINCT channel)             AS n_channel,
        count(DISTINCT region)              AS n_region,
        count(DISTINCT province)            AS n_province,
        count(DISTINCT delivery_status)     AS n_delivery_status,
        count(DISTINCT payment_method)      AS n_payment_method,
        count(DISTINCT payment_status)      AS n_payment_status
    FROM raw.src01_sales_transactions
    GROUP BY order_id
)

-- 1. Orders with more than one value, per column
SELECT
    count(*)                                            AS total_orders,
    count(*) FILTER (WHERE lines > 1)                   AS multi_line_orders,
    count(*) FILTER (WHERE n_order_date      > 1)       AS varying_order_date,
    count(*) FILTER (WHERE n_customer_id     > 1)       AS varying_customer_id,
    count(*) FILTER (WHERE n_employee_id     > 1)       AS varying_employee_id,
    count(*) FILTER (WHERE n_channel         > 1)       AS varying_channel,
    count(*) FILTER (WHERE n_region          > 1)       AS varying_region,
    count(*) FILTER (WHERE n_province        > 1)       AS varying_province,
    count(*) FILTER (WHERE n_delivery_status > 1)       AS varying_delivery_status,
    count(*) FILTER (WHERE n_payment_method  > 1)       AS varying_payment_method,
    count(*) FILTER (WHERE n_payment_status  > 1)       AS varying_payment_status
FROM per_order;
