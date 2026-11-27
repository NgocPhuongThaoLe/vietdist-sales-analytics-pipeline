-- DQ15 / DQ16 – delivery_status (line-level) only takes the values seen in raw
-- Returns the failing rows (0 rows = pass)
SELECT delivery_status, count(*) AS n
FROM staging.stg_sales_transactions
WHERE delivery_status IS NULL
   OR delivery_status NOT IN ('Delivered', 'Delivering', 'Cancelled')
GROUP BY delivery_status
