-- DQ07: the return's employee_id equals the rep on its sales line (0 mismatches in raw, checked 2026-11-28).
-- Returns the failing returns (0 rows = pass).
select
    r.return_id,
    r.employee_id       as return_employee_id,
    s.employee_id       as sale_employee_id
from {{ ref('stg_returns') }} r
join {{ ref('stg_sales_transactions') }} s
  on s.order_id = r.original_order_id
 and s.product_id = r.product_id
where r.employee_id <> s.employee_id
