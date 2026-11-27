-- DQ03 – FK: every customer_id exists in raw.src03_customer_master
-- Returns the failing rows (0 rows = pass)
SELECT s.order_id, s.product_id, s.customer_id
FROM staging.stg_sales_transactions s
WHERE NOT EXISTS (SELECT 1 FROM raw.src03_customer_master c
                  WHERE upper(trim(c.customer_id)) = s.customer_id)
