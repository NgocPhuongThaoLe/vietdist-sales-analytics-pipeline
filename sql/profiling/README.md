# Profiling SQL

Read-only checks on the `raw` schema. Each script proves one finding in [`docs/data_issues.md`](../../docs/data_issues.md) and later becomes a dbt test in Silver.

Run any script from the project root (Postgres must be up and the raw tables loaded):

```bash
docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/grain_src01.sql
```

| Script | Issue | Pass condition | Result (2026-11-27) |
|---|---|---|---|
| `grain_src01.sql` | DQ01 grain SRC01 | `duplicate_rows = 0`, `null_key_rows = 0` | pass |
| `grain_src05.sql` | DQ02 grain SRC05 | `duplicate_rows = 0`, `null_key_rows = 0` | pass |
| `fk_distributor_supervisor.sql` | DQ06 distributor → supervisor | `orphan_distributors = 0` | pass |
| `fk_return_sales_line.sql` | DQ07 return → sales line | `no_matching_line = 0` | pass |
| `data_period.sql` | DQ19 date range | `bad_format = 0`; read `max_date` | `dim_date` must reach 2025-01-02 |
| `dq08_resign_rule.sql` | DQ08 sales after resign date | read the counts; chosen rule is `order_date > resign_date` (see `docs/assumptions_log.md` A-DQ08) | 547 lines flagged (2026-11-28); 1-July rule = 0 |

Still to write (rows marked TBD in `docs/data_issues.md`):

| Script | Issue |
|---|---|
| `off_territory_sales.sql` | DQ09 |
| `territory_vs_transfers.sql` | DQ11 |
| `derived_columns_src01.sql` | DQ14 |
| `order_header_consistency.sql` | DQ15 |
| `returns_on_undelivered.sql` | DQ16 |
| `target_overlap.sql` | DQ18 |
