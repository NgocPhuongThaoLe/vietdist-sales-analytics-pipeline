# sql/silver – plain-SQL baseline (superseded)

Superseded by the dbt model [`vietdist_dbt/models/staging/stg_sales_transactions.sql`](../../vietdist_dbt/models/staging/stg_sales_transactions.sql) and its tests in `_stg_models.yml` (v0.2.5).
Kept only to compare "before dbt" with "after dbt" (see [`docs/pain_points.md`](../../docs/pain_points.md)).
Do not run `stg_sales_transactions.sql` or `run_tests.sh` / `run_tests.ps1`: they `create or replace` the view `staging.stg_sales_transactions` and would overwrite the dbt-built view.
