# VietDist Data Pipeline

## Summary
VietDist is an end-to-end data engineering and analytics project that runs locally.

The pipeline loads Excel and CSV files into PostgreSQL and processes the data through three layers: Bronze for raw data, Silver for cleaned and standardised data, and Gold for reporting-ready data. 

Power BI Desktop connects to the Gold layer to report on sales performance and distribution.

## Project Status

Week 1 – Bronze layer (v0.2.0):
- Bronze load: verified 2026-11-27. All 10 sources load into 11 raw tables, every row count matches section II.E, and a second run skips all 10 sources.
- Item 7, source profiling (v0.2.2): done 2026-11-28. All 19 findings in [`docs/data_issues.md`](docs/data_issues.md) are verified with a count from a script in `sql/profiling/` or a saved notebook output; 0 partial, 0 unverified. One business rule is still open: A-DQ18 (how the 48 v1 H2 target rows of resigned employees count as latest) in [`docs/assumptions_log.md`](docs/assumptions_log.md).
- Silver baseline (v0.2.3): one staging model in plain SQL, `staging.stg_sales_transactions`, passes 13 of 13 plain-SQL tests (section III.C). dbt is set up: `dbt deps`, `dbt debug` and `dbt parse` pass, `_sources.yml` declares the 11 raw tables; no dbt models yet.
- Next: Week 2 – dbt staging models (masters first) with YAML tests.

## Changelog
| Date | Version | Changes |
| --- | --- | --- |
| 2026-11-28 | 0.2.3 | - Silver (plain SQL): `stg_sales_transactions` + 13 tests in `sql/silver/` (13/13 pass).<br>- Added `docs/pain_points.md` (why dbt).<br>- dbt: `dbt_utils` 1.4.1, `_sources.yml` (11 raw tables).<br>- Fix: PowerShell UTF-8 tip in `sql/profiling/README.md`. |
| 2026-11-28 | 0.2.2 | - Profiling done: all 19 findings in `docs/data_issues.md` verified.<br>- New scripts in `sql/profiling/`: `derived_columns_src01.sql` (DQ14), `order_header_consistency.sql` (DQ15), `target_overlap.sql` (DQ18), `returns_on_undelivered.sql` (DQ16), `off_territory_sales.sql` (DQ09), `territory_vs_transfers.sql` (DQ11), `promotion_products.sql` (DQ17).<br>- `docs/assumptions_log.md`: added A-DQ18 (open – decision needed).<br>- `sql/profiling/README.md`: every script with pass condition and result.<br>- README: project status, section I.D and III.B match the profiling results; DQ08 counts added; `assumptions_log.md` no longer marked planned. |
| 2026-11-27 | 0.2.1 | - Raw tables: empty cells → `NULL`; added `_row_number` for traceability.<br>- `init_db.sql` is the single source for schemas and `ingest_log`; loader stops on column changes.<br>- Config: port `5433` consistent, added `profiles.example.yml` + env scripts, dbt `marts:` → `dwh:`.<br>- Profiling: `docs/data_issues.md` + 5 scripts in `sql/profiling/`.<br>- Cleanup: unused code/files removed, `requirements.txt` direct deps only, README matches repo. |
| 2026-11-26 | 0.2.0 | - Added `loader.py` and `run_all.py`.<br>- Removed old `db.py` and `load_raw.py` (replaced by `loader.py` + `run_all.py`).<br>- Added `init_db.sql` (schemas `raw`, `staging`, `dwh`, `snapshots` + `raw.ingest_log` with lookup index).<br>- Switched raw load from multi-row INSERT to Postgres `COPY` (SRC01 119k rows: minutes → ~10 s).<br>- Fixed sheet names in `config.py`.<br>- `reader.py` self-check: updated expected row counts to the real sheet names; a missing expected count is now flagged as `CHECK` instead of passing; the float-like check (`123.0`) now runs on ID/code/phone/tax columns only.<br>- Fixed Docker port mapping to `5433:5432`; use `127.0.0.1` as host on Windows.<br>- All 10 sources loaded into 11 raw tables; row counts match the data profile.<br>- Rewrote README Section III.A to match the implementation. |
| 2026-11-24 | 0.1.5 | - Added `reader.py`. |
| 2026-11-23 | 0.1.4 | - Added Bronze layer development documentation to the README (Section III.A)<br>- Added `config.py` as the central configuration module for the loaders. |
| 2026-11-22 | 0.1.3 | - Set up the project structure for PostgreSQL, Python loaders, dbt, and Power BI.<br>- Added Docker Compose, database initialization, and environment configuration files.<br>- Updated the README with the local setup steps and repository layout. |
| 2026-11-21 | 0.1.2 | - Added the Configuration and Setup section to the README.<br>- Configured dbt to read PostgreSQL connection settings from environment variables.<br>- Documented how to load `.env` variables and verify the connection with `dbt debug`. |
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
- **Data period:** 01/01/2024 to 31/12/2024
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
- At about 165k rows and 25 MB, the whole dataset fits in memory and a full reload takes seconds. Incremental loading is not needed for performance; it is planned for SRC01 later to show the pattern for a growing sales table. Today every source is a full refresh.

