-- DQ16: every return is on a sales line whose delivery_status is 'Delivered'
-- (returns_on_undelivered.sql: returns_on_undelivered = 0). Replaces an is_return_on_undelivered flag.
-- Returns the failing returns (0 rows = pass).
select
    r.return_id,
    s.order_id,
    s.product_id,
    s.delivery_status
from {{ ref('stg_returns') }} r
join {{ ref('stg_sales_transactions') }} s
  on s.order_id = r.original_order_id
 and s.product_id = r.product_id
where s.delivery_status <> 'Delivered'
