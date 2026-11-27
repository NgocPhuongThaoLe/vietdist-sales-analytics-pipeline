# Imports
from __future__ import annotations
import logging
from pathlib import Path
import pandas as pd
from config import CSV_ENCODING, META_COLS, READ_AS_TEXT
logger = logging.getLogger(__name__)

# Shared settings
# Read options shared by CSV and Excel.
# keep_default_na=False: text such as "NA" or "null" stays text. Only truly
# empty cells become NULL (see _tidy).
_READ_OPTS = {
    "dtype": str if READ_AS_TEXT else None,
    "keep_default_na": False,
}

ROW_NUMBER = META_COLS["row_number"]


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

    frames = {sheet: _tidy(df, cfg["source_id"], sheet) for sheet, df in frames.items()}

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


# Helpers
# Light clean-up that does NOT change any cell values
def _tidy(df: pd.DataFrame, source_id: str, sheet: str | None) -> pd.DataFrame:
    # Make a copy -> original table is not changed
    df = df.copy()
    # Remove extra spaces around column names ("customer_id " -> "customer_id")
    df.columns = [str(c).strip() for c in df.columns]
    # Empty cells -> NULL. CSV gives "" for an empty field, Excel gives NaN.
    df = df.mask(df.eq(""))
    # Row position in the source, header = row 1, so the first data row = 2.
    # Set before dropping empty rows, so the numbers still match the file.
    df.insert(0, ROW_NUMBER, range(2, len(df) + 2))

    # Remove rows where every cell is empty
    data_cols = [c for c in df.columns if c != ROW_NUMBER]
    empty_rows = df[data_cols].isna().all(axis=1)
    if empty_rows.any():
        logger.info("%s %s: dropped %d empty row(s)",
                    source_id, sheet or "-", int(empty_rows.sum()))
    df = df.loc[~empty_rows]

    # Find columns named "Unnamed: ..." (no header) that are completely empty
    empty_unnamed = [c for c in data_cols
                     if c.startswith("Unnamed:") and df[c].isna().all()]
    # Remove those columns
    df = df.drop(columns=empty_unnamed)

    # Renumber the rows from 0 and return the table
    return df.reset_index(drop=True)


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
        ("SRC02", "Plan_v1_Original"): 1_332,
        ("SRC02", "Plan_v2_Adjustment_H2"): 618,
        ("SRC03", None): 2_000,
        ("SRC04", "Products"): 100,
        ("SRC05", "Orders"): 35_945,
        ("SRC06", None): 138,
        ("SRC07", "Employee_v1_StartYear"): 114,
        ("SRC07", "Employee_v2_Adjustment"): 114,
        ("SRC07", "Change_Log"): 13,
        ("SRC08", "Sheet1"): 1_843,
        ("SRC09", None): 3_665,
        ("SRC10", "Sheet1"): 40,
    }

    # Only ID-like columns must never look like floats (leading zeros matter).
    # Amount columns such as "15000.0" are fine as text -> cast in dbt.
    ID_LIKE = ("id", "code", "phone", "tax")

    # Counter for tables with problems
    problems = 0
    # Loop over every source in the config
    for cfg in SOURCES:
        # Read the file for this source
        frames = read_source(DATA_RAW_DIR / cfg["file"], cfg)
        # Loop over every table (sheet) that was read
        for sheet, df in frames.items():
            # Key to look up the expected row count, e.g. ("SRC02", "Plan_v1_Original")
            key = (cfg["source_id"], sheet)
            data_cols = [c for c in df.columns if c != ROW_NUMBER]

            # Check 1: find columns that are NOT text (they should all be text)
            not_text = [c for c in data_cols
                        if not pd.api.types.is_string_dtype(df[c])]
            # Check 2: find columns with values like "912345678.0" (sign it was read as a float)
            #   only for ID-like columns (customer_id, tax_code, phone...)
            float_like = [c for c in data_cols
                          if any(w in c.lower() for w in ID_LIKE)
                          and df[c].str.fullmatch(r"\d+\.0", na=False).any()]
            # Check 3: does the row count match the expected count?
            #   no expected value (e.g. sheet renamed in config) -> CHECK, not silently OK
            exp = EXPECTED.get(key)
            count_ok = exp is not None and len(df) == exp

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
