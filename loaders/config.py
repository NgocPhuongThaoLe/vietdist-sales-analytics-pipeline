"""
Central configuration for the VietDist raw loaders.
"""

# Imports
import os
from pathlib import Path
from dotenv import load_dotenv

# Paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

# RAW_DATA_DIR in .env may be relative to the project root
DATA_RAW_DIR = (PROJECT_ROOT / os.getenv("RAW_DATA_DIR", "data/raw")).resolve()
LOG_DIR = PROJECT_ROOT / "logs"
INIT_DB_SQL = PROJECT_ROOT / "docker" / "postgres" / "init_db.sql"

# Database connection
DB = {
    # "localhost" from your machine; the service name (e.g. "postgres")
    # when running inside Docker/Airflow later. Set it in .env.
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": int(os.getenv("POSTGRES_PORT", "5433")),
    "dbname": os.getenv("POSTGRES_DB", "vietdist"),
    "user": os.getenv("POSTGRES_USER", "vietdist_admin"),
    "password": os.getenv("POSTGRES_PASSWORD"),
}


# Schemas
SCHEMA_RAW = "raw"
SCHEMA_STAGING = "staging"
SCHEMA_DWH = "dwh"


# Raw-layer conventions
READ_AS_TEXT = True         # leading zeros, no float conversion; cast in dbt staging
CSV_ENCODING = "utf-8-sig"  # Vietnamese text, BOM
# Empty cells are stored as NULL. Text such as "NA" or "null" is kept as text.


# Metadata columns
META_COLS = {
    "row_number": "_row_number",  # row in the source file/sheet (header = row 1)
    "source_file": "_source_file",
    "sheet_name": "_sheet_name",  # NULL for CSV
    "loaded_at": "_loaded_at",
    "batch_id": "_batch_id",
    "file_hash": "_file_hash",
}

INGEST_LOG_TABLE = f"{SCHEMA_RAW}.ingest_log"  # one row per file/sheet loaded.


# Source registry
# For xlsx: "sheets" maps the EXACT sheet name in the file -> target raw table.
# Sheets not listed here are skipped (e.g. Summary / Category_Summary).
# Several sheets may point to the same table (versions are unioned;
# _sheet_name tells them apart).
SOURCES = [
    {
        "source_id": "SRC01",
        "file": "SRC01_sales_transactions.csv",
        "format": "csv",
        "table": "src01_sales_transactions",
    },
    {
        "source_id": "SRC02",
        "file": "SRC02_sales_target_plan.xlsx",
        "format": "xlsx",
        "sheets": {
            "Plan_v1_Original": "src02_sales_target",       # full year, months 1-12
            "Plan_v2_Adjustment_H2": "src02_sales_target",  # H2 re-plan, months 7-12
            # "Summary" skipped
        },
    },
    {
        "source_id": "SRC03",
        "file": "SRC03_customer_master.csv",
        "format": "csv",
        "table": "src03_customer_master",
    },
    {
        "source_id": "SRC04",
        "file": "SRC04_product_master.xlsx",
        "format": "xlsx",
        "sheets": {
            "Products": "src04_product_master",
            # "Category_Summary" skipped
        },
    },
    {
        "source_id": "SRC05",
        "file": "SRC05_distributor_orders.xlsx",
        "format": "xlsx",
        "sheets": {
            "Orders": "src05_distributor_orders",
        },
    },
    {
        "source_id": "SRC06",
        "file": "SRC06_distributor_master.csv",
        "format": "csv",
        "table": "src06_distributor_master",
    },
    {
        "source_id": "SRC07",
        "file": "SRC07_employee_master.xlsx",
        "format": "xlsx",
        "sheets": {
            "Employee_v1_StartYear": "src07_employee_master",   # effective 2024-01-01
            "Employee_v2_Adjustment": "src07_employee_master",  # effective 2024-07-01
            "Change_Log": "src07_employee_change_log",
        },
    },
    {
        "source_id": "SRC08",
        "file": "SRC08_territory_mapping.xlsx",
        "format": "xlsx",
        "sheets": {
            "Sheet1": "src08_territory_mapping",  # single version (v1)
        },
    },
    {
        "source_id": "SRC09",
        "file": "SRC09_return_transactions.csv",
        "format": "csv",
        "table": "src09_return_transactions",
    },
    {
        "source_id": "SRC10",
        "file": "SRC10_promotion_program.xlsx",
        "format": "xlsx",
        "sheets": {
            "Sheet1": "src10_promotion_program",
        },
    },
]