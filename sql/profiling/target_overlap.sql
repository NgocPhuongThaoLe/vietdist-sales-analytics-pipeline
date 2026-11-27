-- DQ18 – Sales target versions overlap for July–December (SRC02)
-- Question: v1 (Plan_v1_Original) covers months 1–12, v2 (Plan_v2_Adjustment_H2) re-plans 7–12.
--           How big is the overlap, which v1 H2 rows have no v2 replacement, and why?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/target_overlap.sql
-- Pass: version_sheet_mismatch = 0, duplicate_keys = 0, v2_months_missing_in_v1 = 0;
--       v1 H2 employees without v2 = the resigned employees in SRC07 v2 (unmatched both ways = 0).
-- Raw is text: month cast to int for ranges, target_revenue cast to numeric to sum.

WITH t AS (
    SELECT
        _sheet_name,
        plan_version,
        employee_id,
        year,
        month::int                      AS month,
        target_revenue::numeric         AS target_revenue
    FROM raw.src02_sales_target
)

-- 1. Rows per version, H1 / H2 split, and plan_version vs _sheet_name
SELECT
    _sheet_name,
    plan_version,
    count(*)                                        AS rows,
    count(DISTINCT employee_id)                     AS employees,
    count(*) FILTER (WHERE month BETWEEN 1 AND 6)   AS rows_m1_6,
    count(*) FILTER (WHERE month BETWEEN 7 AND 12)  AS rows_m7_12,
    sum(target_revenue) FILTER (WHERE month BETWEEN 7 AND 12) AS target_revenue_m7_12
FROM t
GROUP BY 1, 2
ORDER BY 1, 2;

-- 2. Integrity: version label vs sheet, duplicate keys, v2 months missing in v1
WITH t AS (
    SELECT _sheet_name, plan_version, employee_id, year, month::int AS month
    FROM raw.src02_sales_target
)
SELECT
    count(*) FILTER (WHERE NOT ((_sheet_name = 'Plan_v1_Original'      AND plan_version = 'v1')
                             OR (_sheet_name = 'Plan_v2_Adjustment_H2' AND plan_version = 'v2')))
                                                                    AS version_sheet_mismatch,
    count(*) - count(DISTINCT (plan_version, employee_id, year, month)) AS duplicate_keys,
    count(*) FILTER (WHERE plan_version = 'v2'
                       AND NOT EXISTS (SELECT 1 FROM t v1
                                       WHERE v1.plan_version = 'v1'
                                         AND v1.employee_id = t.employee_id
                                         AND v1.year = t.year
                                         AND v1.month = t.month))  AS v2_months_missing_in_v1,
    count(*) FILTER (WHERE plan_version = 'v1' AND month BETWEEN 7 AND 12
                       AND EXISTS (SELECT 1 FROM t v2
                                   WHERE v2.plan_version = 'v2'
                                     AND v2.employee_id = t.employee_id
                                     AND v2.year = t.year
                                     AND v2.month = t.month))      AS v1_h2_rows_replaced_by_v2,
    count(*) FILTER (WHERE plan_version = 'v1' AND month BETWEEN 7 AND 12
                       AND NOT EXISTS (SELECT 1 FROM t v2
                                       WHERE v2.plan_version = 'v2'
                                         AND v2.employee_id = t.employee_id
                                         AND v2.year = t.year
                                         AND v2.month = t.month))  AS v1_h2_rows_without_v2
FROM t;

