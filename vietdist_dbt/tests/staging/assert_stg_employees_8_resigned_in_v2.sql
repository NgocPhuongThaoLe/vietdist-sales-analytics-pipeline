-- DQ08: exactly 8 employees have a resign_date in v2 (dq08_resign_rule.sql: resigned_employees = 8),
-- and every one of them has status 'Resigned'.
-- Returns one row if either count is off (0 rows = pass).
select
    count(*) filter (where resign_date is not null)                         as with_resign_date,
    count(*) filter (where status = 'Resigned')                             as status_resigned,
    count(*) filter (where resign_date is not null and status = 'Resigned') as both,
    8                                                                       as expected
from {{ ref('stg_employees') }}
where employee_version = 'v2'
having count(*) filter (where resign_date is not null) <> 8
    or count(*) filter (where status = 'Resigned') <> 8
    or count(*) filter (where resign_date is not null and status = 'Resigned') <> 8
