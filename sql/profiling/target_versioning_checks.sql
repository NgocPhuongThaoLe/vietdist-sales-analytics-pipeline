-- DQ18 / A-DQ18 / A-T01 – Sales target version checks (reads the dbt staging views, not raw)
-- Question: does stg_sales_targets_versioned apply A-DQ18 option (a) exactly?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/target_versioning_checks.sql
--       (needs the dbt staging views: dbt build -s staging)
-- Pass: every row has pass = true.
-- Expected values come from target_overlap.sql (DQ18) and docs/assumptions_log.md (A-DQ18):
--   v1 1,332 rows (666 in months 1-6, 666 in 7-12), v2 618 rows, latest = 666 + 618 = 1,284,
--   48 v1 H2 rows of the 8 resigned employees superseded, H2 target v1 139,999,600,000 VND,
--   v2 139,998,000,000 VND (difference -1,600,000 = -10,743,800,000 removed + 10,742,200,000 added).

WITH t AS MATERIALIZED (
    SELECT * FROM staging.stg_sales_targets_versioned
),
resigned AS (
    SELECT employee_id FROM staging.stg_employees
    WHERE employee_version = 'v2' AND resign_date IS NOT NULL
),
per_month AS (
    SELECT employee_id, target_month, count(*) FILTER (WHERE is_latest) AS latest_rows
    FROM t
    GROUP BY employee_id, target_month
),
checks(check_no, check_name, expected, actual) AS (
              SELECT  1, 'rows total',                                     1950::numeric, (SELECT count(*) FROM t)::numeric
    UNION ALL SELECT  2, 'rows v1',                                        1332, (SELECT count(*) FROM t WHERE plan_version = 'v1')
    UNION ALL SELECT  3, 'rows v2',                                         618, (SELECT count(*) FROM t WHERE plan_version = 'v2')
    UNION ALL SELECT  4, 'duplicate employee x year x month x version',       0,
                     (SELECT count(*) - count(DISTINCT (employee_id, year, month, plan_version)) FROM t)
    UNION ALL SELECT  5, 'latest rows (is_latest)',                        1284, (SELECT count(*) FROM t WHERE is_latest)
    UNION ALL SELECT  6, 'latest rows v1 (months 1-6)',                     666, (SELECT count(*) FROM t WHERE is_latest AND plan_version = 'v1')
    UNION ALL SELECT  7, 'latest rows v2 (months 7-12)',                    618, (SELECT count(*) FROM t WHERE is_latest AND plan_version = 'v2')
    UNION ALL SELECT  8, 'latest v1 rows in months 7-12',                     0, (SELECT count(*) FROM t WHERE is_latest AND plan_version = 'v1' AND month >= 7)
    UNION ALL SELECT  9, 'employee-months with more than one latest row',     0, (SELECT count(*) FROM per_month WHERE latest_rows > 1)
    UNION ALL SELECT 10, 'employee-months with exactly one latest row',    1284, (SELECT count(*) FROM per_month WHERE latest_rows = 1)
    UNION ALL SELECT 11, 'employee-months with no latest row (resigned H2)',  48, (SELECT count(*) FROM per_month WHERE latest_rows = 0)
    UNION ALL SELECT 12, 'v2 employee-months missing in v1',                  0,
                     (SELECT count(*) FROM t v2 WHERE v2.plan_version = 'v2'
                        AND NOT EXISTS (SELECT 1 FROM t v1 WHERE v1.plan_version = 'v1'
                                          AND v1.employee_id = v2.employee_id AND v1.target_month = v2.target_month))
    UNION ALL SELECT 13, 'latest H2 rows of the 8 resigned employees',        0,
                     (SELECT count(*) FROM t WHERE is_latest AND month >= 7 AND employee_id IN (SELECT employee_id FROM resigned))
    UNION ALL SELECT 14, 'v1 rows superseded by v2',                        666, (SELECT count(*) FROM t WHERE superseded_by_version = 'v2')
    UNION ALL SELECT 15, 'superseded rows of resigned employees',            48,
                     (SELECT count(*) FROM t WHERE superseded_by_version IS NOT NULL AND employee_id IN (SELECT employee_id FROM resigned))
    UNION ALL SELECT 16, 'latest target_revenue months 7-12 (VND)', 139998000000,
                     (SELECT sum(target_revenue) FROM t WHERE is_latest AND month >= 7)
    UNION ALL SELECT 17, 'v1 target_revenue months 7-12 (VND)',     139999600000,
                     (SELECT sum(target_revenue) FROM t WHERE plan_version = 'v1' AND month >= 7)
    UNION ALL SELECT 18, 'latest minus v1, months 7-12 (VND)',          -1600000,
                     (SELECT sum(target_revenue) FILTER (WHERE is_latest) - sum(target_revenue) FILTER (WHERE plan_version = 'v1')
                      FROM t WHERE month >= 7)
    UNION ALL SELECT 19, 'superseded v1 target_revenue, resigned (VND)', 10743800000,
                     (SELECT sum(target_revenue) FROM t WHERE superseded_by_version IS NOT NULL
                        AND employee_id IN (SELECT employee_id FROM resigned))
    UNION ALL SELECT 20, 'v1 H2 rows with valid_to <> 2024-07-02',            0,
                     (SELECT count(*) FROM t WHERE plan_version = 'v1' AND month >= 7 AND valid_to <> date '2024-07-02')
    UNION ALL SELECT 21, 'latest rows with valid_to <> 9999-12-31',           0,
                     (SELECT count(*) FROM t WHERE is_latest AND valid_to <> date '9999-12-31')
    UNION ALL SELECT 22, 'plan versions in the data (A-T01)',                 2, (SELECT count(DISTINCT plan_version) FROM t)
)
SELECT check_no, check_name, expected, actual, expected = actual AS pass
FROM checks
ORDER BY check_no;
