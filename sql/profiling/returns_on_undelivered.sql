-- DQ16 – Returns on sales lines that were not delivered
-- Question: how many SRC09 returns point to an SRC01 line whose delivery_status is not
--           'Delivered' (i.e. 'Cancelled' or 'Delivering'), and is any return dated
--           before its order?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/returns_on_undelivered.sql
-- Pass: return_before_order = 0. The undelivered count has no pass value: it is the size of
--       the is_return_on_undelivered flag.
-- SRC01 delivery_status values (checked 2026-11-28): 'Delivered', 'Delivering', 'Cancelled'.
-- Join: original_order_id + product_id -> order_id + product_id (1:1, see fk_return_sales_line.sql).
-- Raw is text: return_amount cast to numeric to sum; dates are YYYY-MM-DD text, so text comparison is chronological.

WITH r AS (
    SELECT
        r.return_id,
        r.return_date,
        r.return_amount::numeric    AS return_amount,
        s.order_date,
        s.delivery_status
    FROM raw.src09_return_transactions r
    JOIN raw.src01_sales_transactions s
      ON s.order_id = r.original_order_id
     AND s.product_id = r.product_id
)

-- 1. Returns by the sales line's delivery_status
SELECT
    delivery_status,
    count(*)                AS returns,
    sum(return_amount)      AS return_amount_vnd
FROM r
GROUP BY delivery_status
ORDER BY delivery_status;

-- 2. Summary
WITH r AS (
    SELECT
        r.return_date,
        r.return_amount::numeric    AS return_amount,
        s.order_date,
        s.delivery_status
    FROM raw.src09_return_transactions r
    JOIN raw.src01_sales_transactions s
      ON s.order_id = r.original_order_id
     AND s.product_id = r.product_id
)
SELECT
    (SELECT count(*) FROM raw.src09_return_transactions)                    AS returns_total,
    count(*)                                                                AS returns_matched,
    count(*) FILTER (WHERE delivery_status <> 'Delivered')                  AS returns_on_undelivered,
    sum(return_amount) FILTER (WHERE delivery_status <> 'Delivered')        AS undelivered_return_amount_vnd,
    count(*) FILTER (WHERE return_date < order_date)                        AS return_before_order
FROM r;

-- 3. Order-level view (delivery_status is line-level, see order_header_consistency.sql):
--    returns whose order has at least one line that is not 'Delivered'
SELECT
    count(*)                                                                AS returns_total,
    count(*) FILTER (WHERE EXISTS (SELECT 1 FROM raw.src01_sales_transactions s
                                   WHERE s.order_id = r.original_order_id
                                     AND s.delivery_status <> 'Delivered')) AS returns_in_order_with_undelivered_line,
    sum(r.return_amount::numeric)
        FILTER (WHERE EXISTS (SELECT 1 FROM raw.src01_sales_transactions s
                              WHERE s.order_id = r.original_order_id
                                AND s.delivery_status <> 'Delivered'))      AS amount_in_order_with_undelivered_line_vnd
FROM raw.src09_return_transactions r;
