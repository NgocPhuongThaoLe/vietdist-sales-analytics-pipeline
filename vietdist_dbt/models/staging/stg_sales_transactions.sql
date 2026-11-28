-- stg_sales_transactions: one row per sales order line (SRC01_sales_transactions.csv)
-- Migrated from sql/silver/stg_sales_transactions.sql (plain SQL, v0.2.3).
-- PK order_id + product_id (DQ01: 0 duplicates, 0 null keys). Expected 119,101 rows and
-- sum(net_amount) = 158,957,563,200 VND (= raw; nothing is dropped). Both are tested.
-- No dedup step: DQ01 has 0 duplicates, so the PK-unique test guards the grain instead.
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src01_sales_transactions') }}

),

renamed as (

    select
        -- keys: trim + NFC + upper-case (DQ01; FKs DQ03, DQ04, DQ05)
        {{ clean_code('order_id') }}                        as order_id,
        {{ clean_code('product_id') }}                      as product_id,

        -- DQ19: raw dates are YYYY-MM-DD text (data_period.sql: bad_format = 0)
        {{ clean_text('order_date') }}::date                as order_date,

        {{ clean_code('customer_id') }}                     as customer_id,
        {{ clean_code('employee_id') }}                     as employee_id,

        -- DQ15: order-level fields (0 orders with more than one value)
        {{ clean_text('channel') }}                         as channel,
        {{ clean_text('province') }}                        as province,

        -- quantities integer, money numeric(18,2), percentage numeric(5,2) (DQ14: never float)
        {{ clean_text('quantity') }}::integer               as quantity,
        {{ clean_text('unit_price') }}::numeric(18,2)       as unit_price,
        -- DQ14: discount_pct is a whole percent (2 = 2 %)
        {{ clean_text('discount_pct') }}::numeric(5,2)      as discount_pct,

        -- DQ14: stored amounts are KEPT as booked. gross = qty * price on every row; the stored
        -- discount is the exact discount rounded half-to-even to 100 VND (13,971 rows differ by up
        -- to 50 VND); net = gross - discount on every row and reconciles to raw. Tested, not recomputed.
        {{ clean_text('gross_amount') }}::numeric(18,2)     as gross_amount,
        {{ clean_text('discount_amount') }}::numeric(18,2)  as discount_amount,
        {{ clean_text('net_amount') }}::numeric(18,2)       as net_amount,

        -- DQ15 / DQ16: line-level fields, they may differ between lines of one order
        {{ clean_text('delivery_status') }}                 as delivery_status,
        {{ clean_text('payment_method') }}                  as payment_method,
        {{ clean_text('payment_status') }}                  as payment_status,

        -- DQ14: order_month / order_quarter / order_year (recomputable from order_date) and the
        -- dimension columns region / product_category are dropped; dim_date, dim_customers and
        -- dim_products provide them.

        -- lineage (CSV source: _sheet_name is always NULL, so it is not carried)
        _source_file,
        _row_number,
        _batch_id,
        _loaded_at

    from source

),

-- A-DQ08: resign_date from stg_employees v2 is the true end of employment
resigned as (

    select employee_id, resign_date
    from {{ ref('stg_employees') }}
    where employee_version = 'v2'
      and resign_date is not null

),

final as (

    select
        s.order_id,
        s.product_id,
        s.order_date,
        s.customer_id,
        s.employee_id,
        s.channel,
        s.province,
        s.quantity,
        s.unit_price,
        s.discount_pct,
        s.gross_amount,
        s.discount_amount,
        s.net_amount,
        s.delivery_status,
        s.payment_method,
        s.payment_status,
        -- DQ08 / A-DQ08: order_date > resign_date (the resign day counts as worked).
        -- Flag, never drop (left join); expected 547 lines.
        coalesce(s.order_date > r.resign_date, false)       as is_post_resign_sale,
        s._source_file,
        s._row_number,
        s._batch_id,
        s._loaded_at
    from renamed s
    left join resigned r on r.employee_id = s.employee_id

)

select * from final
