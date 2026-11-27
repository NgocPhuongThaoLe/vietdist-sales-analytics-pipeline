-- DQ15 – payment_method (line-level) only takes the values seen in raw (Vietnamese, NFC)
-- Returns the failing rows (0 rows = pass)
SELECT payment_method, count(*) AS n
FROM staging.stg_sales_transactions
WHERE payment_method IS NULL
   OR payment_method NOT IN (normalize('Chuyển khoản', NFC),
                             normalize('Công nợ', NFC),
                             normalize('Tiền mặt', NFC))
GROUP BY payment_method
