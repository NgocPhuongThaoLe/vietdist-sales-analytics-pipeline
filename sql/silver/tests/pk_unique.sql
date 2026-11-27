-- DQ01 – PK unique: one row per order_id + product_id
-- Returns the failing rows (0 rows = pass)
SELECT order_id, product_id, count(*) AS n
FROM staging.stg_sales_transactions
GROUP BY order_id, product_id
HAVING count(*) > 1
