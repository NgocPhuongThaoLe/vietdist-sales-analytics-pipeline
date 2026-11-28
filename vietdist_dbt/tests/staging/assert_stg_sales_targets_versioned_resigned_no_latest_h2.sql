-- A-DQ18 option (a): the 8 employees who resigned (stg_employees v2 resign_date not null) have no
-- latest target row in months 7-12; their 48 v1 H2 rows are superseded by v2.
-- Returns the failing rows (0 rows = pass).
select
    t.employee_id,
    t.plan_version,
    t.month
from {{ ref('stg_sales_targets_versioned') }} t
join {{ ref('stg_employees') }} e
  on e.employee_id = t.employee_id
 and e.employee_version = 'v2'
where e.resign_date is not null
  and t.month between 7 and 12
  and t.is_latest
