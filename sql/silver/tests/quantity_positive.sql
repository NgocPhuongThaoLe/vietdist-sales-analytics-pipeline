-- Quantity must be > 0 (a NULL quantity fails too)
-- Returns the failing rows (0 rows = pass)
SELECT order_id, product_id, quantity
FROM staging.stg_sales_transactions
WHERE quantity IS NULL
   OR quantity <= 0
