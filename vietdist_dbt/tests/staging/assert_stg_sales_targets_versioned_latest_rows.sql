-- A-DQ18 option (a): latest rows = v1 months 1-6 (666) + all of v2 (618) = 1,284.
-- Returns one row if the count differs (0 rows = pass).
select
    count(*) filter (where is_latest)   as actual_latest_rows,
    1284                                as expected_latest_rows
from {{ ref('stg_sales_targets_versioned') }}
having count(*) filter (where is_latest) <> 1284
