# VietDist Data Pipeline

## Summary
## Project Status
## Changelog
| Date | Version | Changes |
| --- | --- | --- |
| — | Unreleased | Initial project setup and README overview. |

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
### D. Known Data Quality Issues
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