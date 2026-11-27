-- DQ07 – FK: return -> sales line
-- Question: does every SRC09 return point to an existing SRC01 order line
--           (original_order_id + product_id -> order_id + product_id)?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/fk_return_sales_line.sql
-- Pass: no_matching_line = 0

-- 1. Match level for every return
SELECT
    count(*) AS returns,
    count(*) FILTER (WHERE EXISTS (SELECT 1 FROM raw.src01_sales_transactions s
                                   WHERE s.order_id = r.original_order_id
                                     AND s.product_id = r.product_id))      AS matches_order_line,
    count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM raw.src01_sales_transactions s
                                       WHERE s.order_id = r.original_order_id
                                         AND s.product_id = r.product_id)) AS no_matching_line,
    count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM raw.src01_sales_transactions s
                                       WHERE s.order_id = r.original_order_id)) AS order_not_found
FROM raw.src09_return_transactions r;

-- 2. Returns that match a line but return more than was sold
--    (raw is text: cast here only for the comparison)
SELECT count(*) AS returned_more_than_sold
FROM raw.src09_return_transactions r
JOIN raw.src01_sales_transactions s
  ON s.order_id = r.original_order_id AND s.product_id = r.product_id
WHERE r.return_quantity::int > s.quantity::int;
