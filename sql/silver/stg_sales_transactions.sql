-- =====================================================================================
-- staging.stg_sales_transactions  (Silver, plain SQL – no dbt)
-- Source: raw.src01_sales_transactions (SRC01_sales_transactions.csv)
-- Run:    docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/silver/stg_sales_transactions.sql
--         PowerShell: Get-Content sql/silver/stg_sales_transactions.sql | docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
-- Tests:  sql/silver/run_tests.ps1  |  sql/silver/run_tests.sh
--
-- CONTRACT
--   Grain / PK : one row per order line, order_id + product_id (DQ01: 0 duplicates, 0 null keys)
--   Rows       : 119,101 (= raw; nothing is dropped)
--   Net amount : sum(net_amount) = 158,957,563,200 VND (= raw, dq08_resign_rule.sql query 3)
--   Types      : money numeric(18,2); quantity integer; ids text; order_date date
--
-- FIXES (step → issue in docs/data_issues.md)
--   3  fake nulls → NULL                     guard, no DQ ID (raw already stores blanks as NULL)
--   4  cast text → typed columns             DQ14 (amounts as numeric, never float), DQ19 (dates YYYY-MM-DD)
--   5  trim + NFC + upper-case id codes      guard, no DQ ID (README §I.C: NFC so joins match)
--   6  dedup on order_id + product_id        DQ01 (expected 0 rows removed)
--   7  drop derived + dimension columns      DQ14 (order_month/quarter/year recomputable; gross recomputed;
--                                            stored discount_amount and net_amount KEPT, see step 7)
--   8  is_post_resign_sale flag              DQ08 / A-DQ08 (547 lines flagged, never dropped)
--   line-level fields stay on the line       DQ15 (delivery_status, payment_method, payment_status)
-- =====================================================================================

CREATE OR REPLACE VIEW staging.stg_sales_transactions AS

-- 2. Explicit select from raw: no select *, names already snake_case; lineage columns kept
WITH source AS (
    SELECT
        order_id,
        order_date,
        order_month,
        order_quarter,
        order_year,
        customer_id,
        region,
        province,
        channel,
        employee_id,
        product_id,
        product_category,
        quantity,
        unit_price,
        discount_pct,
        discount_amount,
        gross_amount,
        net_amount,
        delivery_status,
        payment_method,
        payment_status,
        _row_number,
        _source_file,
        _loaded_at
    FROM raw.src01_sales_transactions
),

-- 3. Fake nulls: trim first, then '', 'nan', 'NaN', 'None' -> NULL (guard, no DQ ID)
--    Only the columns carried forward are cleaned; dropped columns (step 7) are not.
no_fake_nulls AS (
    SELECT
        CASE WHEN trim(order_id)        IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(order_id)        END AS order_id,
        CASE WHEN trim(order_date)      IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(order_date)      END AS order_date,
        CASE WHEN trim(customer_id)     IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(customer_id)     END AS customer_id,
        CASE WHEN trim(province)        IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(province)        END AS province,
        CASE WHEN trim(channel)         IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(channel)         END AS channel,
        CASE WHEN trim(employee_id)     IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(employee_id)     END AS employee_id,
        CASE WHEN trim(product_id)      IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(product_id)      END AS product_id,
        CASE WHEN trim(quantity)        IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(quantity)        END AS quantity,
        CASE WHEN trim(unit_price)      IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(unit_price)      END AS unit_price,
        CASE WHEN trim(discount_pct)    IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(discount_pct)    END AS discount_pct,
        CASE WHEN trim(discount_amount) IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(discount_amount) END AS discount_amount,
        CASE WHEN trim(net_amount)      IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(net_amount)      END AS net_amount,
        CASE WHEN trim(delivery_status) IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(delivery_status) END AS delivery_status,
        CASE WHEN trim(payment_method)  IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(payment_method)  END AS payment_method,
        CASE WHEN trim(payment_status)  IN ('', 'nan', 'NaN', 'None') THEN NULL ELSE trim(payment_status)  END AS payment_status,
        _row_number,
        _source_file,
        _loaded_at
    FROM source
),

