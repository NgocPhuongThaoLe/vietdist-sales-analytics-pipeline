-- DQ01 / DQ08 – reconciliation: staging keeps every raw row (expected 119,101)
-- Returns one row if the count is wrong (0 rows = pass)
SELECT count(*) AS actual_rows, 119101 AS expected_rows
FROM staging.stg_sales_transactions
HAVING count(*) <> 119101
