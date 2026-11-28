-- stg_territory_mapping: one row per mapped customer (SRC08_territory_mapping.xlsx, Sheet1)
-- PK customer_id: only one version (v1, 2024-01-01 to 9999-12-31). Expected 1,843 rows =
-- 2,000 customers - 157 unmapped (DQ10; the 157 unmapped are the 157 Inactive customers).
--
-- STALE MAPPING: SRC08 was never updated after the 8 resignations and the 5 July region transfers.
--   DQ09: all 4,192 off-territory sales lines are to customers still mapped to a resigned rep.
--   DQ11: all 85 rows of the 5 transferred reps still show their old region.
--   A-DQ09 (decided): a mapping ends at the mapped rep's resign date; Gold applies it. Staging only
--   passes the mapping through; it does not re-assign customers.
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src08_territory_mapping') }}

),

renamed as (

    select
        -- ids: trim + NFC + upper-case (DQ09, DQ10)
        {{ clean_code('customer_id') }}                 as customer_id,
        {{ clean_code('territory_id') }}                as territory_id,
        {{ clean_code('employee_id') }}                 as employee_id,

        -- DQ11: region/team of the mapped rep as of 2024-01-01 (not updated for July transfers)
        {{ clean_text('region') }}                      as region,
        {{ clean_text('team') }}                        as team,

        -- DQ19: raw dates are YYYY-MM-DD text. 9999-12-31 is kept as the open end of the validity
        -- range; it is never used as a dim_date key.
        {{ clean_text('effective_date') }}::date        as effective_date,
        {{ clean_text('expiry_date') }}::date           as expiry_date,
        {{ clean_text('expiry_date') }}::date = date '9999-12-31'
                                                        as is_open_ended,

        {{ clean_text('version') }}                     as version,

        -- lineage
        _source_file,
        _sheet_name,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
