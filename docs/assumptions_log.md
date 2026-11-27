# Assumptions Log

Business rules chosen where the source data allows more than one reading. Each entry states the decision, why it was made, the evidence, and where it is applied. Counts come from the scripts in [`sql/profiling/`](../sql/profiling/); related issues are in [`data_issues.md`](data_issues.md).

| ID | Assumption | Status | Decided |
|---|---|---|---|
| A-DQ08 | Resign date rule | Decided | 2026-11-28 |

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