### D. Known Data Quality Issues

The source files contain deliberate quality issues. Bronze loads them as-is; Silver handles and tests them. Full list, counts and evidence: [`docs/data_issues.md`](docs/data_issues.md).

- Grain and foreign keys are clean: SRC01 and SRC05 are unique on `order_id` + `product_id`, and every return, distributor supervisor, customer, product and employee reference resolves.
- Sales after an employee's resign date: 547 lines, 736,436,300 VND net, across 8 employees (rule `order_date > resign_date`, see [`docs/assumptions_log.md`](docs/assumptions_log.md)). Sales by a rep who is not the customer's mapped rep: 4,192 lines (5,625,298,000 VND), all in July–December and all to customers still mapped to the 8 resigned employees.
- 157 customers have no territory mapping. The mapping was not updated for the 5 July region transfers: all 85 SRC08 rows of these employees still show the old region.
- `phone` and `tax_code` are read as numbers by default (leading zeros lost); `tax_code` is 51.7% null in SRC03.
- SRC01 stores derived columns (month, quarter, year, amounts). All match their base columns except `discount_amount`, which is rounded half-to-even to 100 VND (13,971 rows differ by up to 50 VND). `delivery_status`, `payment_method` and `payment_status` differ between lines of the same order (10,904, 28,666 and 18,861 of 50,000 orders), so they are line-level.
- Returns linked to sales lines that were cancelled or still delivering: 0. All 3,665 returns point to a delivered line.
- SRC10 `applicable_products` holds several product ids separated by `|` (36 of 40 promotions; 145 promotion × product pairs, all in the product master).
- Sales target v1 and v2 overlap for July–December: 618 v1 rows are re-planned in v2; 48 v1 rows of the 8 resigned employees have no v2 row (rule open, A-DQ18).
- 219 SRC05 `expected_delivery_date` values fall in 2025, so `dim_date` must reach 2025-01-02. SRC08 uses `9999-12-31` as an open end date.

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

This section covers required tools, repository structure, environment variables, PostgreSQL setup, and source file preparation.

### Quick start

If you already have Git, Docker Desktop and Python installed (commands shown for Windows PowerShell; macOS/Linux in comments):

```powershell
git clone https://github.com/NgocPhuongThaoLe/vietdist-sales-distribution-analytics.git
cd vietdist-sales-distribution-analytics
copy .env.example .env                       # macOS/Linux: cp .env.example .env
docker compose up -d                         # starts PostgreSQL on 127.0.0.1:5433, creates schemas
python -m venv .venv
.venv\Scripts\activate                       # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
# Put the 10 source files in data\raw\ (section E)
python loaders\reader.py                     # pre-check, no database: should end with "0 item(s) to check"
python loaders\run_all.py                    # loads all 10 sources into schema raw
mkdir $HOME\.dbt -Force                      # macOS/Linux: mkdir -p ~/.dbt
copy vietdist_dbt\profiles.example.yml $HOME\.dbt\profiles.yml   # macOS/Linux: cp vietdist_dbt/profiles.example.yml ~/.dbt/profiles.yml
. .\scripts\load_env.ps1                     # macOS/Linux: source scripts/load_env.sh
cd vietdist_dbt
dbt debug                                    # should end with "All checks passed!"
```

Docker Desktop must be running before `docker compose up -d`. The sections below explain each step.

---

### A. Prerequisites

