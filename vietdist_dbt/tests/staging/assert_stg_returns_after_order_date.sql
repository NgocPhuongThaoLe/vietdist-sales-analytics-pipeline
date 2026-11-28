-- DQ16: a return is never dated before its sales line's order_date
-- (returns_on_undelivered.sql: return_before_order = 0).
-- Returns the failing returns (0 rows = pass).
select
    r.return_id,
    r.return_date,
    s.order_date
from {{ ref('stg_returns') }} r
join {{ ref('stg_sales_transactions') }} s
  on s.order_id = r.original_order_id
 and s.product_id = r.product_id
where r.return_date < s.order_date
