-- DQ15: order_date, customer_id, employee_id, channel and province never vary between the lines of one
-- order (order_header_consistency.sql: 0 orders each), so they can form an order header in Gold.
-- delivery_status, payment_method and payment_status are line-level and are NOT checked here.
-- Returns the orders where an order-level field has more than one value (0 rows = pass).
select
    order_id,
    count(distinct order_date)      as order_dates,
    count(distinct customer_id)     as customers,
    count(distinct employee_id)     as employees,
    count(distinct channel)         as channels,
    count(distinct province)        as provinces
from {{ ref('stg_sales_transactions') }}
group by order_id
having count(distinct order_date)  > 1
    or count(distinct customer_id) > 1
    or count(distinct employee_id) > 1
    or count(distinct channel)     > 1
    or count(distinct province)    > 1
