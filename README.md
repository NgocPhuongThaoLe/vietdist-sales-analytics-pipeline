# VietDist Data Pipeline

## Summary
## Project Status
## Changelog
| Date | Version | Changes |
| --- | --- | --- |
| 2026-11-16 | 0.1.0 | - Initial project setup and README overview.<br>- Project folder structure defined; source files stored locally in `data/raw/`.<br>- Added source exploration notebook.<br>- Documented B. Data Sources and Exploration: Source Inventory for all 10 files (grain, contents, keys).<br>- Documented C. Data Scope and Volume and data volume.<br>- Documented D. Known Data Quality Issues. |

## I. Design
### A. Users and Purpose
**Users:**   Sales managers and distribution operations teams.

**Purpose** This Project helps VietDist sales managers and distribution teams track sales trends, performance, and identify distribution issues that need attention.
 
### B. Data Sources and Exploration

#### Source Inventory
- **Number of files:** 10
- **File types:** CSV and XLSX
- **Data sources:** Simulated exports from the company’s ERP, CRM, and HR systems
- **Data period:** 2024
- **Total size:** Approximately 25 MB

#### Initial File Exploration

The [source exploration notebook](notebooks/01_source_exploration.ipynb) was used to inspect each source file’s contents, row grain, and candidate keys for the Source Inventory.

| ID | File | Format | Grain (one row =) | Holds | Main keys |
|---|---|---|---|---|---|
| SRC01 | SRC01_sales_transactions.csv | CSV | One product line on a customer sales order | Sales fact: 119,101 lines / 50,000 orders / 21 cols, all 2024. Quantity, price, discount, gross & net amount, delivery & payment status. Also repeats dimension attributes (region, province, channel, product_category, order_month/quarter/year) | PK: `order_id` + `product_id` · FK: `customer_id` → SRC03, `product_id` → SRC04, `employee_id` → SRC07 |
| SRC02 | SRC02_sales_target_plan.xlsx | XLSX (3 sheets) | One monthly target for one employee in one plan version | Sales targets (revenue, quantity, new customers). `Plan_v1_Original`: 1,332 rows = 111 emps × 12 months. `Plan_v2_Adjustment_H2`: 618 rows = 103 emps × 6 months (Jul–Dec). `Summary` is a report sheet → skip | PK: `plan_version` + `employee_id` + `year` + `month` · FK: `employee_id` → SRC07 |
| SRC03 | SRC03_customer_master.csv | CSV | One customer | 2,000 customers / 12 cols: name, type, channel, province, region, address, phone, tax_code, join_date, credit_limit, status | PK: `customer_id` |
| SRC04 | SRC04_product_master.xlsx | XLSX (2 sheets) | One product | 100 products with category (sheet `Products`). `Category_Summary` is a report sheet → skip | PK: `product_id` |
| SRC05 | SRC05_distributor_orders.xlsx | XLSX | One product line on a distributor order | Distributor order fact: 35,945 lines / 8,000 orders / 21 cols. Qty ordered vs delivered, fill rate, list vs distributor price, expected vs actual delivery date, on-time flag, payment terms | PK: `order_id` + `product_id` · FK: `distributor_id` → SRC06, `product_id` → SRC04 |
| SRC06 | SRC06_distributor_master.csv | CSV | One distributor | 138 distributors with contact details (phone, email, tax_code) | PK: `distributor_id` |
| SRC07 | SRC07_employee_master.xlsx | XLSX (3 sheets) | v1/v2: one employee · Change_Log: one employee change event | 114 employees in `Employee_v1_StartYear` (Jan snapshot) and `Employee_v2_Adjustment` (Jul snapshot). `Change_Log`: 13 changes (resignations, region transfers) → source for SCD Type 2 | PK: `employee_id` (v1, v2) · Change_Log: `employee_id` + change date |
| SRC08 | SRC08_territory_mapping.xlsx | XLSX | One customer assigned to a territory / sales rep | 1,843 customer-to-rep assignments. Covers 1,843 of 2,000 customers; reflects the start-of-year assignment only | PK: `customer_id` (`territory_id` is also unique) · FK: `customer_id` → SRC03, `employee_id` → SRC07 |
| SRC09 | SRC09_return_transactions.csv | CSV | One returned product line | 3,665 returns / 14 cols: quantity, amount, reason, processing status. 3,564 distinct original orders | PK: `return_id` · FK: `original_order_id` + `product_id` → SRC01, `customer_id` → SRC03, `employee_id` → SRC07 |
| SRC10 | SRC10_promotion_program.xlsx | XLSX | One promotion program | 40 promotions / 14 cols: type, target channel & region, dates, discount %, min qty, budget vs actual cost, status. `applicable_products` holds a pipe-delimited list of products | PK: `promotion_id` · FK: `applicable_products` → SRC04 (multi-valued, needs a bridge table) | 

