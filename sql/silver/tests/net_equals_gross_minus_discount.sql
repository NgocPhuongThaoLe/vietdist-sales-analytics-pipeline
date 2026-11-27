-- DQ14 – stored amounts are kept, so net_amount = gross_amount - discount_amount (tolerance 1 VND)
-- Returns the failing rows (0 rows = pass)
SELECT order_id, product_id, gross_amount, discount_amount, net_amount,
       net_amount - (gross_amount - discount_amount) AS diff
FROM staging.stg_sales_transactions
WHERE net_amount IS NULL
   OR gross_amount IS NULL
   OR discount_amount IS NULL
   OR abs(net_amount - (gross_amount - discount_amount)) > 1
