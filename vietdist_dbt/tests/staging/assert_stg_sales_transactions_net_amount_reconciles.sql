-- DQ08 / DQ14 reconciliation: staging net revenue equals raw, 158,957,563,200 VND
-- (dq08_resign_rule.sql query 3). Flagging never drops rows.
-- Returns one row if the sum differs (0 rows = pass). Replaces sql/silver/tests/reconcile_net_amount.sql.
select
    sum(net_amount)                 as actual_net_vnd,
    158957563200::numeric(18,2)     as expected_net_vnd
from {{ ref('stg_sales_transactions') }}
having sum(net_amount) is distinct from 158957563200::numeric(18,2)
