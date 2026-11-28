-- stg_employees: one row per employee per version (SRC07_employee_master.xlsx)
--   v1 = sheet Employee_v1_StartYear (state on 2024-01-01)
--   v2 = sheet Employee_v2_Adjustment (state on 2024-07-01: 8 resigned, 5 transferred)
-- PK employee_id + employee_version. Expected 114 rows per version, 228 total (DQ05).
-- Both versions are kept: dim_employee (SCD2, week 3) is built from them plus stg_employee_changes.
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src07_employee_master') }}

),

renamed as (

    select
        -- id: trim + NFC + upper-case so SRC01/SRC02/SRC06/SRC08 references match (DQ05, DQ06)
        {{ clean_code('employee_id') }}                 as employee_id,

        -- version key from the sheet name; the raw `version` column is kept and tested to agree
        case _sheet_name
            when 'Employee_v1_StartYear'  then 'v1'
            when 'Employee_v2_Adjustment' then 'v2'
        end                                             as employee_version,
        {{ clean_text('version') }}                     as source_version,

        -- descriptive text: trim + NFC, Vietnamese values kept as delivered
        {{ clean_text('full_name') }}                   as full_name,
        {{ clean_text('gender') }}                      as gender,
        {{ clean_text('position') }}                    as position,
        {{ clean_text('region') }}                      as region,
        {{ clean_text('team') }}                        as team,
        {{ clean_text('email') }}                       as email,

        -- DQ12: kept as text. The leading zero is intact in raw (10 digits, starts with 0) because the
        -- loader reads text (dtype=str); the lost zero came from the notebook's default pandas int read.
        -- No fix in code; an error-level pattern test guards the format.
        {{ clean_text('phone') }}                       as phone,

        {{ clean_text('status') }}                      as status,

        -- DQ19: raw dates are YYYY-MM-DD text (data_period.sql: bad_format = 0)
        {{ clean_text('date_of_birth') }}::date         as date_of_birth,
        {{ clean_text('join_date') }}::date             as join_date,
        {{ clean_text('effective_date') }}::date        as effective_date,

        -- DQ08 / A-DQ08: resign_date is the true end of employment (filled for the 8 resigned
        -- employees in v2 only; empty in v1, arrives as NULL from raw). Tested, not fixed.
        {{ clean_text('resign_date') }}::date           as resign_date,

        -- DQ11: free-text note on the 5 July region transfers (v2 only, NULL in v1)
        {{ clean_text('transfer_note') }}               as transfer_note,

        -- lineage
        _source_file,
        _sheet_name,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
