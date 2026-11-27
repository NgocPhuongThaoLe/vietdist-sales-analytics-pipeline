-- DQ09 – Off-territory sales
-- Question: how many SRC01 sales lines were sold by a rep who is not the rep mapped to that
--           customer in SRC08?  Off-territory = s.employee_id <> m.employee_id (join on customer_id).
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/off_territory_sales.sql
-- Pass: query 1 duplicate_customer_ids = 0 (otherwise the join fans out). The off-territory count
--       has no pass value: it is the size of the is_off_territory flag. Plan figure: 4,192.
-- SRC08 has one version (v1, 2024-01-01 to 9999-12-31), so no date condition is needed in the join.
-- Raw is text: net_amount cast to numeric to sum; month taken from order_date.

-- 1. Precondition: customer_id is unique in SRC08
SELECT
    count(*)                                            AS src08_rows,
    count(DISTINCT customer_id)                         AS distinct_customer_ids,
    count(*) - count(DISTINCT customer_id)              AS duplicate_customer_ids,
    count(*) FILTER (WHERE customer_id IS NULL)         AS null_customer_ids
FROM raw.src08_territory_mapping;

-- 2. Off-territory lines (main definition), with H1 / H2 split
WITH s AS (
    SELECT
        s.employee_id,
        s.customer_id,
        extract(month FROM s.order_date::date)::int     AS order_month,
        s.net_amount::numeric                           AS net_amount,
        m.employee_id                                   AS mapped_employee_id
    FROM raw.src01_sales_transactions s
    LEFT JOIN raw.src08_territory_mapping m ON m.customer_id = s.customer_id
),
f AS (
    SELECT *,
           mapped_employee_id IS NOT NULL AND employee_id <> mapped_employee_id AS is_off_territory
    FROM s
)
SELECT
    count(*)                                                            AS lines,
    count(*) FILTER (WHERE mapped_employee_id IS NOT NULL)              AS lines_with_mapping,
    count(*) FILTER (WHERE is_off_territory)                            AS off_territory_lines,
    sum(net_amount) FILTER (WHERE is_off_territory)                     AS off_territory_net_amount_vnd,
    count(DISTINCT employee_id) FILTER (WHERE is_off_territory)         AS off_territory_sales_employees,
    count(DISTINCT mapped_employee_id) FILTER (WHERE is_off_territory)  AS off_territory_mapped_employees,
    count(DISTINCT customer_id) FILTER (WHERE is_off_territory)         AS off_territory_customers,
    count(*) FILTER (WHERE is_off_territory AND order_month BETWEEN 1 AND 6)   AS off_territory_lines_h1,
    count(*) FILTER (WHERE is_off_territory AND order_month BETWEEN 7 AND 12)  AS off_territory_lines_h2,
    sum(net_amount) FILTER (WHERE is_off_territory AND order_month BETWEEN 1 AND 6)  AS off_territory_net_h1_vnd,
    sum(net_amount) FILTER (WHERE is_off_territory AND order_month BETWEEN 7 AND 12) AS off_territory_net_h2_vnd
FROM f;

-- 3. Who the mapped (territory-owner) employees of the off-territory lines are,
--    tagged with their SRC07 change: resigned (v2 resign_date) or region transfer (Change_Log)
WITH f AS (
    SELECT
        s.employee_id,
        s.customer_id,
        s.order_date,
        s.net_amount::numeric       AS net_amount,
        m.employee_id               AS mapped_employee_id
    FROM raw.src01_sales_transactions s
    JOIN raw.src08_territory_mapping m ON m.customer_id = s.customer_id
    WHERE s.employee_id <> m.employee_id
)
SELECT
    f.mapped_employee_id,
    e.resign_date,
    c.change_type                                   AS change_log_type,
    count(*)                                        AS off_territory_lines,
    sum(f.net_amount)                               AS off_territory_net_amount_vnd,
    count(DISTINCT f.customer_id)                   AS customers,
    count(DISTINCT f.employee_id)                   AS selling_employees,
    min(f.order_date)                               AS first_order_date,
    max(f.order_date)                               AS last_order_date
FROM f
LEFT JOIN raw.src07_employee_master e
       ON e.employee_id = f.mapped_employee_id AND e._sheet_name = 'Employee_v2_Adjustment'
LEFT JOIN raw.src07_employee_change_log c ON c.employee_id = f.mapped_employee_id
GROUP BY 1, 2, 3
ORDER BY 1;
