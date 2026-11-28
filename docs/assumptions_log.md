# Assumptions Log

Business rules chosen where the source data allows more than one reading. Each entry states the decision, why it was made, the evidence, and where it is applied. Counts come from the scripts in [`sql/profiling/`](../sql/profiling/); related issues are in [`data_issues.md`](data_issues.md).

| ID | Assumption | Status | Decided |
|---|---|---|---|
| A-DQ08 | Resign date rule | Decided | 2026-11-28 |
| A-DQ09 | Territory: mapping ends at the mapped rep's resign date; credit the selling rep | Decided | 2026-11-28 |
| A-DQ18 | Sales target: v1 H2 rows of resigned employees are superseded by v2 (option a) | Decided | 2026-11-28 |
| A-T01 | Only v1 and v2 in the sample; the version logic handles further versions | Decided | 2026-11-28 |

---

## A-DQ08 – Resign date rule

**Issue:** [DQ08](data_issues.md) – sales recorded for employees after they resigned.

**Decision**
- `resign_date` (SRC07 `Employee_v2_Adjustment`) is the true end of employment.
- `Change_Log.effective_date` (2024-07-01 for every row) is the date HR recorded the change in a batch update. It is not the resign date.
- Rule: `is_post_resign_sale = order_date > resign_date`. The resign day itself counts as worked.
- Sales are **flagged, never dropped**. Total net revenue must still reconcile to raw.
- SCD2 (`dim_employee`, week 3): resigned employees get `valid_to = resign_date`; transferred employees use `Change_Log.effective_date` as the change date.

**Evidence** (`sql/profiling/dq08_resign_rule.sql`, run 2026-11-28 on raw batch `cdaee7385083`)

| Measure | Chosen rule: `order_date > resign_date` | Rejected rule: `order_date >= 2024-07-01` |
|---|---|---|
| Sales lines flagged | 547 | 0 |
| Net amount flagged (VND) | 736,436,300 | 0 |

- 8 resigned employees, 4,336 sales lines in total. Their resign dates fall between 2024-05-24 and 2024-06-18; the latest sale of any of them is 2024-06-30. The 1-July rule would therefore flag nothing and hide the issue.
- Per employee (chosen rule):

| Employee | resign_date | Sales lines | Flagged lines |
|---|---|---|---|
| EMP1035 | 2024-06-03 | 966 | 161 |
| EMP1046 | 2024-06-10 | 781 | 79 |
| EMP1048 | 2024-06-18 | 572 | 45 |
| EMP1051 | 2024-06-18 | 1,184 | 108 |
| EMP1054 | 2024-05-24 | 125 | 37 |
| EMP1070 | 2024-06-01 | 476 | 62 |
| EMP1075 | 2024-06-09 | 142 | 33 |
| EMP1100 | 2024-05-29 | 90 | 22 |
| **Total** | | **4,336** | **547** |

- Reconciliation baseline: SRC01 has 119,101 lines and 158,957,563,200 VND net (about 159 bn). Flagging keeps all of them.

**Where it is applied**
- Silver: `is_post_resign_sale` on the sales staging model; warn-level test that the flagged count is 547; test that staging net revenue equals raw.
- Gold: `dim_employee` SCD2 validity dates as above; `fact_sales` carries the flag.

---

## A-DQ09 – Territory mapping ends at the resign date

**Issue:** [DQ09](data_issues.md) – sales by a rep who is not the customer's mapped rep; [DQ11](data_issues.md) – SRC08 not updated for the July transfers.

**Status:** Decided 2026-11-28. `stg_territory_mapping` passes SRC08 through unchanged; the rule is applied in Gold (`fact_sales`, `mart_sales_vs_target`).

