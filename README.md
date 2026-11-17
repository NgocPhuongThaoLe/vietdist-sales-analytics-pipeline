# VietDist Data Pipeline

## Summary
## Project Status
**Phase 0 – Source exploration (in progress).** All 10 sources profiled; cross-source checks partly done. Next: remaining Step 7 checks, then raw ingestion into PostgreSQL.

## Changelog
| Date | Version | Changes |
| --- | --- | --- |
| 2026-11-17 | 0.1.1 | - Completed profiling of SRC04, SRC06 and SRC07; filled column counts in Data Volume.|
| 2026-11-16 | 0.1.0 | - Initial project setup and README overview.<br>- Project folder structure defined; source files stored locally in `data/raw/`.<br>- Added source exploration notebook.<br>- Documented B. Data Sources and Exploration: Source Inventory for all 10 files (grain, contents, keys).<br>- Documented C. Data Scope and Volume and data volume.<br>- Documented D. Known Data Quality Issues. |

## I. Design
### A. Users and Purpose
**Users:** Sales managers and distribution operations teams.

**Purpose:** This project helps VietDist sales managers and distribution teams track sales trends and performance, and identify distribution issues that need attention.

### B. Data Sources and Exploration

#### Source Inventory
- **Number of files:** 10
- **File types:** CSV and XLSX
- **Data sources:** Simulated exports from the company's ERP, CRM, and HR systems
- **Data period:** 2024
- **Total size:** Approximately 25 MB

#### Initial File Exploration

The [source exploration notebook](notebooks/01_source_exploration.ipynb) was used to inspect each source file's contents, row grain, and candidate keys for the Source Inventory.

| ID | File | Format | Grain (one row =) | Holds | Main keys |
|---|---|---|---|---|---|
| SRC01 | SRC01_sales_transactions.csv | CSV | One product line on a customer sales order | Sales fact: 119,101 lines / 50,000 orders / 21 cols, all 2024. Quantity, price, discount, gross & net amount, delivery & payment status. Also repeats dimension attributes (region, province, channel, product_category, order_month/quarter/year) | PK: `order_id` + `product_id` · FK: `customer_id` → SRC03, `product_id` → SRC04, `employee_id` → SRC07 |
| SRC02 | SRC02_sales_target_plan.xlsx | XLSX (3 sheets) | One monthly target for one employee in one plan version | Sales targets (revenue, quantity, new customers). `Plan_v1_Original`: 1,332 rows = 111 emps × 12 months. `Plan_v2_Adjustment_H2`: 618 rows = 103 emps × 6 months (Jul–Dec). The 3 Area Managers have no target. `Summary` is a report sheet → not loaded, used for reconciliation | PK: `plan_version` + `employee_id` + `year` + `month` · FK: `employee_id` → SRC07 |
| SRC03 | SRC03_customer_master.csv | CSV | One customer | 2,000 customers / 12 cols: name, type, channel, province, region, address, phone, tax_code, join_date, credit_limit, status | PK: `customer_id` |
| SRC04 | SRC04_product_master.xlsx | XLSX (2 sheets) | One product (SKU) | 100 products / 10 cols (sheet `Products`): name, category (4), sub-category (17), unit, list price, cost price, weight, status, launch date. `Category_Summary` is a report sheet → not loaded, used for reconciliation | PK: `product_id` |
| SRC05 | SRC05_distributor_orders.xlsx | XLSX | One product line on a distributor order | Distributor order fact: 35,945 lines / 8,000 orders / 21 cols. Qty ordered vs delivered, fill rate, list vs distributor price, expected vs actual delivery date, on-time flag, payment terms | PK: `order_id` + `product_id` · FK: `distributor_id` → SRC06, `product_id` → SRC04 |
| SRC06 | SRC06_distributor_master.csv | CSV | One distributor | 138 distributors / 14 cols: name, tier (3), channel, province, region, contact person, phone, email, tax_code, join date, credit limit, status, assigned supervisor | PK: `distributor_id` · FK: `assigned_supervisor_id` → SRC07 `employee_id` |
| SRC07 | SRC07_employee_master.xlsx | XLSX (3 sheets) | v1/v2: one employee per snapshot · Change_Log: one employee change event | 114 employees / 15 cols in two snapshots: `Employee_v1_StartYear` (effective 2024-01-01, all Active) and `Employee_v2_Adjustment` (effective 2024-07-01, with resign_date and transfer_note). `Change_Log`: 13 changes / 8 cols (8 resignations between 24 May and 18 Jun 2024, 5 region transfers) → source for SCD Type 2 | PK: `employee_id` + `version` (snapshots) · `employee_id` + `effective_date` (Change_Log) |
| SRC08 | SRC08_territory_mapping.xlsx | XLSX | One customer assigned to a territory / sales rep | 1,843 customer-to-rep assignments. Covers 1,843 of 2,000 customers; reflects the start-of-year assignment only | PK: `customer_id` (`territory_id` is also unique) · FK: `customer_id` → SRC03, `employee_id` → SRC07 |
| SRC09 | SRC09_return_transactions.csv | CSV | One returned product line | 3,665 returns / 14 cols: quantity, amount, reason, processing status. 3,564 distinct original orders | PK: `return_id` · FK: `original_order_id` + `product_id` → SRC01, `customer_id` → SRC03, `employee_id` → SRC07 |
| SRC10 | SRC10_promotion_program.xlsx | XLSX | One promotion program | 40 promotions / 14 cols: type, target channel & region, dates, discount %, min qty, budget vs actual cost, status. `applicable_products` holds a pipe-delimited list of products | PK: `promotion_id` · FK: `applicable_products` → SRC04 (multi-valued, needs a bridge table) |

