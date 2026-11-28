-- DQ05: SRC07 has 114 employees in each sheet (v1 and v2).
-- Returns the versions whose row count is not 114, or a missing version (0 rows = pass).
with expected as (
    select v as employee_version from (values ('v1'), ('v2')) as t(v)
),
actual as (
    select employee_version, count(*) as n
    from {{ ref('stg_employees') }}
    group by employee_version
)
select
    coalesce(e.employee_version, a.employee_version)   as employee_version,
    coalesce(a.n, 0)                                    as actual_rows,
    114                                                 as expected_rows
from expected e
full join actual a on a.employee_version = e.employee_version
where coalesce(a.n, 0) <> 114