**Decision**
- A territory mapping ends at the mapped rep's resign date. Revenue is credited to the **selling rep**.
- Crediting (Gold, `mart_sales_vs_target`): the selling rep (SRC01 `employee_id`) and that rep's SCD2 region on the order date, not the SRC08 territory, because SRC08 was never updated after the resignations and the July transfers (DQ09, DQ11).
- Two flags in Gold `fact_sales`:
  - `is_off_territory` = the mapping is active on the order date (the mapped rep never resigned, or `order_date <= ` the mapped rep's `resign_date`) **and** the mapped rep <> the selling rep. Expected **0**.
  - `is_unassigned_customer` = the customer's mapped rep resigned before the order date (`order_date > resign_date`), regardless of who sold. Expected **4,739** lines (6,361,734,300 VND).
- Breakdown: 4,739 = **4,192** sold by another rep (the DQ09 lines) + **547** sold by the resigned mapped rep himself (the DQ08 lines, which also carry `is_post_resign_sale`).
- The flags are independent: `is_unassigned_customer` describes the customer's state on the order date, `is_post_resign_sale` the seller's. The 547 overlap is real, not double counting.

**Check** (`sql/profiling/territory_flags_check.sql`, run 2026-11-28 on the staging views built from raw batch `cdaee7385083`)

| Measure | Expected | Actual |
|---|---|---|
| `off_territory_lines` | 0 | 0 |
| `unassigned_customer_lines` | 4,739 | 4,739 |
| `unassigned_customer_net_vnd` | – | 6,361,734,300 |
| `unassigned_sold_by_other_rep` (DQ09 lines) | 4,192 | 4,192 |
| `unassigned_sold_by_mapped_rep` (DQ08 lines) | 547 | 547 |
| `seller_differs_from_mapped_rep` (SRC08 as delivered) | – | 4,192 |

**Facts** (`sql/profiling/off_territory_sales.sql`, `sql/profiling/territory_vs_transfers.sql`, run 2026-11-28 on raw batch `cdaee7385083`; dbt test `warn_stg_territory_mapping_resigned_rep`)

- SRC08 has one version (v1, 2024-01-01 to 9999-12-31) and was never updated in 2024.
- 4,192 sales lines (5,625,298,000 VND) are sold by a rep other than the mapped rep, all in July–December.
- Every one of them is to a customer mapped to one of the 8 resigned employees, ordered from 2024-07-01 on. All resign dates fall between 2024-05-24 and 2024-06-18 (`data_period.sql`).
- 196 customers in SRC08 are mapped to a resigned rep (`warn_stg_territory_mapping_resigned_rep`).
- The 5 transferred reps are not a cause: 0 off-territory lines are mapped to them.

**Options considered** (before the decision)

| Option | Rule | Lines flagged `is_off_territory` |
|---|---|---|
| (a) SRC08 as delivered | Flag when the seller differs from the SRC08 rep | 4,192 |
| (b) Mapping ends at resign date | A customer whose mapped rep resigned before the order date has no valid mapping, so the line is not flagged (it could get its own flag, e.g. `is_orphaned_territory`) | 0 |

Option (b) was chosen, with the separate flag named `is_unassigned_customer`.

**Where it will be applied:** Gold `fact_sales` (`is_off_territory`, `is_unassigned_customer`) and `mart_sales_vs_target` (credit the selling rep, SCD2 region on the order date). Planned tests: `is_off_territory` count = 0 (error), `is_unassigned_customer` count = 4,739 (warn).

---

## A-DQ18 – Sales target: v1 H2 rows of resigned employees

**Issue:** [DQ18](data_issues.md) – target versions overlap for July–December.

**Status:** Decided 2026-11-28 – option (a).

**Decision**
- The 48 v1 H2 rows (months 7–12) of the 8 resigned employees are **superseded** by the v2 re-plan.
- Reason: v2 re-plans the whole H2 and re-assigned almost exactly their target to the other 103 reps (+10,742,200,000 VND vs 10,743,800,000 VND removed); keeping them would double-count about 10.7 bn VND of H2 target. All 8 resigned before July.
- Rule: months 1–6 → v1 `is_latest = true`; months 7–12 → v2 `is_latest = true`, all v1 rows `false` (including the 48). Expected latest rows = **1,284**.
- Dates (raw SRC02): v1 `version_date` 2024-01-05, `effective_from` 2024-01-01; v2 `version_date` 2024-07-03, `effective_from` 2024-07-01. `valid_from` / `valid_to` use `version_date` because they record when a plan was the plan of record (v2 did not exist before 2024-07-03, so v1 H2 rows are valid until 2024-07-02), while `effective_from` says which months a plan covers; `is_latest` answers "final target for the month", so July 1–2 sales are still measured against v2.

**Facts** (`sql/profiling/target_overlap.sql`, run 2026-11-28 on raw batch `cdaee7385083`)

| Measure | v1 (`Plan_v1_Original`) | v2 (`Plan_v2_Adjustment_H2`) |
|---|---|---|
| Rows | 1,332 | 618 |
| Employees | 111 | 103 |
| Rows months 1–6 | 666 | 0 |
| Rows months 7–12 | 666 | 618 |
| Target revenue months 7–12 (VND) | 139,999,600,000 | 139,998,000,000 |

- `plan_version` agrees with `_sheet_name` on every row (`version_sheet_mismatch = 0`); 0 duplicates on (`plan_version`, `employee_id`, `year`, `month`); every v2 employee-month also exists in v1 (`v2_months_missing_in_v1 = 0`).
- 618 v1 H2 rows are replaced by a v2 row. The other **48 v1 H2 rows** (6 months × 8 employees) have no v2 row. The 8 employees are exactly the resigned employees in SRC07 `Employee_v2_Adjustment` (`resigned_with_v2_rows = 0`, `without_v2_not_resigned = 0`): EMP1035, EMP1046, EMP1048, EMP1051, EMP1054, EMP1070, EMP1075, EMP1100.
- Those 48 rows hold 10,743,800,000 VND of target revenue. v2 raised the H2 target of the 103 remaining employees by 10,742,200,000 VND compared with their v1 H2 rows, so the H2 company total is almost unchanged. This suggests v2 moved the resigned employees' targets to the remaining reps.

**Options considered** (before the decision)

| Option | Rule | Latest rows (`is_latest = true`) | Effect |
|---|---|---|---|
| (a) Superseded | The 48 v1 H2 rows of resigned employees get `is_latest = false`; latest = v1 months 1–6 + all of v2 | 1,284 | H2 latest target = v2 total (139,998,000,000 VND). Resigned employees have no H2 target |
| (b) Kept | The 48 rows stay `is_latest = true`; latest = v1 months 1–6 + v2 + the 48 rows | 1,332 | H2 latest target includes the 10,743,800,000 VND of the 48 rows on top of v2, which already re-assigned almost the same amount |

**Where it is applied:** `stg_sales_targets_versioned` (`is_latest`, `superseded_by_version`, `valid_from`, `valid_to`), then Gold `fact_targets` and `mart_sales_vs_target`. Test: `is_latest` row count = 1,284.

---

## A-T01 – Only v1 and v2 in the sample

**Issue:** the project guide mentions a third target version (v3, October re-plan). It is not in this data: SRC02 has two sheets, `Plan_v1_Original` and `Plan_v2_Adjustment_H2` (`target_versioning_checks.sql` check 22: 2 plan versions).

**Status:** Decided 2026-11-28.

**Decision**
- Build and test for the two versions that exist. Do not invent a v3.
- `stg_sales_targets_versioned` is written so that a further version needs no code change: each version covers `effective_from` to `effective_to`; for every employee-month the latest version is the covering version with the newest `version_date`; `superseded_by_version` is the next covering version; `valid_to` is the day before that version's `version_date`.
- With a v3 covering October–December, months 10–12 would get `is_latest` on v3, the v2 rows for those months `superseded_by_version = 'v3'`, and v1 would stay superseded by v2. Not tested: there is no v3 data.

**Where it is applied:** `stg_sales_targets_versioned`. A new version also needs the sheet name added to the `plan_version` mapping in `stg_sales_targets` and to `accepted_values`; the count tests (1,950 rows, 1,284 latest) would change and fail on purpose.

