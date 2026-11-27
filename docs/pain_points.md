# Pain points: one staging model in plain SQL

What it took to build and test `staging.stg_sales_transactions` without dbt ([`sql/silver/`](../sql/silver/)): 1 view, 13 test files, 2 home-made runners. Each point is something hit while doing it, or that is obvious once the other 9 staging models are added.

| # | Pain point | What happened / what it means |
|---|---|---|
| 1 | Manual run order | The view reads `raw.src07_employee_master` for `is_post_resign_sale`. Nothing records that, so with 10 models the build order (and the order of drops when a raw table changes) lives in someone's head. |
| 2 | No lineage | There is no graph of which staging view reads which raw table or which later model reads the view. Impact analysis ("what breaks if SRC07 changes?") means grepping SQL files. |
| 3 | Hard-coded schema and table names | `staging.` and `raw.` are typed into every file. A dev/prod split or a personal schema means find-and-replace, not a target setting. |
| 4 | Tests are loose files with a home-made runner | 13 `.sql` files plus `run_tests.sh` and `run_tests.ps1` that wrap each one in `select count(*)`. No severity (warn vs error), no "store failures", no selection by model, and the runners themselves need testing (a negative check was run by hand). |
| 5 | Generic tests are copy-paste | `pk_not_null`, `pk_unique`, three FK tests and three accepted-values tests are the same query with different names. Ten models will need about a hundred near-identical files. |
| 6 | Copy-paste for the other 9 models | The fake-null `CASE` is repeated for 15 columns in one model. There are no macros, so the same cleaning logic will be pasted into 9 more files and drift. |
| 7 | Expected values hard-coded in tests | 119,101 rows, 158,957,563,200 VND and 547 flags are literals in three files. When a new monthly file arrives, every number must be edited by hand. There are no variables. |
| 8 | No docs | Column meanings, the contract and the DQ references live only in SQL comments. There is no generated catalogue or lineage page to show a reviewer. |
| 9 | Environment-specific commands | Bash uses `< file`; Windows PowerShell 5.1 has no `<` and pipes text as ASCII, which turned `'Chuyển vùng'` into `?` and made a profiling script silently return 0 transfers (fixed with `$OutputEncoding`). Every runner exists twice. |
| 10 | No source freshness | Nothing warns when `_loaded_at` in raw is old. It would have to be another hand-written check. |
| 11 | No materialisation control | Changing the view to a table, or to incremental for SRC01, means rewriting DDL by hand (`create or replace view` cannot change column types or drop columns). |