### C. Data Scope and Volume
#### Data Scope
- One company, Vietnam only, currency VND.
- Period: 01/01/2024 to 31/12/2024.
- Sales to retail customers (SRC01) and orders from distributors (SRC05) are separate processes and get separate fact tables.
- Language: the data comes from a Vietnamese company, so text values are in Vietnamese with diacritics (e.g. region `Miền Nam`, payment method `Công nợ`, return status `Đã xử lý`, customer and employee names). Column names are already in English.
  - All files are read and stored as UTF-8, and text is normalised to Unicode NFC in staging so that visually identical values match in joins and group-bys.
  - Names, addresses and other free text stay in Vietnamese. Low-cardinality categorical fields (region, customer type, payment method, return reason, return status, promotion type, product category) get an English label alongside the original value, for the dashboard and an English-speaking audience.

#### Data Volume

| ID | File | Type | Sheets used | Rows | Columns | Size (MB) |
|---|---|---|---|---|---|---|
| SRC01 | SRC01_sales_transactions.csv | Fact | – | 119,101 (50,000 orders) | 21 | 20.62 |
| SRC02 | SRC02_sales_target_plan.xlsx | Fact (plan) | Plan_v1_Original, Plan_v2_Adjustment_H2 | 1,950 (1,332 + 618) | 13 | 0.11 |
| SRC03 | SRC03_customer_master.csv | Dimension | – | 2,000 | 12 | 0.38 |
| SRC04 | SRC04_product_master.xlsx | Dimension | Products | 100 | 10 | 0.01 |
| SRC05 | SRC05_distributor_orders.xlsx | Fact | Orders | 35,945 (8,000 orders) | 21 | 3.53 |
| SRC06 | SRC06_distributor_master.csv | Dimension | – | 138 | 14 | 0.03 |
| SRC07 | SRC07_employee_master.xlsx | Dimension | Employee_v1_StartYear, Employee_v2_Adjustment, Change_Log | 241 (114 + 114 + 13) | 15 / 15 / 8 | 0.03 |
| SRC08 | SRC08_territory_mapping.xlsx | Mapping | Sheet1 | 1,843 | TBC | 0.07 |
| SRC09 | SRC09_return_transactions.csv | Fact | – | 3,665 | 14 | 0.49 |
| SRC10 | SRC10_promotion_program.xlsx | Dimension | Sheet1 | 40 | 14 | 0.01 |
| **Total** | **10 files** | | | **165,023** | | **25.3** |

Report sheets (`Summary` in SRC02, `Category_Summary` in SRC04) are excluded from the row counts and are not loaded: they hold aggregates that can be recomputed from the detail sheets. They are used only as reconciliation checks.

**Observations**
- The three transaction facts (SRC01, SRC05, SRC09) hold 158,711 rows, about 96% of all data. SRC01 alone is 82% of the size on disk.
- The dimensions are small: from 40 promotions to 2,000 customers.
- At about 165k rows and 25 MB, the whole dataset fits in memory and a full reload takes seconds. Incremental loading isn't needed for performance, but it is still implemented for SRC01 to show the pattern for a growing sales table.

### E. Business Requirements
The warehouse must answer five groups of business questions (BR1–BR5). Each requirement decides which facts, dimensions and marts are built in section F. BR1–BR3 are the priority for v1.0 (the three core Power BI pages); BR4–BR5 follow after v1.0.

#### Business Requirements

| ID | Requirement | Main users | Example questions | Sources | Priority |
|---|---|---|---|---|---|
| BR1 | Sales performance | Sales managers | What is net revenue by month, region, channel, category and product? Which products and customers grow or decline month over month? What margin do we make? | SRC01, SRC03, SRC04 | v1.0 |
| BR2 | Sales vs target | Sales managers | Did each rep and region hit their revenue, quantity and new-customer targets? How did the H2 re-plan (v2) change achievement compared with the original plan (v1)? | SRC01, SRC02, SRC07, SRC08 | v1.0 |
| BR3 | Distributor service | Distribution operations | Which distributors get full and on-time deliveries? Where are fill rate and delays worst? Which distributors are inactive? | SRC05, SRC06, SRC04 | v1.0 |
| BR4 | Returns | Sales managers, distribution operations | What share of sales comes back, for which products, customers and reasons? Are returns linked to orders that were never delivered? | SRC09, SRC01 | After v1.0 |

### F. Database Design
#### Fact and Dimension Grain
#### Relationships and Historical Tracking
#### Reporting Marts
### G. ELT Architecture


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