### C. Data Scope and Volume
#### Data Scope
• One company, Vietnam only, currency VND.

• Period: 01/01/2024 to 31/12/2024.

• Sales to retail customers (SRC01) and orders from distributors (SRC05) are separate processes and get separate fact tables.

• Language: the data comes from a Vietnamese company, so text values are in Vietnamese with diacritics (e.g. region `Miền Nam`, payment method `Công nợ`, return status `Đã xử lý`, customer and employee names). Column names are already in English.

  – All files are read and stored as UTF-8, and text is normalised to Unicode NFC in staging so that visually identical values match in joins and group-bys.
  
  – Names, addresses and other free text stay in Vietnamese. Low-cardinality categorical fields (region, customer type, payment method, return reason, return status, promotion type, product category) get an English label alongside the original value, for the dashboard and an English-speaking audience.

#### Data Volume

| ID | File | Type | Sheets used | Rows | Columns | Size (MB) |
|---|---|---|---|---|---|---|
| SRC01 | SRC01_sales_transactions.csv | Fact | – | 119,101 (50,000 orders) | 21 | 20.62 |
| SRC02 | SRC02_sales_target_plan.xlsx | Fact (plan) | Plan_v1_Original, Plan_v2_Adjustment_H2 | 1,950 (1,332 + 618) | 13 | 0.11 |
| SRC03 | SRC03_customer_master.csv | Dimension | – | 2,000 | 12 | 0.38 |
| SRC04 | SRC04_product_master.xlsx | Dimension | Products | 100 | TBC | 0.01 |
| SRC05 | SRC05_distributor_orders.xlsx | Fact | Orders | 35,945 (8,000 orders) | 21 | 3.53 |
| SRC06 | SRC06_distributor_master.csv | Dimension | – | 138 | TBC | 0.03 |
| SRC07 | SRC07_employee_master.xlsx | Dimension | Employee_v1_StartYear, Employee_v2_Adjustment, Change_Log | 241 (114 + 114 + 13) | TBC | 0.03 |
| SRC08 | SRC08_territory_mapping.xlsx | Mapping | Sheet1 | 1,843 | TBC | 0.07 |
| SRC09 | SRC09_return_transactions.csv | Fact | – | 3,665 | 14 | 0.49 |
| SRC10 | SRC10_promotion_program.xlsx | Dimension | Sheet1 | 40 | 14 | 0.01 |
| **Total** | **10 files** | | | **165,023** | | **25.3** |

Report sheets (`Summary` in SRC02, `Category_Summary` in SRC04) are excluded from the row counts and are not loaded.

**Observations**
- The three transaction facts (SRC01, SRC05, SRC09) hold 158,711 rows, about 96% of all data. SRC01 alone is 82% of the size on disk.
- The dimensions are small: from 40 promotions to 2,000 customers.
- At about 165k rows and 25 MB, the whole dataset fits in memory and a full reload takes seconds. Incremental loading isn't needed for performance, but it is still implemented for SRC01 to show the pattern for a growing sales table.

### D. Known Data Quality Issues

*Status as of 16 Nov 2026. This section will be updated as profiling continues.*

The [source exploration notebook](notebooks/01_source_exploration.ipynb) was used to profile data quality: data types, null rates, duplicate checks on candidate keys, and foreign-key matches between sources. So far the data is clean at the key level: no orphan foreign keys in any fact table and no nulls in key columns. The issues found are about types, consistency, table design and coverage. Each one will be handled in the staging layer and covered by a data test.

#### Confirmed issues

