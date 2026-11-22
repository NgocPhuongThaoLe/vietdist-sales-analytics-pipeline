# VietDist Data Pipeline

## Summary
VietDist is an end-to-end data engineering and analytics project that runs locally.

The pipeline loads Excel and CSV files into PostgreSQL and processes the data through three layers: Bronze for raw data, Silver for cleaned and standardised data, and Gold for reporting-ready data. 

Power BI Desktop connects to the Gold layer to report on sales performance and distribution.

## Project Status


## Changelog
| Date | Version | Changes |
| --- | --- | --- |
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

This section covers required tools, repository structure, environment variables, PostgreSQL setup, and source file preparation.

### Quick start

If you already have Git, Docker Desktop and Python installed (commands shown for Windows PowerShell; macOS/Linux in comments):

```powershell
git clone https://github.com/<your-username>/vietdist-sales-pipeline.git
cd vietdist-sales-pipeline
copy .env.example .env                       # macOS/Linux: cp .env.example .env
docker compose up -d                         # starts PostgreSQL, creates schemas
python -m venv .venv
.venv\Scripts\activate                       # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
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
git clone https://github.com/<your-username>/vietdist-sales-pipeline.git
cd vietdist-sales-pipeline

python -m venv .venv
.venv\Scripts\activate          # Windows  (macOS/Linux: source .venv/bin/activate)
pip install -r requirements.txt
dbt --version                   # should show core 1.11+ and the postgres plugin
```

All commands in this README run from the project root (`vietdist-sales-pipeline/`) unless stated otherwise. dbt commands run from `vietdist_dbt/`.

---

### B. Repository Structure

```text
vietdist-sales-pipeline/
├── data/
│   └── raw/                        # Source files go here (git-ignored, see section E)
│       ├── .gitkeep                # Keeps the empty folder in Git
│       ├── SRC01_sales_transactions.csv
│       ├── ...
│       └── SRC10_promotion_program.xlsx
│
├── docker/
│   └── postgres/
│       └── init_db.sql             # Creates schemas raw, staging, dwh, snapshots + ingest_log + roles
│
├── loaders/                        # Layer 1 – Extract & Load (Python)
│   ├── config.py                   # Reads .env, maps each source file → raw table
│   ├── db.py                       # SQLAlchemy engine / connection helper
│   ├── load_raw.py                 # Loads all 10 sources into schema raw
│   └── ingest_log.py               # Writes one row per load to raw.ingest_log
│
├── vietdist_dbt/                   # Layers 2 & 3 – Transform (dbt Core)
│   ├── dbt_project.yml
│   ├── profiles.example.yml        # Template: copy to ~/.dbt/profiles.yml (no secrets, reads env vars)
│   ├── models/
│   │   ├── staging/                # 1 view per source (stg_*) + _sources.yml + _stg_models.yml
│   │   └── dwh/
│   │       ├── dims/               # 6 dimensions
│   │       ├── facts/              # 4 facts
│   │       ├── bridges/            # bridge_promotion_product
│   │       └── marts/              # 3 marts for Power BI
│   ├── snapshots/                  # dim_employee SCD Type 2
│   ├── tests/                      # Singular (custom SQL) tests
│   └── macros/
│       └── generate_schema_name.sql   # Uses schema names exactly as configured
│
├── notebooks/
│   └── 01_source_exploration.ipynb # Data profiling before modelling
│
├── scripts/
│   ├── load_env.sh                 # Loads .env into the shell (macOS/Linux)
│   └── load_env.ps1                # Loads .env into the shell (Windows PowerShell)
│
├── power_bi/
│   └── vietdist_report.pbix        # 3 report pages, imports from schema dwh
│
├── docs/
│   ├── architecture.png            # Three-layer architecture diagram
│   ├── data_dictionary.md
│   ├── data_issues.md
│   └── assumptions_log.md
│
├── images/                         # Screenshots used in README
│
├── run_pipeline.py                 # One command: load raw → dbt build
├── docker-compose.yml              # PostgreSQL service
├── requirements.txt                # Python + dbt dependencies
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
POSTGRES_PORT=5432
POSTGRES_DB=vietdist
POSTGRES_USER=vietdist_admin
POSTGRES_PASSWORD=change_me_please

# ---------- Loaders ----------
RAW_DATA_DIR=./data/raw
RAW_SCHEMA=raw
# full_refresh = truncate and reload each raw table, append = add rows (incremental loads)
LOAD_MODE=full_refresh

# ---------- dbt ----------
DBT_TARGET=dev
DBT_THREADS=4
```

