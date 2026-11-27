-- DQ14 – Derived columns stored in SRC01
-- Question: do the stored derived columns equal the values recomputed from their base columns?
--   order_month / order_quarter / order_year  vs  extract(...) from order_date
--   gross_amount                              vs  quantity * unit_price
--   discount_amount                           vs  gross_amount * discount_pct / 100
--   net_amount                                vs  gross_amount - discount_amount
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/derived_columns_src01.sql
-- Pass: every *_mismatch = 0 and null_base_rows = 0
-- discount_pct is a whole percent (values 0, 2, 5, 8, 10, 15), so 2 means 2 %.
-- Tolerance: amounts match if they differ by at most 1 VND. Date parts must match exactly.
-- Raw is text: amounts are cast to numeric (never float), date parts to int.

WITH base AS (
    SELECT
        order_id,
        product_id,
        _row_number,
        order_date::date                AS order_date,
        order_month::int                AS order_month,
        order_quarter::int              AS order_quarter,
        order_year::int                 AS order_year,
        quantity::numeric               AS quantity,
        unit_price::numeric             AS unit_price,
        discount_pct::numeric           AS discount_pct,
        gross_amount::numeric           AS gross_amount,
        discount_amount::numeric        AS discount_amount,
        net_amount::numeric             AS net_amount
    FROM raw.src01_sales_transactions
),
recomputed AS (
    SELECT
        b.*,
        extract(month   FROM order_date)::int          AS calc_month,
        extract(quarter FROM order_date)::int          AS calc_quarter,
        extract(year    FROM order_date)::int          AS calc_year,
        quantity * unit_price                          AS calc_gross,
        gross_amount * discount_pct / 100              AS calc_discount,
        gross_amount - discount_amount                 AS calc_net
    FROM base b
)

-- 1. Mismatch count per derived column
SELECT
    count(*)                                                                    AS total_rows,
    count(*) FILTER (WHERE order_date IS NULL OR quantity IS NULL OR unit_price IS NULL
                        OR discount_pct IS NULL OR gross_amount IS NULL
                        OR discount_amount IS NULL OR net_amount IS NULL)       AS null_base_rows,
    count(*) FILTER (WHERE order_month   IS DISTINCT FROM calc_month)           AS order_month_mismatch,
    count(*) FILTER (WHERE order_quarter IS DISTINCT FROM calc_quarter)         AS order_quarter_mismatch,
    count(*) FILTER (WHERE order_year    IS DISTINCT FROM calc_year)            AS order_year_mismatch,
    count(*) FILTER (WHERE abs(gross_amount    - calc_gross)    > 1)            AS gross_amount_mismatch,
    count(*) FILTER (WHERE abs(discount_amount - calc_discount) > 1)            AS discount_amount_mismatch,
    count(*) FILTER (WHERE abs(net_amount      - calc_net)      > 1)            AS net_amount_mismatch
FROM recomputed;

-- 2. Up to 10 example mismatches (one row per column that differs)
WITH base AS (
    SELECT
        order_id, product_id, _row_number,
        order_date::date AS order_date, order_month::int AS order_month,
        order_quarter::int AS order_quarter, order_year::int AS order_year,
        quantity::numeric AS quantity, unit_price::numeric AS unit_price,
        discount_pct::numeric AS discount_pct, gross_amount::numeric AS gross_amount,
        discount_amount::numeric AS discount_amount, net_amount::numeric AS net_amount
    FROM raw.src01_sales_transactions
),
mismatches AS (
              SELECT order_id, product_id, _row_number, 'order_month' AS col,
                     order_month::numeric AS stored, extract(month FROM order_date)::numeric AS recomputed
              FROM base WHERE order_month <> extract(month FROM order_date)
    UNION ALL SELECT order_id, product_id, _row_number, 'order_quarter',
                     order_quarter, extract(quarter FROM order_date)
              FROM base WHERE order_quarter <> extract(quarter FROM order_date)
    UNION ALL SELECT order_id, product_id, _row_number, 'order_year',
                     order_year, extract(year FROM order_date)
              FROM base WHERE order_year <> extract(year FROM order_date)
    UNION ALL SELECT order_id, product_id, _row_number, 'gross_amount',
                     gross_amount, quantity * unit_price
              FROM base WHERE abs(gross_amount - quantity * unit_price) > 1
    UNION ALL SELECT order_id, product_id, _row_number, 'discount_amount',
                     discount_amount, gross_amount * discount_pct / 100
              FROM base WHERE abs(discount_amount - gross_amount * discount_pct / 100) > 1
    UNION ALL SELECT order_id, product_id, _row_number, 'net_amount',
                     net_amount, gross_amount - discount_amount
              FROM base WHERE abs(net_amount - (gross_amount - discount_amount)) > 1
)
SELECT order_id, product_id, col, stored, recomputed, stored - recomputed AS diff
FROM mismatches
ORDER BY _row_number, col
LIMIT 10;

-- 3. Pattern of the discount_amount mismatches: is the stored value the exact discount
--    rounded to 100 VND? Two rounding modes are tested:
--      half_up   = Postgres round(x, -2)          (…50 goes up)
--      half_even = banker's rounding to 100 VND    (…50 goes to the even hundred, as Python round())
WITH d AS (
    SELECT
        discount_amount::numeric                                    AS stored,
        gross_amount::numeric * discount_pct::numeric / 100         AS exact
    FROM raw.src01_sales_transactions
),
r AS (
    SELECT
        stored,
        exact,
        round(exact, -2)                                            AS half_up,
        CASE WHEN exact / 100 - floor(exact / 100) = 0.5
             THEN (floor(exact / 100) + (floor(exact / 100)::bigint % 2)) * 100
             ELSE round(exact, -2)
        END                                                         AS half_even
    FROM d
)
SELECT
    count(*) FILTER (WHERE abs(stored - exact) > 1)                         AS mismatch_rows,
    max(abs(stored - exact))                                                AS max_abs_diff_vnd,
    sum(stored - exact)                                                     AS sum_diff_vnd,
    count(*) FILTER (WHERE stored % 100 <> 0)                               AS stored_not_multiple_of_100,
    count(*) FILTER (WHERE abs(stored - exact) > 1 AND stored = half_up)    AS mismatch_explained_half_up,
    count(*) FILTER (WHERE abs(stored - exact) > 1 AND stored = half_even)  AS mismatch_explained_half_even,
    count(*) FILTER (WHERE stored <> half_even)                             AS rows_not_equal_half_even
FROM r;
