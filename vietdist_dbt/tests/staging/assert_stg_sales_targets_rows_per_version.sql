-- DQ18: SRC02 has 1,332 v1 rows (Plan_v1_Original) and 618 v2 rows (Plan_v2_Adjustment_H2)
-- (target_overlap.sql query 1). Returns the versions whose row count is off, or a missing version (0 rows = pass).
with expected as (
    select * from (values ('v1', 1332), ('v2', 618)) as t(plan_version, expected_rows)
),
actual as (
    select plan_version, count(*) as actual_rows
    from {{ ref('stg_sales_targets') }}
    group by plan_version
)
select
    coalesce(e.plan_version, a.plan_version)    as plan_version,
    coalesce(a.actual_rows, 0)                  as actual_rows,
    e.expected_rows
from expected e
full join actual a on a.plan_version = e.plan_version
where coalesce(a.actual_rows, 0) is distinct from e.expected_rows
