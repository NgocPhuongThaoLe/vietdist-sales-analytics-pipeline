-- DQ13: SRC03 tax_code is NULL for exactly 1,035 of 2,000 customers (51.7%).
-- Returns one row if the NULL count changes (0 rows = pass).
select
    count(*) filter (where tax_code is null)    as actual_null_tax_code,
    1035                                        as expected_null_tax_code
from {{ ref('stg_customers') }}
having count(*) filter (where tax_code is null) <> 1035
