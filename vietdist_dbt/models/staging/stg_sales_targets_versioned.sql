-- stg_sales_targets_versioned: stg_sales_targets + version logic (guide Task 2.3, rule A-DQ18 option a)
-- One row per employee x month x plan version (1,950 rows, nothing dropped), plus:
--   is_latest              true for the row of the latest version covering that month
--   superseded_by_version  the next version that covers the month of a non-latest row (NULL if none)
--   valid_from / valid_to  when this version row was the plan of record
--
-- Approach (data-driven, no hard-coded month numbers, so a v3 works without code changes):
--   1. versions: one row per plan version with version_date and the period it covers
--      (effective_from .. effective_to): v1 2024-01-01..2024-12-31 issued 2024-01-05,
--      v2 2024-07-01..2024-12-31 issued 2024-07-03.
--   2. For every target row, the covering versions are those whose period contains target_month.
--   3. latest = the covering version with the newest version_date. A version re-plans its WHOLE
--      period, so a v1 row is superseded even when the employee has no row in v2 (A-DQ18 option a:
--      the 48 v1 H2 rows of the 8 resigned employees are superseded; latest rows = 1,284).
--   4. superseded_by_version = the covering version issued next after this row's version.
--   5. valid_from = version_date (the date the plan was issued; a plan cannot be valid before it
--      exists, so an as-of query on 2024-07-02 returns v1). effective_from is kept in
--      stg_sales_targets as the period the plan covers. valid_to = the day before the superseding
--      version's version_date, or 9999-12-31 while the row is still the latest (DQ19 open end).
-- Result for this data: months 1-6 -> v1 latest; months 7-12 -> v2 latest, every v1 row false.
-- Materialized as a view (dbt_project.yml: staging = view).

with targets as (

    select * from {{ ref('stg_sales_targets') }}

),

-- 1. one row per plan version: issue date and covered period
versions as (

    select
        plan_version,
        min(version_date)       as version_date,
        min(effective_from)     as effective_from,
        max(effective_to)       as effective_to
    from targets
    group by plan_version

),

-- 2. every version that covers each target row's month, ranked by issue date
covering as (

    select
        t.employee_id,
        t.plan_version,
        t.target_month,
        t.version_date                                          as row_version_date,
        v.plan_version                                          as covering_version,
        v.version_date                                          as covering_version_date,
        row_number() over (
            partition by t.employee_id, t.plan_version, t.target_month
            order by v.version_date desc
        )                                                       as newest_rank
    from targets t
    join versions v
      on t.target_month between v.effective_from and v.effective_to

),

-- 3. latest covering version per target row (A-DQ18)
latest as (

    select employee_id, plan_version, target_month, covering_version as latest_version
    from covering
    where newest_rank = 1

),

-- 4. next covering version issued after the row's own version
next_version as (

    select distinct on (employee_id, plan_version, target_month)
        employee_id,
        plan_version,
        target_month,
        covering_version        as superseded_by_version,
        covering_version_date   as superseded_on
    from covering
    where covering_version_date > row_version_date
    order by employee_id, plan_version, target_month, covering_version_date

),

final as (

    select
        t.employee_id,
        t.plan_version,
        t.year,
        t.month,
        t.target_month,
        t.version_date,
        t.effective_from,
        t.effective_to,
        t.plan_region,
        t.plan_team,
        t.target_revenue,
        t.target_quantity,
        t.target_new_customers,

        -- A-DQ18: true only for the latest version covering the month
        (t.plan_version = l.latest_version)                     as is_latest,
        n.superseded_by_version,

        -- 5. validity of this version row (version_date based)
        t.version_date                                          as valid_from,
        coalesce(n.superseded_on - 1, date '9999-12-31')        as valid_to,

        -- lineage
        t._source_file,
        t._sheet_name,
        t._row_number,
        t._batch_id,
        t._loaded_at

    from targets t
    join latest l
      on l.employee_id = t.employee_id
     and l.plan_version = t.plan_version
     and l.target_month = t.target_month
    left join next_version n
      on n.employee_id = t.employee_id
     and n.plan_version = t.plan_version
     and n.target_month = t.target_month

)

select * from final
