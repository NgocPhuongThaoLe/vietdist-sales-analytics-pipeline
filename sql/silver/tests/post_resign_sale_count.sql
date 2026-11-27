-- DQ08 / A-DQ08 – is_post_resign_sale flags exactly 547 lines (order_date > resign_date)
-- Returns one row if the count is wrong (0 rows = pass)
SELECT count(*) FILTER (WHERE is_post_resign_sale) AS actual_flagged, 547 AS expected_flagged
FROM staging.stg_sales_transactions
HAVING count(*) FILTER (WHERE is_post_resign_sale) <> 547
