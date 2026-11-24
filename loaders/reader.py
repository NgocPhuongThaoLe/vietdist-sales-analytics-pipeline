# Imports
from __future__ import annotations
import logging
from pathlib import Path
import pandas as pd
from config import CSV_ENCODING, READ_AS_TEXT
logger = logging.getLogger(__name__)

# Shared settings
# Read options shared by CSV and Excel
_READ_OPTS = {
    "dtype": str if READ_AS_TEXT else None,
    "keep_default_na": False,
}

MONTH_COLS = [f"T{i}" for i in range(1, 13)]
TOTAL_WORDS = {"total", "tổng", "tổng cộng", "grand total"}


# Main Function
# takes a file path + its config, returns {sheet name: table}
def read_source(path, cfg):

    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"{cfg['source_id']}: file not found -> {path}")
    
    fmt = cfg["format"].lower()
    if fmt == "csv":
        frames = _read_csv(path)
    elif fmt == "xlsx":
        frames = _read_xlsx(path, cfg["sheets"])
    else:
        raise ValueError(f"{cfg['source_id']}: unsupported format '{cfg['format']}'")
    
    frames = {sheet: _tidy(df) for sheet, df in frames.items()}

    # SRC02 only
    if cfg["source_id"] == "SRC02":
        frames = {sheet: _melt_target(df, sheet) for sheet, df in frames.items()}

    # Log the number of rows and columns of each table, for checking
    for sheet, df in frames.items():
        logger.info("%s %-12s rows=%d cols=%d",
                    cfg["source_id"], sheet or "-", len(df), df.shape[1])
    
    return frames

# Read a CSV file
def _read_csv(path: Path) -> dict[None, pd.DataFrame]:
    # Read the CSV with the configured encoding + the shared read options
    df = pd.read_csv(path, encoding=CSV_ENCODING, **_READ_OPTS)
    return {None: df}

# Read an Excel file
def _read_xlsx(path: Path, sheets: dict[str, str]) -> dict[str, pd.DataFrame]:

    with pd.ExcelFile(path, engine="openpyxl") as xls:
        
        available = set(xls.sheet_names)
        wanted = list(sheets)

        missing = [s for s in wanted if s not in available]
        if missing:
            raise ValueError(
                f"{path.name}: sheet(s) {missing} not found. Available: {sorted(available)}"
            )

        skipped = sorted(available - set(wanted))
        # Log that these sheets were skipped
        if skipped:
            logger.info("%s: skipping sheet(s) not in config: %s", path.name, skipped)

        return {s: pd.read_excel(xls, sheet_name=s, **_READ_OPTS) for s in wanted}


# Heplpers
# Light clean-up that does NOT change any cell values
def _tidy(df: pd.DataFrame) -> pd.DataFrame:
    # Make a copy -> original table is not changed
    df = df.copy()
    # Remove extra spaces around column names ("customer_id " -> "customer_id")
    df.columns = [str(c).strip() for c in df.columns]
    # Any leftover empty values (NaN) -> empty text ""
    df = df.fillna("")
    # Remove rows where every cell is empty
    df = df.loc[~(df == "").all(axis=1)]

    # Find columns named "Unnamed: ..." (no header) that are completely empty
    empty_unnamed = [c for c in df.columns
                     if c.startswith("Unnamed:") and (df[c] == "").all()]
    # Remove those columns
    df = df.drop(columns=empty_unnamed)

    # Renumber the rows from 0 and return the table
    return df.reset_index(drop=True)


