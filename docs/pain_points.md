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

## After dbt (v0.2.5)

The same work in dbt: 11 staging models in `vietdist_dbt/models/staging/`, including `stg_sales_transactions` migrated from `sql/silver/`. `dbt build` runs 11 models and 149 tests (146 pass, 3 warn, 0 error).

| # | Pain point | What dbt changed in this repo |
|---|---|---|
| 1 | Manual run order | `ref()` builds the graph: `stg_sales_transactions` waits for `stg_employees` (post-resign flag), and the return tests wait for both. One command, `dbt build`, runs 11 models and their tests in order. |
| 2 | No lineage | `dbt docs generate` writes the lineage graph (11 sources → 11 models) and a catalogue; impact analysis is `dbt ls -s source:raw.src07_employee_master+`. |
| 3 | Hard-coded schema and table names | The 11 raw tables are declared once in `_sources.yml` and read with `source('raw', ...)`; the target schema comes from the profile. |
| 4 | Loose test files and a home-made runner | `stg_sales_transactions`: 13 SQL files (83 lines) + 2 runners (72 lines) → 58 YAML test lines + 2 singular tests (17 lines), run by `dbt build`. Severity is per test (`warn`, or `warn_if` / `error_if` for counts that must stay exact). |
| 5 | Generic tests are copy-paste | `unique`, `not_null`, `relationships` and `accepted_values` are one YAML entry each: 149 tests come from one YAML file, 14 singular tests and 1 generic test (`row_count_equals`). |
| 6 | Copy-paste cleaning for every model | Macros `clean_text` and `clean_code`, called 127 times across 11 models. `stg_sales_transactions` shrank from 215 to 104 lines. |
| 7 | Expected values hard-coded in tests | Not solved yet: counts are still literals in YAML (`row_count_equals: expected`) and in `error_if` configs, now in one place per model. `vars` could move them out. |
| 8 | No docs | Every model and every column has a one-line description in `_stg_models.yml`; `dbt docs generate` builds the site. |
| 9 | Environment-specific commands | `dbt build` is the same on Windows and macOS/Linux; only `.env` loading still has two scripts. dbt sends UTF-8 through psycopg2, so Vietnamese accepted values pass without the PowerShell encoding fix. |
| 10 | No source freshness | `loaded_at_field: _loaded_at` is set for the source, so `dbt source freshness` can run once thresholds are added (none yet). |
| 11 | No materialisation control | `+materialized: view` for staging in `dbt_project.yml`; switching a model to a table or incremental is a config change, and dbt handles the DDL. |

