-- DQ08 – reconciliation: total net revenue equals raw (expected 158,957,563,200 VND)
-- Returns one row if the sum is wrong (0 rows = pass)
SELECT sum(net_amount) AS actual_net_vnd, 158957563200::numeric AS expected_net_vnd
FROM staging.stg_sales_transactions
HAVING sum(net_amount) IS DISTINCT FROM 158957563200::numeric
