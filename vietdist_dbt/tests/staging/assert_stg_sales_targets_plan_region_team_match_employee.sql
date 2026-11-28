-- DQ18 / DQ11: the region and team a target was set for equal the employee's region and team in the
-- same version (v1 rows vs stg_employees v1, v2 rows vs v2). 0 mismatches in raw (checked 2026-11-28).
-- Returns the failing target rows (0 rows = pass).
select
    t.employee_id,
    t.plan_version,
    t.month,
    t.plan_region,
    e.region        as employee_region,
    t.plan_team,
    e.team          as employee_team
from {{ ref('stg_sales_targets') }} t
left join {{ ref('stg_employees') }} e
       on e.employee_id = t.employee_id
      and e.employee_version = t.plan_version
where e.employee_id is null
   or e.region is distinct from t.plan_region
   or e.team is distinct from t.plan_team
