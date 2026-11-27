-- DQ04 – FK: every product_id exists in raw.src04_product_master
-- Returns the failing rows (0 rows = pass)
SELECT s.order_id, s.product_id
FROM staging.stg_sales_transactions s
WHERE NOT EXISTS (SELECT 1 FROM raw.src04_product_master p
                  WHERE upper(trim(p.product_id)) = s.product_id)
