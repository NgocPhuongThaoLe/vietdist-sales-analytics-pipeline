-- stg_distributors: one row per distributor (SRC06_distributor_master.csv)
-- PK distributor_id. Expected 138 rows (DQ06).
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src06_distributor_master') }}

),

renamed as (

    select
        -- id: trim + NFC + upper-case so SRC05 references match
        {{ clean_code('distributor_id') }}              as distributor_id,

        -- descriptive text: trim + NFC, Vietnamese values kept as delivered
        {{ clean_text('distributor_name') }}            as distributor_name,
        {{ clean_text('tier') }}                        as tier,
        {{ clean_text('channel') }}                     as channel,
        {{ clean_text('province') }}                    as province,
        {{ clean_text('region') }}                      as region,
        {{ clean_text('contact_person') }}              as contact_person,

        -- DQ12: kept as text. The leading zero is intact in raw (11 digits, starts with 0) because the
        -- loader reads text (dtype=str); the lost zero came from the notebook's default pandas int read.
        -- No fix in code; an error-level pattern test guards the format.
        {{ clean_text('phone') }}                       as phone,
        {{ clean_text('email') }}                       as email,

        -- DQ13: kept as text, 0 NULL in SRC06. The notebook read it as int64; raw is text and correct,
        -- so no fix in code; not_null and an error-level pattern test guard it.
        {{ clean_text('tax_code') }}                    as tax_code,

        -- DQ19: raw dates are YYYY-MM-DD text (data_period.sql: bad_format = 0)
        {{ clean_text('join_date') }}::date             as join_date,

        -- money: numeric(18,2), never float
        {{ clean_text('credit_limit') }}::numeric(18,2) as credit_limit,

        {{ clean_text('status') }}                      as status,

        -- DQ06: renamed to say what it is; all 9 supervisors exist in SRC07 (fk_distributor_supervisor.sql)
        {{ clean_code('assigned_supervisor_id') }}      as supervisor_employee_id,

        -- lineage (CSV source: _sheet_name is always NULL, so it is not carried)
        _source_file,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
