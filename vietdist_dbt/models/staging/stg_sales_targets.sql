-- stg_sales_targets: one row per raw target row = employee x year x month x plan version
-- (SRC02_sales_target_plan.xlsx; sheets Plan_v1_Original and Plan_v2_Adjustment_H2; the Summary sheet is not loaded).
-- Expected 1,950 rows: v1 1,332 (111 employees x 12 months) + v2 618 (103 employees x months 7-12) (DQ18).
-- Both versions are kept as they are; which row is the latest is decided in stg_sales_targets_versioned (A-DQ18).
-- Materialized as a view (dbt_project.yml: staging = view).

with source as (

    select * from {{ source('raw', 'src02_sales_target') }}

),

renamed as (

    select
        -- id: trim + NFC + upper-case, references stg_employees (DQ05)
        {{ clean_code('employee_id') }}                         as employee_id,

        -- DQ18: version key from the sheet name; the raw plan_version column is kept and tested to agree
        -- (target_overlap.sql: version_sheet_mismatch = 0)
        case _sheet_name
            when 'Plan_v1_Original'      then 'v1'
            when 'Plan_v2_Adjustment_H2' then 'v2'
        end                                                     as plan_version,
        {{ clean_text('plan_version') }}                        as source_plan_version,

        -- DQ19: raw dates are YYYY-MM-DD text (data_period.sql: bad_format = 0)
        {{ clean_text('version_date') }}::date                  as version_date,
        {{ clean_text('effective_from') }}::date                as effective_from,
        {{ clean_text('effective_to') }}::date                  as effective_to,

        -- target period: year / month integer; target_month = first day of the month (joins dim_date in Gold)
        {{ clean_text('year') }}::integer                       as year,
        {{ clean_text('month') }}::integer                      as month,
        make_date({{ clean_text('year') }}::integer,
                  {{ clean_text('month') }}::integer, 1)        as target_month,

        -- region / team the target was set for; equal to stg_employees of the same version on every row
        -- (0 mismatches, tested). employee_name is dropped: stg_employees provides it.
        {{ clean_text('region') }}                              as plan_region,
        {{ clean_text('team') }}                                as plan_team,

        -- money numeric(18,2), counts integer
        {{ clean_text('target_revenue') }}::numeric(18,2)       as target_revenue,
        {{ clean_text('target_quantity') }}::integer            as target_quantity,
        {{ clean_text('target_new_customers') }}::integer       as target_new_customers,

        -- lineage
        _source_file,
        _sheet_name,
        _row_number,
        _batch_id,
        _loaded_at

    from source

)

select * from renamed
