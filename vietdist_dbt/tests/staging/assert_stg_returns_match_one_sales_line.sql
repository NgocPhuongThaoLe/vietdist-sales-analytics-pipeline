-- DQ07: every return matches exactly one sales line (original_order_id + product_id -> order_id + product_id).
-- Returns the returns with 0 or more than 1 matching line (0 rows = pass).
select
    r.return_id,
    r.original_order_id,
    r.product_id,
    count(s.order_id)   as matching_lines
from {{ ref('stg_returns') }} r
left join {{ ref('stg_sales_transactions') }} s
       on s.order_id = r.original_order_id
      and s.product_id = r.product_id
group by r.return_id, r.original_order_id, r.product_id
having count(s.order_id) <> 1
