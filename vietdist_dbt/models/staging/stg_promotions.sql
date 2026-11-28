-- stg_promotions: one row per promotion (SRC10_promotion_program.xlsx, Sheet1)
-- PK promotion_id. Expected 40 rows.
-- applicable_products is dropped here: it is split into stg_promotion_products (DQ17).
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src10_promotion_program') }}

),

renamed as (

    select
        -- id: trim + NFC + upper-case (DQ17: referenced by stg_promotion_products)
        {{ clean_code('promotion_id') }}                    as promotion_id,

        -- descriptive text: trim + NFC, Vietnamese values kept as delivered
        {{ clean_text('promotion_name') }}                  as promotion_name,
        {{ clean_text('promotion_type') }}                  as promotion_type,
        -- 'All' = every channel / region
        {{ clean_text('target_channel') }}                  as target_channel,
        {{ clean_text('target_region') }}                   as target_region,

        -- DQ19: raw dates are YYYY-MM-DD text (data_period.sql: bad_format = 0)
        {{ clean_text('start_date') }}::date                as start_date,
        {{ clean_text('end_date') }}::date                  as end_date,

        -- percentage numeric(5,2) (whole percent, 8 = 8 %); quantity integer; money numeric(18,2)
        {{ clean_text('discount_pct') }}::numeric(5,2)      as discount_pct,
        {{ clean_text('min_order_quantity') }}::integer     as min_order_quantity,
        {{ clean_text('budget_vnd') }}::numeric(18,2)       as budget_vnd,
        {{ clean_text('actual_cost_vnd') }}::numeric(18,2)  as actual_cost_vnd,

        {{ clean_text('status') }}                          as status,

        -- person name in Vietnamese (40 different names), not an employee id: no relationship test
        {{ clean_text('created_by') }}                      as created_by,

        -- lineage
        _source_file,
        _sheet_name,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