| # | Source | Issue | Evidence | Planned handling | Planned test |
|---|---|---|---|---|---|
| 1 | SRC03 | `phone` stored as an integer, leading 0 lost | dtype `int64`, e.g. `2868978194` | Read as text; add back the leading 0 | Regex `^0\d{9,10}$` (length distribution to be checked first) |
| 2 | SRC03 | `tax_code` stored as a float and mostly missing | dtype `float64`, shown as `2.416011e+09`; 1,035 of 2,000 null (51.7%) | Read as text; keep nulls; label "Unknown" in reports | Digits only when not null |
| 3 | All | Dates stored as text | dtype `object` for every date column | Cast to `DATE` in staging | Type check; dates within 2024 |
| 4 | SRC01, SRC05 | Order-level attributes differ between lines of the same order | `ORD0010002`: `delivery_status` Delivered / Delivering, `payment_method` Công nợ / Tiền mặt. `DORD0020001`: `payment_terms` NET30 / NET15 / NET45 | Keep at line level; derive an order-level status in a mart | Accepted values on each status column |
| 5 | SRC01, SRC05, SRC09 | Fact tables repeat dimension attributes | Month, quarter, year, region, province, channel, product category stored in the facts | Drop in staging; take from dimension tables | Columns not present in fact tables |
| 6 | SRC08 | Territory mapping has no effective dates | One row per customer, no valid-from/to columns, while SRC07 `Change_Log` records changes during the year | Take the rep's region from `dim_employee` (SCD Type 2) valid on the order date | Rep region in fact = region valid on order date |
| 7 | SRC08, SRC03 | Not every customer has an assigned rep | 1,843 mappings for 2,000 customers; 157 unmapped | Map to an "Unassigned" member in reports | Count of unmapped customers (warn) |
| 8 | SRC10 | `applicable_products` is a pipe-delimited list | e.g. `PRD0017\|PRD0040` | Split into `bridge_promotion_product` | Every `product_id` exists in `dim_product` |
| 9 | SRC10 | `"All"` used as a value instead of a list | `target_region` and `target_channel` contain `All` | Treat as a wildcard when matching promotions to sales | Accepted values (`All` + valid regions/channels) |
| 10 | All | Vietnamese text with diacritics can be stored in different Unicode forms | Text values such as `Miền Nam`, `Đã xử lý` | Read as UTF-8; normalise to NFC | Text equals its NFC form |

#### Coverage findings (not errors)

| Finding | Size |
|---|---|
| Customers who never bought | 198 of 2,000 |
| Customers assigned to a rep but never bought | 41 |
| Products never sold, ordered or returned | 8 of 100 |
| Distributors who never ordered | 13 of 138 |
| Employees with no sales | 6 of 114 |
| Employees with no H2 target (v2 plan) | 11 of 114 |
| Promotions over budget | e.g. PROMO001: 296M vs 278M VND budget |

#### Still to check

These need joins across sources (notebook Step 7). They will move to the confirmed table, with sizes, once verified.

- Sales recorded by employees after their resignation date (SRC01 × SRC07 `Change_Log`).
- Sales where the selling rep is not the customer's assigned rep (SRC01 × SRC08).
- Number of reps who changed region in July, and whether SRC08 reflects it (SRC07 `Change_Log` × SRC08).
- Returns linked to orders that still have cancelled or delivering lines (SRC09 × SRC01).
- Headcount reconciliation: SRC02 `Summary` says 8 employees left (SRC02 `Summary` × SRC07 `Change_Log`).
- Whether `region` / `province` in SRC01 describe the customer or the rep (SRC01 × SRC03 × SRC07).
- Grain checks (`check_grain`) on SRC01, SRC02 and SRC05, and the `check_fk` from SRC09 to SRC01.


### E. Business Requirements and KPIs
### F. Load Schedule and Load Strategies
### G. ELT Architecture
### H. Dimensional Model
#### Fact and Dimension Grain
#### Relationships and Historical Tracking
#### Reporting Marts
### I. DAG Design
### J. Design Decisions and Trade-offs
### K. Implementation Plan

## II. Configuration
### A. Prerequisites

### B. Repository Structure

### C. Environment Variables

### D. PostgreSQL Setup

### E. Source Access and File Formats

## III. Development

### A. Bronze Layer
#### Source Connection and File Parsing
#### Raw Data Ingestion and Metadata
#### Ingestion Log

### B. Bronze Data Profiling

### C. Silver Layer
#### Cleaning and Standardisation
#### Sales Target Versioning

### D. Gold Layer
#### Fact and Dimension Tables
#### Sales vs. Target Mart
#### Distributor Performance Mart

### E. Orchestration and Error Handling

## IV. Testing and Validation

### A. Data Quality Checks

### B. Source-to-Target Reconciliation

### C. Incremental Load and Rerun Tests

### D. SCD Type 2 Validation

### E. Sales Target Version Validation

## V. How to Run Locally
### A. First Run
### B. Simulate a New Monthly File
### C. Verify the Output

## VI. Power BI Dashboard
### A. Gold Tables and KPI Definitions
### B. Report Pages and Screenshots
### C. Key Findings

## VII. Known Limitations and Next Steps

## VIII. References and Supporting Documentation

### A. Project References

### B. Data Dictionary

### C. Assumptions Log