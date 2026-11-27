-- DQ01 – PK not null: order_id and product_id are never NULL
-- Returns the failing rows (0 rows = pass)
SELECT order_id, product_id, _row_number
FROM staging.stg_sales_transactions
WHERE order_id IS NULL
   OR product_id IS NULL
