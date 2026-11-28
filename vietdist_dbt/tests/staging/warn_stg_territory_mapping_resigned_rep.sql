-- DQ09: customers still mapped to a rep who resigned (SRC07 v2 resign_date not null).
-- Expected to FAIL: it documents the stale mapping behind the 4,192 off-territory lines.
-- Returns one row per such customer; severity warn, so the build does not stop.
{{ config(severity = 'warn') }}

select
    m.customer_id,
    m.employee_id       as mapped_employee_id,
    e.resign_date
from {{ ref('stg_territory_mapping') }} m
join {{ ref('stg_employees') }} e
  on e.employee_id = m.employee_id
 and e.employee_version = 'v2'
where e.resign_date is not null
