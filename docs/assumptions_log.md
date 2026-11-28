# Assumptions Log

Business rules chosen where the source data allows more than one reading. Each entry states the decision, why it was made, the evidence, and where it is applied. Counts come from the scripts in [`sql/profiling/`](../sql/profiling/); related issues are in [`data_issues.md`](data_issues.md).

| ID | Assumption | Status | Decided |
|---|---|---|---|
| A-DQ08 | Resign date rule | Decided | 2026-11-28 |
| A-DQ09 | Off-territory flag for customers of resigned reps | Open – decision needed | – |
| A-DQ18 | Sales target: v1 H2 rows of resigned employees | Open – decision needed | – |

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

## A-DQ09 – Off-territory flag for customers of resigned reps

**Issue:** [DQ09](data_issues.md) – sales by a rep who is not the customer's mapped rep; [DQ11](data_issues.md) – SRC08 not updated for the July transfers.

**Status:** Open – decision needed. `stg_territory_mapping` passes SRC08 through unchanged; the rule is applied later in `fact_sales`.

**Facts** (`sql/profiling/off_territory_sales.sql`, `sql/profiling/territory_vs_transfers.sql`, run 2026-11-28 on raw batch `cdaee7385083`; dbt test `warn_stg_territory_mapping_resigned_rep`)

- SRC08 has one version (v1, 2024-01-01 to 9999-12-31) and was never updated in 2024.
- 4,192 sales lines (5,625,298,000 VND) are sold by a rep other than the mapped rep, all in July–December.
- Every one of them is to a customer mapped to one of the 8 resigned employees, ordered from 2024-07-01 on. All resign dates fall between 2024-05-24 and 2024-06-18 (`data_period.sql`).
- 196 customers in SRC08 are mapped to a resigned rep (`warn_stg_territory_mapping_resigned_rep`).
- The 5 transferred reps are not a cause: 0 off-territory lines are mapped to them.

**Options**

| Option | Rule | Lines flagged `is_off_territory` |
|---|---|---|
| (a) SRC08 as delivered | Flag when the seller differs from the SRC08 rep | 4,192 |
| (b) Mapping ends at resign date | A customer whose mapped rep resigned before the order date has no valid mapping, so the line is not flagged (it could get its own flag, e.g. `is_orphaned_territory`) | 0 |

**Where it will be applied:** `fact_sales.is_off_territory`; warn test on the flagged count (4,192 under (a), 0 under (b)).

---

## A-DQ18 – Sales target: v1 H2 rows of resigned employees

**Issue:** [DQ18](data_issues.md) – target versions overlap for July–December.

**Status:** Open – decision needed. Nothing is decided yet; the Silver model must not pick an option until this entry is closed.

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

**Options**

| Option | Rule | Latest rows (`is_latest = true`) | Effect |
|---|---|---|---|
| (a) Superseded | The 48 v1 H2 rows of resigned employees get `is_latest = false`; latest = v1 months 1–6 + all of v2 | 1,284 | H2 latest target = v2 total (139,998,000,000 VND). Resigned employees have no H2 target |
| (b) Kept | The 48 rows stay `is_latest = true`; latest = v1 months 1–6 + v2 + the 48 rows | 1,332 | H2 latest target includes the 10,743,800,000 VND of the 48 rows on top of v2, which already re-assigned almost the same amount |

**Where it will be applied:** `stg_sales_target` (`plan_version`, `is_latest`), `fact_targets`, `mart_sales_vs_target`. Planned test: count of `is_latest` rows = the figure of the chosen option.
