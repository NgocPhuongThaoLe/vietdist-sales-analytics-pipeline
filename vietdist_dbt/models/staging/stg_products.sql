-- stg_products: one row per product (SRC04_product_master.xlsx, sheet Products)
-- PK product_id. Expected 100 rows (DQ04). The Category_Summary sheet is not loaded (report sheet).
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src04_product_master') }}

),

renamed as (

    select
        -- id: trim + NFC + upper-case so SRC01/SRC05/SRC09/SRC10 references match (DQ04, DQ17)
        {{ clean_code('product_id') }}                  as product_id,

        -- descriptive text: trim + NFC, Vietnamese values kept as delivered
        {{ clean_text('product_name') }}                as product_name,
        {{ clean_text('category') }}                    as category,
        {{ clean_text('sub_category') }}                as sub_category,
        {{ clean_text('unit') }}                        as unit,

        -- money: numeric(18,2), never float
        {{ clean_text('unit_price') }}::numeric(18,2)   as unit_price,
        {{ clean_text('cost_price') }}::numeric(18,2)   as cost_price,

        -- weight in grams: whole numbers in raw
        {{ clean_text('weight_gram') }}::integer        as weight_gram,

        {{ clean_text('status') }}                      as status,

        -- DQ19: raw dates are YYYY-MM-DD text (data_period.sql: bad_format = 0)
        {{ clean_text('launch_date') }}::date           as launch_date,

        -- lineage
        _source_file,
        _sheet_name,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
