-- stg_customers: one row per customer (SRC03_customer_master.csv)
-- PK customer_id. Expected 2,000 rows (DQ03, DQ10).
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src03_customer_master') }}

),

renamed as (

    select
        -- ids: trim + NFC + upper-case so joins from SRC01/SRC08 match (DQ03, DQ10)
        {{ clean_code('customer_id') }}                 as customer_id,

        -- descriptive text: trim + NFC, Vietnamese values kept as delivered
        {{ clean_text('customer_name') }}               as customer_name,
        {{ clean_text('customer_type') }}               as customer_type,
        {{ clean_text('channel') }}                     as channel,
        {{ clean_text('province') }}                    as province,
        {{ clean_text('region') }}                      as region,
        {{ clean_text('address') }}                     as address,

        -- DQ12: kept as text. The leading zero is intact in raw because the loader reads every column
        -- as text (dtype=str); the lost zero in DQ12 came from the notebook's default pandas int read.
        -- No fix in code; an error-level pattern test guards the format.
        {{ clean_text('phone') }}                       as phone,

        -- DQ13: kept as text, NULL stays NULL (1,035 NULL). Raw has no '.0' (read as text), so no fix
        -- in code; an error-level pattern test guards the format.
        {{ clean_text('tax_code') }}                    as tax_code,

        -- DQ19: raw dates are YYYY-MM-DD text (data_period.sql: bad_format = 0)
        {{ clean_text('join_date') }}::date             as join_date,

        -- money: numeric(18,2), never float
        {{ clean_text('credit_limit') }}::numeric(18,2) as credit_limit,

        -- DQ10: the 157 'Inactive' customers are exactly the 157 without a territory mapping
        {{ clean_text('status') }}                      as status,

        -- lineage (CSV source: _sheet_name is always NULL, so it is not carried)
        _source_file,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
