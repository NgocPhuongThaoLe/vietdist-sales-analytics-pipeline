# Profiling SQL

Read-only checks on the `raw` schema. Each script proves one finding in [`docs/data_issues.md`](../../docs/data_issues.md) and later becomes a dbt test in Silver.

Run any script from the project root (Postgres must be up and the raw tables loaded):

```bash
docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/grain_src01.sql
```

| Script | Issue | Pass condition | Result |
|---|---|---|---|
| `grain_src01.sql` | DQ01 grain SRC01 | `duplicate_rows = 0`, `null_key_rows = 0` | pass (2026-11-27) |
| `grain_src05.sql` | DQ02 grain SRC05 | `duplicate_rows = 0`, `null_key_rows = 0` | pass (2026-11-27) |
| `fk_distributor_supervisor.sql` | DQ06 distributor → supervisor | `orphan_distributors = 0` | pass (2026-11-27) |
| `fk_return_sales_line.sql` | DQ07 return → sales line | `no_matching_line = 0` | pass (2026-11-27) |
| `data_period.sql` | DQ19 date range | `bad_format = 0`; read `max_date` | `dim_date` must reach 2025-01-02 (2026-11-27) |
| `dq08_resign_rule.sql` | DQ08 sales after resign date | read the counts; chosen rule is `order_date > resign_date` (see `docs/assumptions_log.md` A-DQ08) | 547 lines flagged; 1-July rule = 0 (2026-11-28) |
| `off_territory_sales.sql` | DQ09 off-territory sales | `duplicate_customer_ids = 0`; read the flag count | pass; 4,192 lines flagged, all H2, all mapped to the 8 resigned reps (2026-11-28) |
| `territory_vs_transfers.sql` | DQ11 SRC08 vs July transfers | read the counts | 5 transfers; 85 of 85 SRC08 rows still in the old region (2026-11-28) |
| `derived_columns_src01.sql` | DQ14 derived columns SRC01 | every `*_mismatch = 0`, `null_base_rows = 0` (amount tolerance 1 VND) | fail on `discount_amount_mismatch = 13971` only; all explained by half-to-even rounding to 100 VND (`rows_not_equal_half_even = 0`) (2026-11-28) |
| `denormalised_columns_match.sql` | DQ14 / DQ20 dropped region / category copies vs masters | every `*_mismatch = 0` | pass; SRC01 119,101 and SRC05 35,945 lines, 0 mismatches (2026-11-28) |
| `derived_columns_src05.sql` | DQ20 derived columns SRC05 | every `*_mismatch = 0`, `null_base_rows = 0` | fail on `ontime_delivery_mismatch = 177` only (early or on-time lines stored as `No`); all other columns match (2026-11-28) |
| `order_header_consistency.sql` | DQ15 order-level fields | read the counts; a column is order-level only if its count = 0 | 6 columns order-level; `delivery_status`, `payment_method`, `payment_status` line-level (2026-11-28) |
| `returns_on_undelivered.sql` | DQ16 returns on undelivered lines | `return_before_order = 0`; read `returns_on_undelivered` | pass; 0 returns on undelivered lines (2026-11-28) |
| `promotion_products.sql` | DQ17 promotion → products split | `orphan_product_ids = 0`, `empty_parts = 0`, `duplicate_pairs = 0` | pass; 145 bridge rows (2026-11-28) |
| `phone_tax_code_format.sql` | DQ12 / DQ13 phone and tax_code format in raw | `starts_with_0 = non_null` for phone; `dot_zero = 0`, `non_digit = 0` | pass; raw values correct, issue is read-time only (2026-11-28) |
| `unmapped_customers.sql` | DQ10 unmapped vs inactive customers | read the counts | 157 unmapped = the 157 `Inactive` customers, 0 with sales (2026-11-28) |
| `target_versioning_checks.sql` | DQ18 / A-DQ18 / A-T01 target version logic (reads the dbt staging views) | every row `pass = true` (22 checks) | pass; 1,284 latest rows (2026-11-28) |
| `territory_flags_check.sql` | A-DQ09 territory flags (reads the dbt staging views) | `off_territory_lines = 0`, `unassigned_customer_lines = 4739`, `unassigned_sold_by_other_rep = 4192`, `unassigned_sold_by_mapped_rep = 547` | pass (2026-11-28) |
| `target_overlap.sql` | DQ18 target version overlap | `version_sheet_mismatch = 0`, `duplicate_keys = 0`, `v2_months_missing_in_v1 = 0`; v1 H2 rows without v2 = resigned employees | pass; 48 v1 H2 rows without v2, superseded by v2 (A-DQ18 decided) (2026-11-28) |

All results are from raw batch `cdaee7385083`. On Windows PowerShell, `<` does not work; pipe the file instead. Set UTF-8 first: Windows PowerShell 5.1 pipes text to native programs as ASCII, which turns Vietnamese literals such as `'Chuyển vùng'` into `?`, so `territory_vs_transfers.sql` would silently return 0 transfers:

```powershell
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
Get-Content -Encoding UTF8 sql/profiling/grain_src01.sql | docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```
