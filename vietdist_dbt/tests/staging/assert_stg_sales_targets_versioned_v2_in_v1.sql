-- DQ18: every v2 employee-month also exists in v1 (target_overlap.sql: v2_months_missing_in_v1 = 0).
-- Returns the v2 rows with no v1 row for the same employee-month (0 rows = pass).
-- The view is read once (materialized CTE) and anti-joined; a correlated NOT EXISTS on the
-- versioned view re-ran its window functions per row (about 100 s).
with t as materialized (
    select employee_id, target_month, plan_version
    from {{ ref('stg_sales_targets_versioned') }}
)
select
    v2.employee_id,
    v2.target_month
from t v2
left join t v1
       on v1.plan_version = 'v1'
      and v1.employee_id = v2.employee_id
      and v1.target_month = v2.target_month
where v2.plan_version = 'v2'
  and v1.employee_id is null
