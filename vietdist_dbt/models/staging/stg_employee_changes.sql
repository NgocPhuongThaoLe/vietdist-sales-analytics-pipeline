-- stg_employee_changes: one row per HR change (SRC07_employee_master.xlsx, sheet Change_Log)
-- Expected 13 rows: 8 'Nghỉ việc' (resigned) + 5 'Chuyển vùng' (region transfer) (DQ08, DQ11).
-- effective_date (2024-07-01 on every row) is the date HR recorded the change in a batch update,
-- NOT the resign date: resignations use stg_employees.resign_date (A-DQ08). For transfers it is the
-- change date used by dim_employee SCD2.
-- No PK: an employee could have more than one change; today each has one.
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src07_employee_change_log') }}

),

renamed as (

    select
        -- id: trim + NFC + upper-case, references stg_employees (DQ05)
        {{ clean_code('employee_id') }}                 as employee_id,
        {{ clean_text('employee_name') }}               as employee_name,

        -- 'Nghỉ việc' = resigned, 'Chuyển vùng' = region transfer (Vietnamese values kept)
        {{ clean_text('change_type') }}                 as change_type,

        -- A-DQ08: HR recording date, not the resign date (DQ19: YYYY-MM-DD text)
        {{ clean_text('effective_date') }}::date        as effective_date,

        -- DQ11: new_region / new_team are NULL for resignations, filled for the 5 transfers
        {{ clean_text('old_region') }}                  as old_region,
        {{ clean_text('new_region') }}                  as new_region,
        {{ clean_text('old_team') }}                    as old_team,
        {{ clean_text('new_team') }}                    as new_team,

        -- lineage
        _source_file,
        _sheet_name,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
