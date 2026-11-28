-- A-DQ18 / DQ18: at most one is_latest row per employee-month (exactly one where a latest row exists).
-- Returns the employee-months with more than one latest row (0 rows = pass).
select
    employee_id,
    target_month,
    count(*) filter (where is_latest)   as latest_rows
from {{ ref('stg_sales_targets_versioned') }}
group by employee_id, target_month
having count(*) filter (where is_latest) > 1