-- 4. Cast types (DQ14: amounts like '908000.0' -> numeric(18,2), never float; DQ19: dates are YYYY-MM-DD)
--    discount_pct is a whole percent (2 = 2 %, DQ14) -> numeric(5,2), not money.
typed AS (
    SELECT
        order_id,
        order_date::date                    AS order_date,
        customer_id,
        province,
        channel,
        employee_id,
        product_id,
        quantity::integer                   AS quantity,
        unit_price::numeric(18,2)           AS unit_price,
        discount_pct::numeric(5,2)          AS discount_pct,
        discount_amount::numeric(18,2)      AS discount_amount,
        net_amount::numeric(18,2)           AS net_amount,
        delivery_status,
        payment_method,
        payment_status,
        _row_number,
        _source_file,
        _loaded_at
    FROM no_fake_nulls
),

-- 5. Standardise text: trim + Unicode NFC (guard, README §I.C); id codes upper-case.
--    Vietnamese values (province, payment_method) keep their diacritics and case.
standardised AS (
    SELECT
        upper(normalize(trim(order_id),    NFC))    AS order_id,
        order_date,
        upper(normalize(trim(customer_id), NFC))    AS customer_id,
        normalize(trim(province),        NFC)       AS province,
        normalize(trim(channel),         NFC)       AS channel,
        upper(normalize(trim(employee_id), NFC))    AS employee_id,
        upper(normalize(trim(product_id),  NFC))    AS product_id,
        quantity,
        unit_price,
        discount_pct,
        discount_amount,
        net_amount,
        normalize(trim(delivery_status), NFC)       AS delivery_status,
        normalize(trim(payment_method),  NFC)       AS payment_method,
        normalize(trim(payment_status),  NFC)       AS payment_status,
        _row_number,
        _source_file,
        _loaded_at
    FROM typed
),

-- 6. Dedup on the PK (DQ01: 0 duplicates expected, so 0 rows removed).
--    All rows share one _loaded_at per batch, so _row_number desc breaks ties deterministically.
deduped AS (
    SELECT *
    FROM (
        SELECT
            s.*,
            row_number() OVER (PARTITION BY order_id, product_id
                               ORDER BY _loaded_at DESC, _row_number DESC) AS _dedup_rank
        FROM standardised s
    ) ranked
    WHERE _dedup_rank = 1
),

-- 7. Drop derived and dimension columns (DQ14):
--    - order_month, order_quarter, order_year: recomputable from order_date (0 mismatches) -> dropped,
--      dim_date provides them.
--    - region, product_category: belong to dim_customers / dim_products -> dropped.
--    - gross_amount: recomputed as quantity * unit_price (0 mismatches with the stored value).
--    - discount_amount, net_amount: stored values KEPT. The stored discount is the exact discount
--      rounded half-to-even to 100 VND (13,971 rows differ from gross * pct / 100 by up to 50 VND),
--      net = gross - stored discount on every row, and net must reconcile to raw.
trimmed_columns AS (
    SELECT
        order_id,
        product_id,
        order_date,
        customer_id,
        employee_id,
        channel,
        province,
        quantity,
        unit_price,
        discount_pct,
        (quantity * unit_price)::numeric(18,2)      AS gross_amount,
        discount_amount,
        net_amount,
        delivery_status,
        payment_method,
        payment_status,
        _row_number,
        _source_file,
        _loaded_at
    FROM deduped
),

-- 8. is_post_resign_sale exactly as A-DQ08: order_date > resign_date (SRC07 Employee_v2_Adjustment).
--    The resign day counts as worked. Rows are flagged, never dropped (LEFT JOIN, expected 547 true).
resigned AS (
    SELECT
        upper(normalize(trim(employee_id), NFC))    AS employee_id,
        resign_date::date                           AS resign_date
    FROM raw.src07_employee_master
    WHERE _sheet_name = 'Employee_v2_Adjustment'
      AND resign_date IS NOT NULL
),

final AS (
    SELECT
        t.order_id,
        t.product_id,
        t.order_date,
        t.customer_id,
        t.employee_id,
        t.channel,
        t.province,
        t.quantity,
        t.unit_price,
        t.discount_pct,
        t.gross_amount,
        t.discount_amount,
        t.net_amount,
        t.delivery_status,
        t.payment_method,
        t.payment_status,
        coalesce(t.order_date > r.resign_date, false)   AS is_post_resign_sale,
        t._row_number,
        t._source_file,
        t._loaded_at
    FROM trimmed_columns t
    LEFT JOIN resigned r ON r.employee_id = t.employee_id
)

SELECT * FROM final;