> Keep comments on their own line. Docker Compose, `python-dotenv` and the shell scripts handle `VALUE  # comment` differently. Avoid spaces, quotes, `#` and `$` in values.

| Variable | Description | Default |
|---|---|---|
| `POSTGRES_HOST` | Database host. Use `127.0.0.1` rather than `localhost`: on Windows, `localhost` can resolve to IPv6 (`::1`) and reach a locally installed Postgres instead of the Docker container | `127.0.0.1` |
| `POSTGRES_PORT` | Host port mapped to the container. Change it to e.g. `5433` if Postgres is already installed on your machine (check with `Get-Service *postgres*` on Windows) | `5432` |
| `POSTGRES_DB` | Database name | `vietdist` |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | Admin user created when the container starts **for the first time** | – |
| `RAW_DATA_DIR` | Folder the loaders read source files from | `./data/raw` |
| `RAW_SCHEMA` | Target schema for Layer 1 | `raw` |
| `LOAD_MODE` | `full_refresh` truncates and reloads each raw table; `append` adds rows (used later for incremental loads) | `full_refresh` |
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
      port: "{{ env_var('POSTGRES_PORT', '5432') | as_number }}"
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

`scripts/load_env.ps1`:

```powershell
Get-Content .env | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
    $name, $value = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim())
}
```

`scripts/load_env.sh`:

```bash
set -a
source .env
set +a
```

The Python loaders do not need this step; they read `.env` directly with `python-dotenv`.

---

### D. PostgreSQL Setup

PostgreSQL runs in Docker, so there is nothing to install on your machine. On first start the container runs `docker/postgres/init_db.sql`, which creates the schemas, the ingest log and a read-only role.

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
      - "${POSTGRES_PORT}:5432"
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

Docker Compose fills in `${...}` from the `.env` file in the project root automatically. Inside the container Postgres always listens on `5432`; `POSTGRES_PORT` only changes the port on your machine.

**2. `docker/postgres/init_db.sql`:**

```sql
-- Three-layer architecture
CREATE SCHEMA IF NOT EXISTS raw;       -- Layer 1: Bronze (Python loaders)
CREATE SCHEMA IF NOT EXISTS staging;   -- Layer 2: Silver (dbt views)
CREATE SCHEMA IF NOT EXISTS dwh;       -- Layer 3: Gold  (dbt star schema + marts)
CREATE SCHEMA IF NOT EXISTS snapshots; -- dbt snapshot (dim_employee SCD2)

-- One row per file load, written by the Python loaders
CREATE TABLE IF NOT EXISTS raw.ingest_log (
    ingest_id      BIGSERIAL PRIMARY KEY,
    batch_id       UUID         NOT NULL,
    source_file    TEXT         NOT NULL,
    sheet_name     TEXT,
    target_table   TEXT         NOT NULL,
    rows_loaded    INTEGER,
    status         TEXT         NOT NULL CHECK (status IN ('success', 'failed')),
    error_message  TEXT,
    started_at     TIMESTAMPTZ  NOT NULL,
    finished_at    TIMESTAMPTZ
);

-- Read-only role for Power BI.
-- Local demo password: change it with ALTER ROLE if this database is ever shared.
CREATE ROLE powerbi_reader WITH LOGIN PASSWORD 'change_me_reader';
GRANT USAGE ON SCHEMA dwh TO powerbi_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA dwh GRANT SELECT ON TABLES TO powerbi_reader;
```

> The `powerbi_reader` password is a placeholder for a local demo with synthetic data. It is committed on purpose; real credentials never are.

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
| Port | value of `POSTGRES_PORT` (default `5432`) |
| Database | `vietdist` |
| User | `vietdist_admin` (full access) or `powerbi_reader` (read-only, schema `dwh`) |

In DBeaver, create the connection via **Database → New Database Connection → PostgreSQL** (not via *Edit Driver*, which changes the driver for every connection).