-- 3. Employees with v1 rows in months 7–12 but no v2 rows at all,
--    compared with the resigned employees in SRC07 v2 (resign_date not null)
WITH v1_h2 AS (
    SELECT employee_id, count(*) AS v1_h2_rows, sum(target_revenue::numeric) AS v1_h2_target_revenue
    FROM raw.src02_sales_target
    WHERE plan_version = 'v1' AND month::int BETWEEN 7 AND 12
    GROUP BY employee_id
),
no_v2 AS (
    SELECT h.*
    FROM v1_h2 h
    WHERE NOT EXISTS (SELECT 1 FROM raw.src02_sales_target v2
                      WHERE v2.plan_version = 'v2' AND v2.employee_id = h.employee_id)
),
resigned AS (
    SELECT employee_id, resign_date
    FROM raw.src07_employee_master
    WHERE _sheet_name = 'Employee_v2_Adjustment'
      AND resign_date IS NOT NULL
)
SELECT
    coalesce(n.employee_id, r.employee_id)  AS employee_id,
    n.v1_h2_rows,
    n.v1_h2_target_revenue,
    r.resign_date,
    CASE WHEN n.employee_id IS NULL THEN 'resigned but has v2 rows'
         WHEN r.employee_id IS NULL THEN 'no v2 rows but not resigned'
         ELSE 'match' END                   AS check_result
FROM no_v2 n
FULL JOIN resigned r ON r.employee_id = n.employee_id
ORDER BY 1;

-- 4. Summary of query 3 and the latest-row count under both options
--    (a) v1 H2 rows of employees without v2 are superseded  -> latest = v1 H1 + v2
--    (b) they are kept as latest                            -> latest = v1 H1 + v2 + those rows
WITH v1_h2_no_v2 AS (
    SELECT t.employee_id, t.target_revenue::numeric AS target_revenue
    FROM raw.src02_sales_target t
    WHERE t.plan_version = 'v1' AND t.month::int BETWEEN 7 AND 12
      AND NOT EXISTS (SELECT 1 FROM raw.src02_sales_target v2
                      WHERE v2.plan_version = 'v2' AND v2.employee_id = t.employee_id)
),
resigned AS (
    SELECT employee_id FROM raw.src07_employee_master
    WHERE _sheet_name = 'Employee_v2_Adjustment' AND resign_date IS NOT NULL
)
SELECT
    (SELECT count(DISTINCT employee_id) FROM v1_h2_no_v2)                       AS employees_v1_h2_without_v2,
    (SELECT count(*) FROM v1_h2_no_v2)                                          AS v1_h2_rows_without_v2,
    (SELECT sum(target_revenue) FROM v1_h2_no_v2)                               AS v1_h2_revenue_without_v2,
    (SELECT sum(target_revenue::numeric) FROM raw.src02_sales_target
      WHERE plan_version = 'v2')
  - (SELECT sum(target_revenue::numeric) FROM raw.src02_sales_target
      WHERE plan_version = 'v1' AND month::int BETWEEN 7 AND 12
        AND employee_id IN (SELECT employee_id FROM raw.src02_sales_target WHERE plan_version = 'v2'))
                                                                                AS v2_minus_v1_h2_same_employees,
    (SELECT count(*) FROM resigned)                                             AS resigned_employees_src07,
    (SELECT count(*) FROM resigned r
      WHERE NOT EXISTS (SELECT 1 FROM v1_h2_no_v2 n WHERE n.employee_id = r.employee_id))
                                                                                AS resigned_with_v2_rows,
    (SELECT count(DISTINCT n.employee_id) FROM v1_h2_no_v2 n
      WHERE NOT EXISTS (SELECT 1 FROM resigned r WHERE r.employee_id = n.employee_id))
                                                                                AS without_v2_not_resigned,
    (SELECT count(*) FROM raw.src02_sales_target WHERE plan_version = 'v1' AND month::int BETWEEN 1 AND 6)
  + (SELECT count(*) FROM raw.src02_sales_target WHERE plan_version = 'v2')     AS latest_rows_option_a,
    (SELECT count(*) FROM raw.src02_sales_target WHERE plan_version = 'v1' AND month::int BETWEEN 1 AND 6)
  + (SELECT count(*) FROM raw.src02_sales_target WHERE plan_version = 'v2')
  + (SELECT count(*) FROM v1_h2_no_v2)                                          AS latest_rows_option_b;
