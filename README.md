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

| ID | File | Format | Grain | Holds | Main keys |
| --- | --- | --- | --- | --- | --- |
| SRC01 | `SRC01_sales_transactions.csv` | CSV | | | |
| SRC02 | `SRC02_sales_target_plan.xlsx` | XLSX | | | |
| SRC03 | `SRC03_customer_master.csv` | CSV | | | |
| SRC04 | `SRC04_product_master.xlsx` | XLSX | | | |
| SRC05 | `SRC05_distributor_orders.xlsx` | XLSX | | | |
| SRC06 | `SRC06_distributor_master.csv` | CSV | | | |
| SRC07 | `SRC07_employee_master.xlsx` | XLSX | | | |
| SRC08 | `SRC08_territory_mapping.xlsx` | XLSX | | | |
| SRC09 | `SRC09_return_transactions.csv` | CSV | | | |
| SRC10 | `SRC10_promotion_program.xlsx` | XLSX | | | |
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