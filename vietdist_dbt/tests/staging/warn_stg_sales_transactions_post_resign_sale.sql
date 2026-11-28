-- DQ08 / A-DQ08: sales lines after the employee's resign date (order_date > resign_date).
-- Documents a known issue: returns the flagged lines, WARN when there are exactly 547,
-- ERROR when the count differs from 547 (the rule or the data changed).
-- Replaces sql/silver/tests/post_resign_sale_count.sql.
{{ config(severity = 'error', error_if = '!= 547', warn_if = '!= 0') }}

select order_id, product_id, employee_id, order_date
from {{ ref('stg_sales_transactions') }}
where is_post_resign_sale
