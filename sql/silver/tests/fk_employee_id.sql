-- DQ05 – FK: every employee_id exists in raw.src07_employee_master (v1 and v2 sheets)
-- Returns the failing rows (0 rows = pass)
SELECT s.order_id, s.product_id, s.employee_id
FROM staging.stg_sales_transactions s
WHERE NOT EXISTS (SELECT 1 FROM raw.src07_employee_master e
                  WHERE upper(trim(e.employee_id)) = s.employee_id)
