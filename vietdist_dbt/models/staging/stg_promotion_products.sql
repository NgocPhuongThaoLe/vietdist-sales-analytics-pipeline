-- stg_promotion_products: one row per promotion x product (bridge source for bridge_promotion_product)
-- DQ17: SRC10 applicable_products holds several product ids separated by '|'. Split and trim each id.
-- Expected 145 rows (promotion_products.sql: bridge_rows = 145, 0 empty parts, 0 duplicates, 0 orphans).
-- Reads the raw source because stg_promotions drops applicable_products.
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src10_promotion_program') }}

),

split as (

    -- DQ17: one row per product id in the '|'-separated list
    select
        s.promotion_id,
        x.product_id,
        x.position_in_list,
        s._source_file,
        s._sheet_name,
        s._row_number,
        s._batch_id,
        s._loaded_at
    from source s
    cross join lateral unnest(string_to_array(s.applicable_products, '|'))
        with ordinality as x(product_id, position_in_list)

),

renamed as (

    select
        -- ids: trim + NFC + upper-case so they match stg_promotions / stg_products (DQ17)
        {{ clean_code('promotion_id') }}        as promotion_id,
        {{ clean_code('product_id') }}          as product_id,
        position_in_list::integer               as position_in_list,

        -- lineage (one source row produces several bridge rows)
        _source_file,
        _sheet_name,
        _row_number,
        _batch_id,
        _loaded_at

    from split

)

select * from renamed
