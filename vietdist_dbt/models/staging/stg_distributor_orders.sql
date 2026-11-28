-- stg_distributor_orders: one row per distributor order line (SRC05_distributor_orders.xlsx, sheet Orders)
-- PK order_id + product_id (DQ02: 0 duplicates, 0 null keys). Expected 35,945 rows, 8,000 orders.
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src05_distributor_orders') }}

),

renamed as (

    select
        -- keys: trim + NFC + upper-case (DQ02; FKs to stg_distributors and stg_products)
        {{ clean_code('order_id') }}                            as order_id,
        {{ clean_code('product_id') }}                          as product_id,
        {{ clean_code('distributor_id') }}                      as distributor_id,

        -- DQ19: raw dates are YYYY-MM-DD text; expected_delivery_date reaches 2025-01-02 (219 rows after 2024)
        {{ clean_text('order_date') }}::date                    as order_date,
        {{ clean_text('expected_delivery_date') }}::date        as expected_delivery_date,
        {{ clean_text('actual_delivery_date') }}::date          as actual_delivery_date,

        {{ clean_text('channel') }}                             as channel,

        -- quantities integer, money numeric(18,2), percentage numeric(5,2)
        {{ clean_text('qty_ordered') }}::integer                as qty_ordered,
        {{ clean_text('qty_delivered') }}::integer              as qty_delivered,
        {{ clean_text('unit_price_list') }}::numeric(18,2)      as unit_price_list,
        {{ clean_text('distributor_price') }}::numeric(18,2)    as distributor_price,

        -- DQ20: stored derived values are KEPT. fill_rate_pct, gross_amount and delivered_amount
        -- match their base columns (0 mismatches, tested). ontime_delivery differs from
        -- actual <= expected on 177 lines (warn test); it is not recomputed.
        {{ clean_text('fill_rate_pct') }}::numeric(5,2)         as fill_rate_pct,
        {{ clean_text('gross_amount') }}::numeric(18,2)         as gross_amount,
        {{ clean_text('delivered_amount') }}::numeric(18,2)     as delivered_amount,
        {{ clean_text('ontime_delivery') }}                     as ontime_delivery,

        {{ clean_text('delivery_status') }}                     as delivery_status,
        {{ clean_text('payment_terms') }}                       as payment_terms,

        -- DQ20: order_month / order_quarter (recomputable, 0 mismatches) and the dimension columns
        -- region / product_category are dropped; dim_date, dim_distributors, dim_products provide them.

        -- lineage
        _source_file,
        _sheet_name,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
