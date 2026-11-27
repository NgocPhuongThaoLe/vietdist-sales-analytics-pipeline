-- DQ15 – payment_status (line-level) only takes the values seen in raw
-- Returns the failing rows (0 rows = pass)
SELECT payment_status, count(*) AS n
FROM staging.stg_sales_transactions
WHERE payment_status IS NULL
   OR payment_status NOT IN ('Paid', 'Partial', 'Unpaid')
GROUP BY payment_status