| Tool | Version (tested) | Used for |
|---|---|---|
| [Git](https://git-scm.com/) | 2.40+ | Cloning the repository |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) (incl. Docker Compose v2) | 4.x / Compose 2.20+ | Running PostgreSQL in a container |
| [Python](https://www.python.org/downloads/) | 3.11 – 3.13 (tested on 3.13) | Python loaders + dbt Core |
| [dbt Core](https://docs.getdbt.com/docs/core/installation-overview) + `dbt-postgres` | dbt Core 1.11+ (below 2.0), `dbt-postgres` 1.11+ | Transformations (staging → warehouse), tests, snapshot, docs |
| [Power BI Desktop](https://powerbi.microsoft.com/desktop/) | Latest | Report layer (Windows only) |
| A SQL client (optional) – DBeaver, pgAdmin or `psql` | Any | Inspecting the database |

**Hardware:** ~2 GB free RAM for Docker and ~1 GB free disk space (raw data is ~25 MB; the database with all three layers is a few hundred MB).

Check that everything is installed:

```bash
git --version
docker --version
docker compose version
python --version        # should print 3.11.x – 3.13.x
```

> Docker only runs PostgreSQL. The Python loaders and dbt run on your machine, so your local Python version matters. All versions are pinned in `requirements.txt`.

Clone the repository, then create a virtual environment and install dependencies:

```bash
git clone https://github.com/NgocPhuongThaoLe/vietdist-sales-distribution-analytics.git
cd vietdist-sales-distribution-analytics

python -m venv .venv
.venv\Scripts\activate          # Windows  (macOS/Linux: source .venv/bin/activate)
pip install -r requirements.txt
dbt --version                   # should show core 1.11+ and the postgres plugin
```

All commands in this README run from the project root (`vietdist-sales-distribution-analytics/`) unless stated otherwise. dbt commands run from `vietdist_dbt/`.

---

### B. Repository Structure

Items marked `(planned)` do not exist yet.

```text
vietdist-sales-distribution-analytics/
├── data/
│   └── raw/                        # Source files go here (git-ignored, see section E)
│       ├── .gitkeep                # Keeps the empty folder in Git
│       ├── SRC01_sales_transactions.csv
│       ├── ...
│       └── SRC10_promotion_program.xlsx
│
├── docker/
│   └── postgres/
│       └── init_db.sql             # Schemas raw, staging, dwh, snapshots + raw.ingest_log (single definition)
│
├── loaders/                        # Layer 1 – Extract & Load (Python)
│   ├── config.py                   # Reads .env; SOURCES registry: file → sheet(s) → raw table
│   ├── reader.py                   # Reads CSV/XLSX as text; `python loaders/reader.py` = pre-check without DB
│   ├── loader.py                   # Hash check, metadata columns, TRUNCATE + COPY, raw.ingest_log
│   └── run_all.py                  # Entry point: loads all sources (--only, --force)
│
├── vietdist_dbt/                   # Layers 2 & 3 – Transform (dbt Core)
│   ├── dbt_project.yml
│   ├── profiles.example.yml        # Template: copy to ~/.dbt/profiles.yml (no secrets, reads env vars)
│   ├── packages.yml                # dbt_utils (package-lock.yml pins the resolved version)
│   ├── models/
│   │   ├── staging/                # _sources.yml (11 raw tables); (planned) 1 view per source (stg_*) + _stg_models.yml
│   │   └── dwh/
│   │       ├── dims/               # 6 dimensions
│   │       ├── facts/              # 4 facts
│   │       ├── bridges/            # bridge_promotion_product
│   │       └── marts/              # 3 marts for Power BI
│   ├── snapshots/                  # (planned) dim_employee SCD Type 2
│   ├── tests/                      # (planned) Singular (custom SQL) tests
│   └── macros/
│       └── generate_schema_name.sql   # Uses schema names exactly as configured
│
├── notebooks/
│   ├── 00_source_exploration.ipynb # Profiling before modelling (outputs feed docs/data_issues.md)
│   └── 01_source_columns.ipynb     # Column names and inferred types (section I.B)
│
├── sql/
│   ├── profiling/                  # SQL checks behind docs/data_issues.md (one script per finding)
│   └── silver/                     # Plain-SQL baseline: stg_sales_transactions.sql, tests/, run_tests.sh / .ps1
│
├── scripts/
│   ├── load_env.sh                 # Loads .env into the shell (macOS/Linux)
│   └── load_env.ps1                # Loads .env into the shell (Windows PowerShell)
│
├── power_bi/                       # (planned) vietdist_report.pbix, 3 report pages from schema dwh
│
├── docs/
│   ├── data_issues.md              # Known data issues: count, evidence, Silver handling, planned test
│   ├── pain_points.md              # Problems of building Silver in plain SQL (why dbt)
│   ├── data_dictionary.md          # (planned)
│   └── assumptions_log.md          # Business rules chosen where the data allows more than one reading
│
├── images/                         # Architecture and data flow diagrams used in this README
│
├── docker-compose.yml              # PostgreSQL service
├── requirements.txt                # Python + dbt dependencies (direct, pinned)
├── .env.example                    # Template for environment variables
├── .gitignore
└── README.md
```

| Folder | Layer in the architecture |
|---|---|
| `data/raw/` | Source files |
| `loaders/` | Python loaders → **Layer 1 Raw (Bronze)** |
| `vietdist_dbt/models/staging/` | **Layer 2 Staging (Silver)** |
| `vietdist_dbt/models/dwh/` + `vietdist_dbt/snapshots/` | **Layer 3 Warehouse (Gold)** |
| `power_bi/` | Power BI reports |

---

### C. Environment Variables

All connection details live in one `.env` file in the project root. It is read by **Docker Compose** (to create the database), the **Python loaders** (via `python-dotenv`) and **dbt** (via `env_var()` in `~/.dbt/profiles.yml`). The real `.env` is listed in `.gitignore` and must never be committed.

**1. Create your `.env` from the template:**

```bash
copy .env.example .env        # Windows
cp .env.example .env          # macOS / Linux
```

**2. Edit the values if needed (`.env.example`):**

```dotenv
# ---------- PostgreSQL (Docker) ----------
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5433
POSTGRES_DB=vietdist
POSTGRES_USER=vietdist_admin
POSTGRES_PASSWORD=change_me_please

# Optional: a full SQLAlchemy URL overrides the POSTGRES_* values for the loaders (CI / Airflow)
# DATABASE_URL=postgresql+psycopg2://vietdist_admin:change_me_please@127.0.0.1:5433/vietdist

# ---------- Loaders ----------
RAW_DATA_DIR=data/raw

# ---------- dbt ----------
DBT_TARGET=dev
DBT_THREADS=4
```

> Keep comments on their own line. Docker Compose, `python-dotenv` and the shell scripts handle `VALUE  # comment` differently. Avoid spaces, quotes, `#` and `$` in values.

| Variable | Description | Default |
|---|---|---|
| `POSTGRES_HOST` | Database host. Use `127.0.0.1` rather than `localhost`: on Windows, `localhost` can resolve to IPv6 (`::1`) and reach a locally installed Postgres instead of the Docker container | `127.0.0.1` |
| `POSTGRES_PORT` | Host port mapped to the container (`docker-compose.yml` reads it). `5433` avoids a clash with a locally installed Postgres on `5432` (check with `Get-Service *postgres*` on Windows) | `5433` |
| `POSTGRES_DB` | Database name | `vietdist` |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | Admin user created when the container starts **for the first time** | – |
| `DATABASE_URL` | Optional. Full SQLAlchemy URL; if set, the loaders use it instead of the `POSTGRES_*` values | not set |
| `RAW_DATA_DIR` | Folder the loaders read source files from, relative to the project root | `data/raw` |
| `DBT_TARGET` | dbt target (output) to use | `dev` |
| `DBT_THREADS` | Number of models dbt builds in parallel | `4` |

**3. dbt reads the same variables through `~/.dbt/profiles.yml`.**

The repository ships a template, `vietdist_dbt/profiles.example.yml`. Copy it to your dbt home folder once:

```powershell
mkdir $HOME\.dbt -Force
copy vietdist_dbt\profiles.example.yml $HOME\.dbt\profiles.yml       # Windows
```

```bash
mkdir -p ~/.dbt && cp vietdist_dbt/profiles.example.yml ~/.dbt/profiles.yml   # macOS / Linux
```

`vietdist_dbt/profiles.example.yml`:

```yaml
vietdist_dbt:
  target: "{{ env_var('DBT_TARGET', 'dev') }}"
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('POSTGRES_HOST', '127.0.0.1') }}"
      port: "{{ env_var('POSTGRES_PORT', '5433') | as_number }}"
      dbname: "{{ env_var('POSTGRES_DB', 'vietdist') }}"
      user: "{{ env_var('POSTGRES_USER') }}"
      password: "{{ env_var('POSTGRES_PASSWORD') }}"
      schema: staging            # default schema; dwh models override it in dbt_project.yml
      threads: "{{ env_var('DBT_THREADS', '4') | as_number }}"
```

The top-level key (`vietdist_dbt`) must match `profile: 'vietdist_dbt'` in `dbt_project.yml`.

> dbt looks for `profiles.yml` in the current folder **before** `~/.dbt/`. Do not keep a second `profiles.yml` inside `vietdist_dbt/`, or dbt will silently use that one instead. `dbt debug` prints which file it is using (`Using profiles.yml file at ...`).

The default schema is `staging`. Models in `models/dwh/` set `+schema: dwh` in `dbt_project.yml`:

```yaml
models:
  vietdist_dbt:
    staging:
      +schema: staging
      +materialized: view
    dwh:
      +schema: dwh
      +materialized: table
```

Without `macros/generate_schema_name.sql`, dbt would join the default and custom schema names and create `staging_staging` and `staging_dwh`. The macro makes dbt use `staging` and `dwh` exactly:

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

**4. Load `.env` into your shell before running dbt.** dbt does not read `.env` files by itself. Run this once per new terminal, **from the project root**:

```bash
. .\scripts\load_env.ps1            # Windows PowerShell
source scripts/load_env.sh          # macOS / Linux
```

Both scripts skip comment lines, set every `NAME=value` from `.env` for the current terminal only, and stop with a message if `.env` is missing.

The Python loaders do not need this step; they read `.env` directly with `python-dotenv`.

---

### D. PostgreSQL Setup

PostgreSQL runs in Docker, so there is nothing to install on your machine. On first start the container runs `docker/postgres/init_db.sql`, which creates the schemas and the ingest log.

**1. `docker-compose.yml`:**

```yaml
services:
  postgres:
    image: postgres:16
    container_name: vietdist_postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "${POSTGRES_PORT:-5433}:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./docker/postgres/init_db.sql:/docker-entrypoint-initdb.d/init_db.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  pg_data:
```

Docker Compose fills in `${...}` from the `.env` file in the project root automatically (`5433` if `POSTGRES_PORT` is not set). Inside the container Postgres always listens on `5432`; `POSTGRES_PORT` only changes the port on your machine.

**2. `docker/postgres/init_db.sql`** creates the schemas `raw`, `staging`, `dwh` and `snapshots`, and the table `raw.ingest_log` (columns in section III.A, *Ingestion Log*). It is the only place these are defined. Every statement uses `IF NOT EXISTS`, and the loader runs the same file before each load, so an existing database picks up changes without a reset.

A read-only role for Power BI is planned for the Gold layer.

**3. Start the database and check it is healthy:**

```bash
docker compose up -d
docker compose ps                          # STATUS should show "healthy"; PORTS shows <POSTGRES_PORT>->5432
docker compose exec postgres psql -U vietdist_admin -d vietdist -c "\dn"
```

Expected schemas: `raw`, `staging`, `dwh`, `snapshots`, `public`.

**4. Check that dbt can connect:**

```bash
. .\scripts\load_env.ps1                   # macOS/Linux: source scripts/load_env.sh
cd vietdist_dbt
dbt debug                                  # should end with "All checks passed!"
```

**5. Connection details (SQL client / Power BI):**

| Setting | Value |
|---|---|
| Host | `127.0.0.1` |
| Port | value of `POSTGRES_PORT` (default `5433`) |
| Database | `vietdist` |
| User | `vietdist_admin` (full access) |

In DBeaver, create the connection via **Database → New Database Connection → PostgreSQL** (not via *Edit Driver*, which changes the driver for every connection).

**Useful commands:**

| Command | What it does |
|---|---|
| `docker compose up -d` | Starts the database |
| `docker compose stop` | Stops the container, keeps the data |
| `docker compose down` | Removes the container, keeps the data (volume `pg_data`) |
| `docker compose down -v` | Removes the container **and all data** – `init_db.sql` runs again on next `up` |
| `docker compose logs -f postgres` | Follows the database log |

> Docker runs `init_db.sql` only when the volume is empty. The loader also runs it before every load, so new schemas or tables added there appear on the next `python loaders/run_all.py`. Changing an existing column still needs `docker compose down -v` and `docker compose up -d` (this deletes all data).

**Troubleshooting:**

| Error | Cause | Fix |
|---|---|---|
| `failed to connect to the docker API ... dockerDesktopLinuxEngine` | Docker Desktop is not running | Start Docker Desktop and wait for "Engine running" |
| `Could not find profile named 'vietdist_dbt'` | No `profiles.yml` in `~/.dbt/` (or the top-level key is misspelled) | Copy `profiles.example.yml` as in section C.3 |
| `Connection refused` | Container not running, or port in `.env` ≠ port in use | `docker compose ps`; use the host port shown under PORTS |
| `password authentication failed` | Another Postgres on the same port, or the password in `.env` changed after the first start | Use `127.0.0.1` and a free port (e.g. `5433`); reset with `docker compose exec postgres psql -U vietdist_admin -d vietdist -c "ALTER USER vietdist_admin PASSWORD '<new>';"` or `docker compose down -v` |
| `env_var ... is not set` in dbt | `.env` not loaded in this terminal | Run `. .\scripts\load_env.ps1` from the project root |

---

### E. Source Access and File Formats

**1. Access**

The source data is a synthetic dataset for a fictional Vietnamese FMCG distributor (VietDist), covering calendar year 2024. It contains 10 files (~25 MB) delivered as one zip archive. The raw files are **not committed** to Git (`data/raw/*` is in `.gitignore`, except `.gitkeep`).

To get the data:
1. Download `vietdist_sample_data.zip` from the [GitHub Releases](https://github.com/NgocPhuongThaoLe/vietdist-sales-distribution-analytics/releases) page.
2. Extract it so the files sit directly in `data/raw/` (no sub-folder).
3. Do not rename the files – the loaders match them by name.

**2. Source files**

| ID | File | Format | Sheet(s) loaded | Rows | Raw table |
|---|---|---|---|---|---|
| SRC01 | `SRC01_sales_transactions.csv` | CSV | – | 119,101 lines (50,000 orders) | `raw.src01_sales_transactions` |
| SRC02 | `SRC02_sales_target_plan.xlsx` | XLSX | `Plan_v1_Original`, `Plan_v2_Adjustment_H2` (skip `Summary`) | 1,332 + 618 | `raw.src02_sales_target` |
| SRC03 | `SRC03_customer_master.csv` | CSV | – | 2,000 | `raw.src03_customer_master` |
| SRC04 | `SRC04_product_master.xlsx` | XLSX | `Products` (skip `Category_Summary`) | 100 | `raw.src04_product_master` |
| SRC05 | `SRC05_distributor_orders.xlsx` | XLSX | `Orders` | 35,945 lines (8,000 orders) | `raw.src05_distributor_orders` |
| SRC06 | `SRC06_distributor_master.csv` | CSV | – | 138 | `raw.src06_distributor_master` |
| SRC07 | `SRC07_employee_master.xlsx` | XLSX | `Employee_v1_StartYear`, `Employee_v2_Adjustment`, `Change_Log` | 114 + 114 + 13 | `raw.src07_employee_master`, `raw.src07_employee_change_log` |
| SRC08 | `SRC08_territory_mapping.xlsx` | XLSX | `Sheet1` | 1,843 | `raw.src08_territory_mapping` |
| SRC09 | `SRC09_return_transactions.csv` | CSV | – | 3,665 | `raw.src09_return_transactions` |
| SRC10 | `SRC10_promotion_program.xlsx` | XLSX | `Sheet1` | 40 | `raw.src10_promotion_program` |

**3. Format rules the loaders follow**

| Rule | Detail |
|---|---|
| Encoding | CSV files are read as **UTF-8** (Vietnamese diacritics). Text is normalised to Unicode **NFC** in staging. |
| Delimiter | CSV uses comma `,`; first row is the header. |
| Excel | Only `.xlsx` is supported (read with `openpyxl`). Summary sheets (`Summary`, `Category_Summary`) are skipped. |
| Versioned sheets | SRC02 and SRC07 have `v1` / `v2` sheets. Both are loaded into the same raw table with a `_sheet_name` column; staging decides which version is used. |
| Data types in Raw | **Every source column is loaded as `TEXT`** – nothing is cast in Layer 1. This keeps values such as `phone` and `tax_code` exactly as delivered; casting and cleaning happen in dbt staging. |
| Empty cells | Stored as `NULL`. Text such as `NA` or `null` stays text. |
| Dates | Single format in the source (`YYYY-MM-DD`, checked by `sql/profiling/data_period.sql`); parsed in staging. |
| Currency | Amounts are in **VND**. Some SRC01 amounts are written as `908000.0` in the file and stay that way in raw. |
| Column names | Kept as in the source (already English `snake_case`); only surrounding spaces are trimmed. |

**4. Metadata columns added to every raw table**

See section III.A, *Raw Data Ingestion and Metadata*.

**5. Known data issues**

The source data contains deliberate quality issues (lost leading zeros, unmapped customers, pipe-delimited lists, derived columns). How each one is detected and fixed is documented in [`docs/data_issues.md`](docs/data_issues.md).

## III. Development

### A. Bronze Layer

The Bronze layer loads the 10 source files into PostgreSQL **as delivered**, with no cleaning or business logic. It does three things: makes the raw data queryable, makes each row traceable to its source file, and makes reloads safe. All cleaning (types, phone/tax_code fixes, Unicode NFC, dropping derived columns) happens later in the Silver layer (dbt staging models).

| Item | Choice |
|---|---|
| Source location | Local folder `data/raw/` (10 files, ~25 MB, CSV + XLSX) |
| Target | PostgreSQL 16 (Docker Compose), schema `raw` |
| Tooling | Python 3.13, pandas, openpyxl, SQLAlchemy 2, psycopg2 |
| Load pattern | Full refresh per source file, skipped if the file is unchanged (hash check) |
| Load method | Postgres `COPY ... FROM STDIN` (SRC01, 119k rows, loads in ~10 s) |
| Entry point | `python loaders/run_all.py` (loads all sources) |

#### Source Connection and File Parsing

**Connection.** Database credentials are read from `.env`, which is never committed (see `.env.example`). Postgres runs in Docker with the host port from `POSTGRES_PORT` (default `5433`) mapped to `5432` in the container:

    docker compose up -d postgres
    docker compose port postgres 5432      # -> 0.0.0.0:5433

`init_db.sql` is mounted into `/docker-entrypoint-initdb.d/` and runs automatically the first time the container starts on an empty volume. It creates the schemas `raw`, `staging`, `dwh` and `snapshots`, plus the table `raw.ingest_log`. The loader runs the same file at the start of every load (`ensure_log_table` in `loader.py`), so an existing database picks up new schemas or tables without a manual step.

On Windows, use `127.0.0.1` instead of `localhost`. Otherwise `localhost` resolves to IPv6 `::1`, and Docker Desktop may drop the connection.

**Source registry.** Every source is declared once in the `SOURCES` list in `loaders/config.py`. Each entry has the source id, the file name, the format and the target table. For Excel files, it also maps each sheet to load to a target table. Sheets not listed in that mapping are skipped. The loader loops over this registry, so adding a source means adding config, not code. Sheet names must match the Excel file exactly. If a listed sheet is missing, the source fails with a message that lists the sheets that are available.

**Parsing rules** (`loaders/reader.py`):
- **Every column is read as text** (`dtype=str`, `keep_default_na=False`). This stops pandas from changing data on read, for example turning `tax_code` into a float or dropping leading zeros. Type casting is left to Silver on purpose.
- **Empty cells become `NULL`**, so Silver can use `not_null` tests directly. Text such as `NA` or `null` is not treated as missing and stays text.
- **CSV**: encoding `utf-8-sig` (UTF-8, BOM-safe for Vietnamese text), comma-delimited, header on row 1.
- **XLSX**: only the sheets listed in the registry are loaded. Summary sheets are skipped (`Summary` in SRC02, `Category_Summary` in SRC04).
- **Multi-version sheets are unioned into one table per entity**, and `_sheet_name` records the version:
  - SRC02: target v1 (full year) and v2 (H2 re-plan) go into `src02_sales_target`.
  - SRC07: employee v1 and v2 go into `src07_employee_master`, and `Change_Log` goes into its own table.

  This keeps the history that Silver needs for target versioning and SCD2, and a version can be filtered with a `WHERE` clause.
- **Light tidy-up only**, with no cell values changed. Spaces around column names are trimmed. Rows where every cell is empty are dropped (the count is logged). Columns with no header (`Unnamed: n`) are dropped if they are completely empty. Column names are otherwise kept as in the source.

| Source | Format | Sheets loaded | Raw table | Rows |
|---|---|---|---|---|
| SRC01 Sales transactions | CSV | – | `raw.src01_sales_transactions` | 119,101 |
| SRC02 Sales target plan | XLSX | Plan_v1_Original, Plan_v2_Adjustment_H2 | `raw.src02_sales_target` | 1,332 + 618 |
| SRC03 Customer master | CSV | – | `raw.src03_customer_master` | 2,000 |
| SRC04 Product master | XLSX | Products | `raw.src04_product_master` | 100 |
| SRC05 Distributor orders | XLSX | Orders | `raw.src05_distributor_orders` | 35,945 |
| SRC06 Distributor master | CSV | – | `raw.src06_distributor_master` | 138 |
| SRC07 Employee master | XLSX | Employee_v1_StartYear, Employee_v2_Adjustment | `raw.src07_employee_master` | 114 + 114 |
| | | Change_Log | `raw.src07_employee_change_log` | 13 |
| SRC08 Territory mapping | XLSX | Sheet1 | `raw.src08_territory_mapping` | 1,843 |
| SRC09 Return transactions | CSV | – | `raw.src09_return_transactions` | 3,665 |
| SRC10 Promotion program | XLSX | Sheet1 | `raw.src10_promotion_program` | 40 |

#### Raw Data Ingestion and Metadata

**One transaction per source file.** Every target table of the file is truncated and reloaded, and the `success` rows are written to `raw.ingest_log`, all in one transaction. If any step fails, nothing from that file is committed, so a failed load never leaves a half-written or mixed-version table. Tables are truncated rather than dropped, so dbt views built on `raw.*` keep working.

**Failures are isolated.** If one source fails, it is logged as `failed` (with the file hash, if it was computed) in a separate transaction and the run continues with the remaining sources. `run_all.py` exits with code 1 if any source failed, so Airflow or CI can mark the run as failed.

**Schema changes fail loudly.** If a file gains or loses a column, or the loader adds a metadata column, the load stops with a message naming the new and missing columns. Drop that raw table (and any views on it), then rerun with `--force`.

The loader adds these metadata columns to every row:

| Column | Type | Purpose |
|---|---|---|
| `_row_number` | BIGINT | Row in the source file or sheet (header = row 1, so the first data row is 2). Traces a failing row back to the file |
| `_batch_id` | TEXT | 12-character run id. Groups everything loaded in one run and joins to `raw.ingest_log.batch_id` |
| `_source_file` | TEXT | Original file name, e.g. `SRC01_sales_transactions.csv` |
| `_sheet_name` | TEXT | Excel sheet the row came from (`NULL` for CSV); also the version key for SRC02/SRC07 |
| `_file_hash` | TEXT | SHA-256 of the source file |
| `_loaded_at` | TIMESTAMPTZ | Load timestamp (UTC) |

**Re-runnable by design.** Before loading, the loader computes the file's SHA-256 and checks `raw.ingest_log`. If the same source already loaded successfully with the same hash, the whole file is `skipped`. If the file changed, every table from that file is reloaded. Running the loader twice therefore never creates duplicates.

    python loaders/run_all.py                    # load all new/changed sources
    python loaders/run_all.py --only SRC07       # one or more sources
    python loaders/run_all.py --force            # reload even if unchanged

The skip is based on the file content only. After changing loader code or `config.py`, run with `--force`, or the old data stays in place.

**Pre-load check (optional, no database).** `python loaders/reader.py` reads every source and compares row counts with the data profile. It also flags columns that are not text, and values that look like floats (`123.0`).

#### Ingestion Log

`raw.ingest_log` keeps one row per sheet, or per CSV file, per run. It is the audit trail for the Bronze layer: what was loaded, when, from which file version, and whether it worked. It is created by `init_db.sql`, with an index on `(source_id, file_hash, status)` for the skip lookup.

| Column | Type | Description |
|---|---|---|
| `log_id` | BIGSERIAL PK | |
| `batch_id` | TEXT | Run identifier (same as `_batch_id` in the data) |
| `source_id` | TEXT | `SRC01` … `SRC10` |
| `file_name` | TEXT | Source file name |
| `file_hash` | TEXT | SHA-256 of the file |
| `sheet` | TEXT | Sheet name (`NULL` for CSV and for skipped/failed files) |
| `target_table` | TEXT | e.g. `raw.src07_employee_master` |
| `row_count` | INT | Rows read from the file and loaded |
| `status` | TEXT | `success` / `skipped` (unchanged hash) / `failed` |
| `error` | TEXT | Exception text if failed (first 2,000 characters) |
| `started_at` / `finished_at` | TIMESTAMPTZ | Load duration |

Example: check the latest run

    SELECT source_id, sheet, target_table, status, row_count,
           finished_at - started_at AS duration
    FROM raw.ingest_log
    WHERE batch_id = (SELECT batch_id FROM raw.ingest_log ORDER BY log_id DESC LIMIT 1)
    ORDER BY source_id, sheet;

**Bronze is done when** a single command loads all 10 sources into 11 raw tables. Each `row_count` must match the table above, and a second run must report every source as `skipped`.

### B. Source Profiling (findings → silver tests)

Before building Silver, every source file was profiled in [`notebooks/00_source_exploration.ipynb`](notebooks/00_source_exploration.ipynb): row counts, data types, null rates, candidate keys and an automatic foreign-key scan across all files. The findings are listed in [`docs/data_issues.md`](docs/data_issues.md), each with its count, the notebook cell it comes from, how Silver will handle it and the dbt test that will guard it. Every count is now proven: 13 SQL scripts in [`sql/profiling/`](sql/profiling/) run against the raw tables (batch `cdaee7385083`), and the rest come from saved notebook outputs. All 19 findings are verified. The scripts prove the grain (SRC01 and SRC05 unique on `order_id` + `product_id`), the foreign keys, the data period (`dim_date` must reach 2025-01-02) and the issues the Silver layer has to handle: 547 sales after the resign date, 4,192 off-territory lines (all caused by customers still mapped to resigned reps), 85 territory rows not updated for the July transfers, the half-to-even rounding of `discount_amount`, three line-level fields in SRC01, the 145-row promotion × product bridge and the 48 overlapping target rows. Where the data allows more than one reading, the rule is recorded in [`docs/assumptions_log.md`](docs/assumptions_log.md): A-DQ08 (resign date) is decided, A-DQ18 (target rows of resigned employees) is open. Each finding then becomes a dbt test in the Silver layer, so the checks run on every build instead of only once.

### C. Silver Layer

#### Plain-SQL baseline (before dbt)

To show what dbt replaces, the first staging model is built by hand in [`sql/silver/`](sql/silver/):

- [`stg_sales_transactions.sql`](sql/silver/stg_sales_transactions.sql) creates the view `staging.stg_sales_transactions` from `raw.src01_sales_transactions`. It is a chain of commented CTEs (explicit select, fake nulls to `NULL`, casts, trim and Unicode NFC, dedup on `order_id` + `product_id`, drop derived and dimension columns, `is_post_resign_sale`). Each step cites its issue in [`docs/data_issues.md`](docs/data_issues.md). The header states the contract: 119,101 rows, net 158,957,563,200 VND, money as `numeric(18,2)`.
- Amounts follow DQ14: `gross_amount` is recomputed as `quantity * unit_price`; the stored `discount_amount` and `net_amount` are kept, because the source rounds the discount half-to-even to 100 VND and net must reconcile to raw.
- [`tests/`](sql/silver/tests/) holds 13 tests, one file each. Like dbt tests, each returns its failing rows (0 rows = pass): PK not null and unique, 3 FKs, quantity > 0, accepted values for the 3 line-level fields (DQ15), net = gross − discount, row count, net total and the 547 post-resign flags (A-DQ08).
- `bash sql/silver/run_tests.sh` or `powershell -ExecutionPolicy Bypass -File sql/silver/run_tests.ps1` rebuilds the view and prints `PASS` / `FAIL` per file. Result on 2026-11-28: 13 of 13 pass.

What this costs compared with dbt (run order, lineage, copy-paste tests, two runners, no docs) is listed in [`docs/pain_points.md`](docs/pain_points.md). From the next model on, Silver is built in dbt.
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