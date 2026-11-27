-- DQ11 – Territory mapping vs the July region transfers
-- Question: SRC08 has one version (v1, from 2024-01-01). 5 employees changed region on
--           2024-07-01 (SRC07 Change_Log, change_type = 'Chuyển vùng'). How many SRC08 rows
--           mapped to them still show the old region, and how much do they sell from July on?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/territory_vs_transfers.sql
-- Pass: read the counts (no pass/fail). Expected: 5 transfers, all effective 2024-07-01.
-- change_type values (checked 2026-11-28): 'Nghỉ việc' (resigned, 8 rows), 'Chuyển vùng' (region transfer, 5 rows).
-- Raw is text: net_amount cast to numeric; dates are YYYY-MM-DD text, so text comparison is chronological.

WITH transfers AS (
    SELECT employee_id, effective_date, old_region, new_region, old_team, new_team
    FROM raw.src07_employee_change_log
    WHERE change_type = 'Chuyển vùng'
),
mapping AS (
    SELECT
        t.employee_id,
        count(m.customer_id)                                    AS src08_rows,
        count(*) FILTER (WHERE m.region = t.old_region)         AS src08_rows_old_region,
        count(*) FILTER (WHERE m.region = t.new_region)         AS src08_rows_new_region
    FROM transfers t
    LEFT JOIN raw.src08_territory_mapping m ON m.employee_id = t.employee_id
    GROUP BY t.employee_id
),
sales AS (
    SELECT
        t.employee_id,
        count(s.order_id)                                       AS src01_lines_from_eff,
        sum(s.net_amount::numeric)                              AS src01_net_from_eff_vnd,
        count(*) FILTER (WHERE s.region = t.old_region)         AS src01_lines_from_eff_old_region,
        count(*) FILTER (WHERE s.region = t.new_region)         AS src01_lines_from_eff_new_region
    FROM transfers t
    LEFT JOIN raw.src01_sales_transactions s
           ON s.employee_id = t.employee_id
          AND s.order_date >= t.effective_date
    GROUP BY t.employee_id
)

-- 1. Per transferred employee
SELECT
    t.employee_id,
    t.effective_date,
    t.old_region,
    t.new_region,
    e.region                            AS src07_v2_region,
    m.src08_rows,
    m.src08_rows_old_region,
    m.src08_rows_new_region,
    s.src01_lines_from_eff,
    s.src01_net_from_eff_vnd,
    s.src01_lines_from_eff_old_region,
    s.src01_lines_from_eff_new_region
FROM transfers t
JOIN mapping m USING (employee_id)
JOIN sales s USING (employee_id)
LEFT JOIN raw.src07_employee_master e
       ON e.employee_id = t.employee_id AND e._sheet_name = 'Employee_v2_Adjustment'
ORDER BY t.employee_id;

-- 2. Totals, and overlap with the DQ09 off-territory lines (see off_territory_sales.sql)
WITH transfers AS (
    SELECT employee_id, effective_date, old_region, new_region
    FROM raw.src07_employee_change_log
    WHERE change_type = 'Chuyển vùng'
),
off_territory AS (
    SELECT s.employee_id, m.employee_id AS mapped_employee_id
    FROM raw.src01_sales_transactions s
    JOIN raw.src08_territory_mapping m ON m.customer_id = s.customer_id
    WHERE s.employee_id <> m.employee_id
)
SELECT
    (SELECT count(*) FROM transfers)                                            AS transferred_employees,
    (SELECT count(DISTINCT effective_date) FROM transfers)                      AS distinct_effective_dates,
    (SELECT min(effective_date) FROM transfers)                                 AS effective_date,
    (SELECT count(*) FROM raw.src08_territory_mapping m
       JOIN transfers t ON t.employee_id = m.employee_id)                       AS src08_rows_of_transferred,
    (SELECT count(*) FROM raw.src08_territory_mapping m
       JOIN transfers t ON t.employee_id = m.employee_id
      WHERE m.region = t.old_region)                                            AS src08_rows_still_old_region,
    (SELECT count(*) FROM raw.src01_sales_transactions s
       JOIN transfers t ON t.employee_id = s.employee_id
      WHERE s.order_date >= t.effective_date)                                   AS src01_lines_from_eff,
    (SELECT sum(s.net_amount::numeric) FROM raw.src01_sales_transactions s
       JOIN transfers t ON t.employee_id = s.employee_id
      WHERE s.order_date >= t.effective_date)                                   AS src01_net_from_eff_vnd,
    (SELECT count(*) FROM off_territory o
      WHERE o.employee_id IN (SELECT employee_id FROM transfers)
         OR o.mapped_employee_id IN (SELECT employee_id FROM transfers))        AS dq09_lines_involving_transferred,
    (SELECT count(*) FROM off_territory o
      WHERE o.employee_id IN (SELECT employee_id FROM transfers))               AS dq09_lines_sold_by_transferred,
    (SELECT count(*) FROM off_territory o
      WHERE o.mapped_employee_id IN (SELECT employee_id FROM transfers))        AS dq09_lines_mapped_to_transferred;