**Useful commands:**

| Command | What it does |
|---|---|
| `docker compose up -d` | Starts the database |
| `docker compose stop` | Stops the container, keeps the data |
| `docker compose down` | Removes the container, keeps the data (volume `pg_data`) |
| `docker compose down -v` | Removes the container **and all data** – `init_db.sql` runs again on next `up` |
| `docker compose logs -f postgres` | Follows the database log |

> `init_db.sql` only runs when the volume is empty. If you change it, run `docker compose down -v` and `docker compose up -d` to apply it.

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
1. Download `vietdist_sample_data.zip` from the [GitHub Release](https://github.com/<your-username>/vietdist-sales-pipeline/releases) page.
2. Extract it so the files sit directly in `data/raw/` (no sub-folder).
3. Do not rename the files – the loaders match them by name.

**2. Source files**

| ID | File | Format | Sheet(s) loaded | Rows | Raw table |
|---|---|---|---|---|---|
| SRC01 | `SRC01_sales_transactions.csv` | CSV | – | 119,101 lines (50,000 orders) | `raw.src01_sales_transactions` |
| SRC02 | `SRC02_sales_target_plan.xlsx` | XLSX | v1, v2 (skip `Summary`) | 1,332 + 618 | `raw.src02_sales_target_plan` |
| SRC03 | `SRC03_customer_master.csv` | CSV | – | 2,000 | `raw.src03_customer_master` |
| SRC04 | `SRC04_product_master.xlsx` | XLSX | Products (skip `Category_Summary`) | 100 | `raw.src04_product_master` |
| SRC05 | `SRC05_distributor_orders.xlsx` | XLSX | Orders | 35,945 lines (8,000 orders) | `raw.src05_distributor_orders` |
| SRC06 | `SRC06_distributor_master.csv` | CSV | – | 138 | `raw.src06_distributor_master` |
| SRC07 | `SRC07_employee_master.xlsx` | XLSX | v1, v2, Change_Log | 114 + 114 + 13 | `raw.src07_employee_master`, `raw.src07_employee_change_log` |
| SRC08 | `SRC08_territory_mapping.xlsx` | XLSX | Mapping | 1,843 | `raw.src08_territory_mapping` |
| SRC09 | `SRC09_return_transactions.csv` | CSV | – | 3,665 | `raw.src09_return_transactions` |
| SRC10 | `SRC10_promotion_program.xlsx` | XLSX | Promotions | 40 | `raw.src10_promotion_program` |

**3. Format rules the loaders follow**

| Rule | Detail |
|---|---|
| Encoding | CSV files are read as **UTF-8** (Vietnamese diacritics). Text is normalised to Unicode **NFC** in staging. |
| Delimiter | CSV uses comma `,`; first row is the header. |
| Excel | Only `.xlsx` is supported (read with `openpyxl`). Summary sheets (`Summary`, `Category_Summary`) are skipped. |
| Versioned sheets | SRC02 and SRC07 have `v1` / `v2` sheets. Both are loaded into the same raw table with a `_sheet_name` column; staging decides which version is used. |
| Data types in Raw | **Every column is loaded as `TEXT`** – nothing is cast in Layer 1. This keeps values such as `phone` and `tax_code` exactly as delivered; casting and cleaning happen in dbt staging. |
| Dates | Single format in the source (`YYYY-MM-DD`); parsed in staging. |
| Currency | Amounts are in **VND**, no decimals. |
| Column names | Converted to `snake_case` on load. |

**4. Metadata columns added to every raw table**

| Column | Type | Description |
|---|---|---|
| `_batch_id` | UUID | Same ID for all files in one run; joins to `raw.ingest_log.batch_id` |
| `_source_file` | TEXT | Original file name |
| `_sheet_name` | TEXT | Excel sheet (NULL for CSV) |
| `_row_number` | INTEGER | Row position in the source file, for tracing issues back |
| `_loaded_at` | TIMESTAMPTZ | Load timestamp |

**5. Known data issues**

The source data contains deliberate quality issues (lost leading zeros, unmapped customers, pipe-delimited lists, derived columns). How each one is detected and fixed is documented in [`docs/data_issues.md`](docs/data_issues.md).

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