# Reshape the SRC02 target table: wide (one column per month) -> long (one row per month)
def _melt_target(df: pd.DataFrame, sheet: str | None) -> pd.DataFrame:
    # Lookup: column name in UPPER case -> original name (so "t1" also matches "T1")
    col_by_upper = {c.upper(): c for c in df.columns}
    # Keep only the month columns that really exist in the table
    month_cols = [col_by_upper[m] for m in MONTH_COLS if m in col_by_upper]
    # No month columns -> the table is already long, return it unchanged
    if not month_cols:
        logger.info("SRC02 %s: no T1..T12 columns -> already long, no melt", sheet)
        return df

    # Info columns (employee id, name...): not a month column, not a "Total" column
    id_cols = [c for c in df.columns
               if c not in month_cols and c.strip().lower() not in TOTAL_WORDS]

    # Mark rows that have "Tổng"/"Total" in any info column
    is_total_label = (
        df[id_cols].apply(lambda s: s.str.strip().str.lower().isin(TOTAL_WORDS)).any(axis=1)
    )
    # Mark rows where all info columns are empty (usually also a total row)
    has_no_id = (df[id_cols] == "").all(axis=1)
    # Count the total rows to remove (for the log)
    n_total = int((is_total_label | has_no_id).sum())
    # Remove the total rows
    df = df.loc[~(is_total_label | has_no_id)]

    # Reshape: each (employee x month) becomes one row
    #   column "month" holds the month name, column "target_amount" holds the target
    long = df.melt(id_vars=id_cols, value_vars=month_cols,
                   var_name="month", value_name="target_amount")
    # Remove the leading "T" from the month name: "T7" -> "7"
    long["month"] = long["month"].str.upper().str.removeprefix("T")
    # Remove rows with no target (v2 only has months 7-12, the rest are empty)
    long = long.loc[long["target_amount"].str.strip() != ""]

    # Log: how many months, how many total rows removed, how many rows left
    logger.info("SRC02 %s: melted %d months, dropped %d total row(s) -> %d rows",
                sheet, len(month_cols), n_total, len(long))
    # Renumber the rows and return the table
    return long.reset_index(drop=True)


# Test Run
# This part only runs when you type "python reader.py" directly,
# not when another file imports reader
if __name__ == "__main__":
    # Get the data folder and the list of 10 sources from config
    from config import DATA_RAW_DIR, SOURCES

    # Turn on logging so messages show on screen
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    # Expected row count for each (source, sheet), taken from the data profile
    EXPECTED = {
        ("SRC01", None): 119_101,
        ("SRC02", "v1"): 1_332,
        ("SRC02", "v2"): 618,
        ("SRC03", None): 2_000,
        ("SRC04", "Products"): 100,
        ("SRC05", "Orders"): 35_945,
        ("SRC06", None): 138,
        ("SRC07", "v1"): 114,
        ("SRC07", "v2"): 114,
        ("SRC07", "Change_Log"): 13,
        ("SRC08", "v1"): 1_843,
        ("SRC09", None): 3_665,
        ("SRC10", "Promotions"): 40,
    }

    # Counter for tables with problems
    problems = 0
    # Loop over every source in the config
    for cfg in SOURCES:
        # Read the file for this source
        frames = read_source(DATA_RAW_DIR / cfg["file"], cfg)
        # Loop over every table (sheet) that was read
        for sheet, df in frames.items():
            # Key to look up the expected row count, e.g. ("SRC02", "v1")
            key = (cfg["source_id"], sheet)

            # Check 1: find columns that are NOT text (they should all be text)
            not_text = [c for c in df.columns
                        if not pd.api.types.is_string_dtype(df[c])]
            # Check 2: find columns with values like "912345678.0" (sign it was read as a float)
            float_like = [c for c in df.columns
                          if df[c].str.fullmatch(r"\d+\.0").any()]
            # Check 3: does the row count match the expected count?
            exp = EXPECTED.get(key)
            count_ok = exp is None or len(df) == exp

            # Passed all 3 checks -> "OK", otherwise -> "CHECK"
            status = "OK" if not (not_text or float_like) and count_ok else "CHECK"
            # If not OK, add 1 to the counter (True counts as 1)
            problems += status != "OK"
            # Print the result as neatly aligned lines
            print(f"{status:5} {cfg['source_id']:6} {str(sheet):12} "
                  f"rows={len(df):>7} expected={exp} "
                  f"non_text={not_text or '-'} float_like={float_like or '-'}")

    # Print the total number of tables to check
    print(f"\n{problems} item(s) to check")