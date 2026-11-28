-- DQ02: SRC05 has 8,000 distinct distributor orders (grain_src05.sql: distinct_orders = 8000).
-- Returns one row if the number of orders differs (0 rows = pass).
select
    count(distinct order_id)    as actual_orders,
    8000                        as expected_orders
from {{ ref('stg_distributor_orders') }}
having count(distinct order_id) <> 8000
