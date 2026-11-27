-- DQ08 – Sales after the employee's resign date
-- Question: how many SRC01 sales lines belong to the 8 resigned employees after they left,
--           under the two candidate rules?
--   Rule 1 (chosen): order_date >  resign_date          (resign day counts as worked)
--   Rule 2 (rejected): order_date >= '2024-07-01'       (Change_Log effective_date = HR recording date)
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/dq08_resign_rule.sql
-- Raw dates are text YYYY-MM-DD (checked in data_period.sql), so text comparison is chronological.
-- Raw amounts are text (e.g. '908000.0'); cast here only to sum.

WITH resigned AS (
    -- Resigned employees: resign_date is filled in the v2 sheet only
    SELECT employee_id, resign_date
    FROM raw.src07_employee_master
    WHERE _sheet_name = 'Employee_v2_Adjustment'
      AND resign_date IS NOT NULL
),
change_log AS (
    SELECT employee_id, change_type, effective_date
    FROM raw.src07_employee_change_log
),
sales AS (
    SELECT s.employee_id, s.order_date, s.net_amount::numeric AS net_amount, r.resign_date
    FROM raw.src01_sales_transactions s
    JOIN resigned r ON r.employee_id = s.employee_id
)

-- 1. Totals under both rules
SELECT
    (SELECT count(*) FROM resigned)                                       AS resigned_employees,
    count(*)                                                              AS sales_lines_of_resigned,
    count(*) FILTER (WHERE order_date >  resign_date)                     AS rule1_lines_after_resign_date,
    count(*) FILTER (WHERE order_date >= '2024-07-01')                    AS rule2_lines_from_2024_07_01,
    count(*) FILTER (WHERE order_date > resign_date
                       AND order_date < '2024-07-01')                     AS lines_rule1_only,
    count(*) FILTER (WHERE order_date >= '2024-07-01'
                       AND order_date <= resign_date)                     AS lines_rule2_only,
    sum(net_amount) FILTER (WHERE order_date >  resign_date)              AS rule1_net_amount,
    sum(net_amount) FILTER (WHERE order_date >= '2024-07-01')             AS rule2_net_amount
FROM sales;

-- 2. Per employee
SELECT
    r.employee_id,
    r.resign_date,
    c.change_type                                                         AS change_log_type,
    c.effective_date                                                      AS change_log_date,
    count(s.order_date)                                                   AS sales_lines,
    max(s.order_date)                                                     AS last_order_date,
    count(*) FILTER (WHERE s.order_date >  r.resign_date)                 AS rule1_lines,
    count(*) FILTER (WHERE s.order_date >= '2024-07-01')                  AS rule2_lines
FROM (SELECT employee_id, resign_date FROM raw.src07_employee_master
      WHERE _sheet_name = 'Employee_v2_Adjustment' AND resign_date IS NOT NULL) r
LEFT JOIN raw.src07_employee_change_log c ON c.employee_id = r.employee_id
LEFT JOIN raw.src01_sales_transactions s  ON s.employee_id = r.employee_id
GROUP BY 1, 2, 3, 4
ORDER BY 1;

-- 3. Reconciliation: flagging never drops rows, so total net revenue must equal raw
SELECT count(*) AS src01_lines, sum(net_amount::numeric) AS src01_net_amount_vnd
FROM raw.src01_sales_transactions;
