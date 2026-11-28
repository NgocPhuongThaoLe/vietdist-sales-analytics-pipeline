-- stg_returns: one row per returned sales line (SRC09_return_transactions.csv)
-- PK return_id. Expected 3,665 rows. Each return points to one SRC01 line via
-- original_order_id + product_id (DQ07: 0 orphans, 0 returned more than sold).
-- DQ16: every return is on a 'Delivered' line (0 on undelivered lines), so there is no
-- is_return_on_undelivered flag; a singular test guards it instead.
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src09_return_transactions') }}

),

renamed as (

    select
        -- keys: trim + NFC + upper-case (DQ07: original_order_id + product_id -> stg_sales_transactions)
        {{ clean_code('return_id') }}                       as return_id,
        {{ clean_code('original_order_id') }}               as original_order_id,
        {{ clean_code('product_id') }}                      as product_id,
        {{ clean_code('customer_id') }}                     as customer_id,
        {{ clean_code('employee_id') }}                     as employee_id,

        -- DQ19: raw dates are YYYY-MM-DD text (data_period.sql: bad_format = 0)
        {{ clean_text('return_date') }}::date               as return_date,

        -- quantity integer, money numeric(18,2); return_amount = return_quantity * unit_price on every row (tested)
        {{ clean_text('return_quantity') }}::integer        as return_quantity,
        {{ clean_text('unit_price') }}::numeric(18,2)       as unit_price,
        {{ clean_text('return_amount') }}::numeric(18,2)    as return_amount,

        -- Vietnamese values kept as delivered
        {{ clean_text('return_reason') }}                   as return_reason,
        {{ clean_text('status') }}                          as status,

        -- return_month (recomputable from return_date) and the dimension columns region / province
        -- are dropped; dim_date and dim_customers provide them.

        -- lineage (CSV source: _sheet_name is always NULL, so it is not carried)
        _source_file,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
