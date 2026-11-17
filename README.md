# VietDist Data Pipeline

## Summary
VietDist is an end-to-end data engineering and analytics project that runs locally.

The pipeline loads Excel and CSV files into PostgreSQL and processes the data through three layers: Bronze for raw data, Silver for cleaned and standardised data, and Gold for reporting-ready data. Power BI Desktop connects to the Gold layer to report on sales performance and distribution.

## Project Status


## Changelog
| Date | Version | Changes |
| --- | --- | --- |
| 2026-11-17 | 0.1.1 | - Completed inital exploration<br>- Simplified B. Initial File Exploration.<br>- Added `notebooks/01_source_columns.ipynb` to list columns and inferred data types.<br>- Documented E. Business Requirements (BR1–BR5).<br>- Designed the data model<br>- Documented the ELT architecture and the data flow.|
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

Used [source columns notebook](notebooks/01_source_columns.ipynb) to inspect column names and data types in the source files.

| ID | File | Sheet | Cols | Columns (data type) |
|---|---|---|---|---|
| SRC01 | SRC01_sales_transactions.csv | – | 21 | `order_id` text, `order_date` text, `order_month` int, `order_quarter` int, `order_year` int, `customer_id` text, `region` text, `province` text, `channel` text, `employee_id` text, `product_id` text, `product_category` text, `quantity` int, `unit_price` int, `discount_pct` int, `discount_amount` float, `gross_amount` int, `net_amount` float, `delivery_status` text, `payment_method` text, `payment_status` text |
| SRC02 | SRC02_sales_target_plan.xlsx | `Plan_v1_Original` / `Plan_v2_Adjustment_H2` | 13 | `plan_version` text, `version_date` text, `effective_from` text, `effective_to` text, `employee_id` text, `employee_name` text, `region` text, `team` text, `year` int, `month` int, `target_revenue` int, `target_quantity` int, `target_new_customers` int |
| SRC03 | SRC03_customer_master.csv | – | 12 | `customer_id` text, `customer_name` text, `customer_type` text, `channel` text, `province` text, `region` text, `address` text, `phone` int, `tax_code` float, `join_date` text, `credit_limit` int, `status` text |
| SRC04 | SRC04_product_master.xlsx | `Products` | 10 | `product_id` text, `product_name` text, `category` text, `sub_category` text, `unit` text, `unit_price` int, `cost_price` int, `weight_gram` int, `status` text, `launch_date` text |
| SRC05 | SRC05_distributor_orders.xlsx | `Orders` | 21 | `order_id` text, `order_date` text, `order_month` int, `order_quarter` int, `distributor_id` text, `region` text, `channel` text, `product_id` text, `product_category` text, `qty_ordered` int, `qty_delivered` int, `fill_rate_pct` float, `unit_price_list` int, `distributor_price` int, `gross_amount` int, `delivered_amount` int, `expected_delivery_date` text, `actual_delivery_date` text, `ontime_delivery` text, `delivery_status` text, `payment_terms` text |
| SRC06 | SRC06_distributor_master.csv | – | 14 | `distributor_id` text, `distributor_name` text, `tier` text, `channel` text, `province` text, `region` text, `contact_person` text, `phone` int, `email` text, `tax_code` int, `join_date` text, `credit_limit` int, `status` text, `assigned_supervisor_id` text |
| SRC07 | SRC07_employee_master.xlsx | `Employee_v1_StartYear` | 15 | `employee_id` text, `full_name` text, `gender` text, `date_of_birth` text, `join_date` text, `position` text, `region` text, `team` text, `email` text, `phone` int, `status` text, `version` text, `effective_date` text, `resign_date` float, `transfer_note` float |
| SRC07 | SRC07_employee_master.xlsx | `Employee_v2_Adjustment` | 15 | Same columns as v1; `resign_date` text, `transfer_note` text |
| SRC07 | SRC07_employee_master.xlsx | `Change_Log` | 8 | `employee_id` text, `employee_name` text, `change_type` text, `effective_date` text, `old_region` text, `new_region` text, `old_team` text, `new_team` text |
| SRC08 | SRC08_territory_mapping.xlsx | `Sheet1` | 8 | `territory_id` text, `employee_id` text, `customer_id` text, `region` text, `team` text, `effective_date` text, `expiry_date` text, `version` text |
| SRC09 | SRC09_return_transactions.csv | – | 14 | `return_id` text, `original_order_id` text, `return_date` text, `return_month` int, `customer_id` text, `employee_id` text, `product_id` text, `region` text, `province` text, `return_quantity` int, `unit_price` int, `return_amount` int, `return_reason` text, `status` text |
| SRC10 | SRC10_promotion_program.xlsx | `Sheet1` | 14 | `promotion_id` text, `promotion_name` text, `promotion_type` text, `target_channel` text, `target_region` text, `start_date` text, `end_date` text, `applicable_products` text, `discount_pct` int, `min_order_quantity` int, `budget_vnd` int, `actual_cost_vnd` int, `status` text, `created_by` text |


