-- DQ07: the return's customer_id equals the customer on its sales line (0 mismatches in raw, checked 2026-11-28).
-- Returns the failing returns (0 rows = pass).
select
    r.return_id,
    r.customer_id       as return_customer_id,
    s.customer_id       as sale_customer_id
from {{ ref('stg_returns') }} r
join {{ ref('stg_sales_transactions') }} s
  on s.order_id = r.original_order_id
 and s.product_id = r.product_id
where r.customer_id <> s.customer_id
