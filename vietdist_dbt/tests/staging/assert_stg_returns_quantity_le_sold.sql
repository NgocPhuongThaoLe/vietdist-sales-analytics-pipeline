-- DQ07: a return never exceeds the quantity sold on its sales line
-- (fk_return_sales_line.sql: returned_more_than_sold = 0).
-- Returns the failing returns (0 rows = pass).
select
    r.return_id,
    r.return_quantity,
    s.quantity          as sold_quantity
from {{ ref('stg_returns') }} r
join {{ ref('stg_sales_transactions') }} s
  on s.order_id = r.original_order_id
 and s.product_id = r.product_id
where r.return_quantity > s.quantity