### C. Data Scope and Volume
#### Data Scope
- One company, Vietnam only, currency VND.
- Period: 01/01/2024 to 31/12/2024
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
| SRC08 | SRC08_territory_mapping.xlsx | Mapping | Sheet1 | 1,843 | 8 | 0.07 |
| SRC09 | SRC09_return_transactions.csv | Fact | – | 3,665 | 14 | 0.49 |
| SRC10 | SRC10_promotion_program.xlsx | Dimension | Sheet1 | 40 | 14 | 0.01 |
| **Total** | **10 files** | | | **165,023** | | **25.3** |

Report sheets (`Summary` in SRC02, `Category_Summary` in SRC04) are excluded from the row counts and are not loaded. They hold aggregates that can be recomputed from the detail sheets, so they are used only as reconciliation checks.

**Observations**
- The three transaction facts (SRC01, SRC05, SRC09) hold 158,711 rows, about 96% of all data. SRC01 alone is about 82% of the size on disk.
- The dimensions are small: from 40 promotions to 2,000 customers.
- At about 165k rows and 25 MB, the whole dataset fits in memory and a full reload takes seconds. Incremental loading is not needed for performance, but it is still implemented for SRC01 to show the pattern for a growing sales table.


### E. Business Requirements
The warehouse must answer five groups of business questions (BR1–BR5). Each requirement decides which facts, dimensions and marts are built in section F. BR1–BR3 are the priority for v1.0 (the three core Power BI pages); BR4–BR5 follow after v1.0.

#### Business Requirements

| ID | Requirement | Main users | Example questions | Sources | Priority |
|---|---|---|---|---|---|
| BR1 | Sales performance | Sales managers | What is net revenue by month, region, channel, category and product? Which products and customers grow or decline month over month? What margin do we make? | SRC01, SRC03, SRC04 | v1.0 |
| BR2 | Sales vs target | Sales managers | Did each rep and region hit their revenue, quantity and new-customer targets? How did the H2 re-plan (v2) change achievement compared with the original plan (v1)? | SRC01, SRC02, SRC07, SRC08 | v1.0 |
| BR3 | Distributor service | Distribution operations | Which distributors get full and on-time deliveries? Where are fill rate and delays worst? Which distributors are inactive? | SRC05, SRC06, SRC04 | v1.0 |
| BR4 | Returns | Sales managers, distribution operations | What share of sales comes back, for which products, customers and reasons? Are returns linked to orders that were never delivered? | SRC09, SRC01 | After v1.0 |
| BR5 | Promotions | Sales managers | Did sales of covered products rise during each promotion? Did the promotion stay within budget? | SRC10, SRC01, SRC04 | After v1.0 |

### F. Data model - star schema overview


| Table | Type | Description | SCD type | 
|---|---|---|---|
| `dim_date` | Dimension | Calendar: day, week, month, quarter, year, FY | N/A (static) | 
| `dim_employees` | Dimension | Sales reps + history of region/team changes and resignations (from `Change_Log`) | SCD Type 2 | 
| `dim_customers` | Dimension | Customers: type, territory, tax code, phone | SCD Type 1 | 
| `dim_products` | Dimension | Products: category, brand, unit, list price, cost price | SCD Type 1 |
| `dim_distributors` | Dimension | Distributors: region, assigned supervisor | SCD Type 2 | 
| `fact_sales` | Fact | Sales transactions. Grain: 1 order line (`order_id` + `product_id`) | – | 
| `fact_targets` | Fact | Sales targets. Grain: employee × month × version (v1 full year, v2 H2 re-plan) | Temporal (versioned) | 
| `fact_returns` | Fact | Returned goods. Grain: 1 returned line, linked to the original sale | – | 
| `fact_distributor_orders` | Fact | Distributor orders. Grain: 1 order line; ordered vs delivered qty, promised vs actual date | – | 
| `mart_sales_vs_target` | Mart | Monthly actual vs target, credited to the rep/region valid on the order date | – | 
| `mart_distributor_performance` | Mart | Fill rate, on-time delivery %, inactive distributors | – | 

  
### G. ELT Architecture

#### ELT Diagram & Taskflow

![VietDist three-layer data architecture](images/vietdist_architecture_v1.png)

Three-layer ELT on PostgreSQL (Docker): **Raw (Bronze) → Staging (Silver) → Warehouse (Gold)**.

| Step | Tool | What happens |
|---|---|---|
| **Extract** | Python, pandas | Read 10 CSV/XLSX files from `data/raw/` |
| **Load** | Python → PostgreSQL | Write each file as-is to the `raw` schema with metadata columns (`_source_file`, `_loaded_at`, `_batch_id`); log every run in `raw.ingest_log` |
| **Transform** | dbt | Build `staging` views (clean, type, test), then `dwh` tables (star schema, SCD2 snapshot for employees) and marts |
| **Serve** | Power BI | Import marts into 3 report pages |


#### Data Flow Diagram

![VietDist data flow](images/vietdist_data_flow_v1.png)

Table-level flow from the 10 source files to Power BI:
- **Raw:** one table per source file, loaded as-is.
- **Staging:** one model per source; fixes data-type issues (phone, tax_code as text), unions sales-target versions v1 + v2, splits promotion products.
- **Warehouse:** 6 dims, 4 facts and 1 bridge. `dim_employee` is SCD2; facts carry data-quality flags (`is_post_resign_sale`, `is_off_territory`, `is_return_on_undelivered`).
- **Marts:** one per Power BI page.



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