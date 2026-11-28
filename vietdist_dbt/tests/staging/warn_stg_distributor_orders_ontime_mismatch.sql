-- DQ20: ontime_delivery disagrees with actual_delivery_date <= expected_delivery_date on 177 lines
-- (derived_columns_src05.sql). All are early or on-time deliveries stored as 'No'.
-- Documents a known issue: WARN at exactly 177 lines, ERROR if the count changes.
{{ config(severity = 'error', error_if = '!= 177', warn_if = '!= 0') }}

select
    order_id,
    product_id,
    expected_delivery_date,
    actual_delivery_date,
    ontime_delivery
from {{ ref('stg_distributor_orders') }}
where ontime_delivery <> case when actual_delivery_date <= expected_delivery_date then 'Yes' else 'No' end
