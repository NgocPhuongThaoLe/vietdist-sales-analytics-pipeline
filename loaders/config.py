"""
Central configuration for the VietDist raw loaders.
"""

# imports 
import os
from pathlib import Path 
from dotenv import load_dotenv

# Paths
PROJECT_ROOT = Path(__file__).resolve().parent
DATA_RAW_DIR = PROJECT_ROOT/"data"/"raw"
LOG_DIG = PROJECT_ROOT/"logs"

load_dotenv(PROJECT_ROOT/".env")

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
READ_AS_TEXT = True # leading zeros, no float conversion; cast in dbt staging
CSV_ENCODING = "utf-8-sig" # Vietnamese text, BOM
LOAD_MODE = "replace"


# Metadata columns
META_COLS = {
    "source_file": "_source_file",
    "sheet_name": "_sheet_name",
    "loaded_at": "_loaded_at",
    "batch_id": "_batch_id",
    "file_hash": "_file_hash",
}

INGEST_LOG_TABLE = f"{SCHEMA_RAW}.ingest_log" # one row per file/sheet loaded.

# Source registry

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
            "v1": "src02_sales_target",  
            "v2": "src02_sales_target",  
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
            "v1": "src07_employee_master",          
            "v2": "src07_employee_master",         
            "Change_Log": "src07_employee_change_log",
        },
    },
    {
        "source_id": "SRC08",
        "file": "SRC08_territory_mapping.xlsx",
        "format": "xlsx",
        "sheets": {
            "v1": "src08_territory_mapping",  
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
            "Promotions": "src10_promotion_program",  
        },
    },
]