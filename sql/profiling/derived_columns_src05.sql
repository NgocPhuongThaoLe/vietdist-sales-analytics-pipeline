-- DQ20 – Derived columns stored in SRC05 (distributor orders)
-- Question: do the stored derived columns equal the values recomputed from their base columns?
--   order_month / order_quarter  vs  extract(month / quarter) from order_date
--   fill_rate_pct                vs  qty_delivered / qty_ordered * 100        (tolerance 0.01)
--   gross_amount                 vs  qty_ordered   * distributor_price        (tolerance 1 VND)
--   delivered_amount             vs  qty_delivered * distributor_price        (tolerance 1 VND)
--   ontime_delivery              vs  actual_delivery_date <= expected_delivery_date
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/derived_columns_src05.sql
-- Pass: every *_mismatch = 0 and null_base_rows = 0
-- ontime_delivery values (checked 2026-11-28): 'Yes', 'No'. actual_delivery_date is never NULL
-- (also on 'Cancelled' lines), so no NULL coding is needed.
-- Raw is text: amounts and percentages cast to numeric (never float), quantities to int, dates to date.

WITH base AS (
    SELECT
        order_id,
        product_id,
        _row_number,
        order_date::date                    AS order_date,
        order_month::int                    AS order_month,
        order_quarter::int                  AS order_quarter,
        qty_ordered::int                    AS qty_ordered,
        qty_delivered::int                  AS qty_delivered,
        fill_rate_pct::numeric              AS fill_rate_pct,
        distributor_price::numeric          AS distributor_price,
        gross_amount::numeric               AS gross_amount,
        delivered_amount::numeric           AS delivered_amount,
        expected_delivery_date::date        AS expected_delivery_date,
        actual_delivery_date::date          AS actual_delivery_date,
        ontime_delivery,
        delivery_status
    FROM raw.src05_distributor_orders
),
recomputed AS (
    SELECT
        b.*,
        extract(month   FROM order_date)::int                           AS calc_month,
        extract(quarter FROM order_date)::int                           AS calc_quarter,
        qty_delivered::numeric / nullif(qty_ordered, 0) * 100           AS calc_fill_rate,
        qty_ordered   * distributor_price                               AS calc_gross,
        qty_delivered * distributor_price                               AS calc_delivered,
        CASE WHEN actual_delivery_date <= expected_delivery_date
             THEN 'Yes' ELSE 'No' END                                   AS calc_ontime
    FROM base b
)

-- 1. Mismatch count per derived column
SELECT
    count(*)                                                                AS total_rows,
    count(*) FILTER (WHERE order_date IS NULL OR qty_ordered IS NULL OR qty_delivered IS NULL
                        OR distributor_price IS NULL OR expected_delivery_date IS NULL
                        OR actual_delivery_date IS NULL OR ontime_delivery IS NULL)
                                                                            AS null_base_rows,
    count(*) FILTER (WHERE qty_ordered = 0)                                 AS zero_qty_ordered,
    count(*) FILTER (WHERE order_month   IS DISTINCT FROM calc_month)       AS order_month_mismatch,
    count(*) FILTER (WHERE order_quarter IS DISTINCT FROM calc_quarter)     AS order_quarter_mismatch,
    count(*) FILTER (WHERE abs(fill_rate_pct - calc_fill_rate) > 0.01)      AS fill_rate_pct_mismatch,
    count(*) FILTER (WHERE abs(gross_amount - calc_gross) > 1)              AS gross_amount_mismatch,
    count(*) FILTER (WHERE abs(delivered_amount - calc_delivered) > 1)      AS delivered_amount_mismatch,
    count(*) FILTER (WHERE ontime_delivery IS DISTINCT FROM calc_ontime)    AS ontime_delivery_mismatch,
    max(abs(fill_rate_pct - calc_fill_rate))                                AS fill_rate_max_abs_diff
FROM recomputed;

-- 2. ontime_delivery vs recomputed, and delivery facts per delivery_status
WITH b AS (
    SELECT
        delivery_status,
        ontime_delivery,
        qty_ordered::int                AS qty_ordered,
        qty_delivered::int              AS qty_delivered,
        order_date::date                AS order_date,
        expected_delivery_date::date    AS expected_delivery_date,
        actual_delivery_date::date      AS actual_delivery_date
    FROM raw.src05_distributor_orders
)
SELECT
    delivery_status,
    count(*)                                                                    AS lines,
    count(*) FILTER (WHERE ontime_delivery = 'Yes')                             AS ontime_yes,
    count(*) FILTER (WHERE actual_delivery_date <= expected_delivery_date)      AS calc_ontime_yes,
    count(*) FILTER (WHERE qty_delivered = 0)                                   AS qty_delivered_0,
    count(*) FILTER (WHERE qty_delivered = qty_ordered)                         AS fully_delivered,
    count(*) FILTER (WHERE qty_delivered > qty_ordered)                         AS delivered_more_than_ordered,
    count(*) FILTER (WHERE actual_delivery_date < order_date)                   AS actual_before_order,
    count(*) FILTER (WHERE expected_delivery_date < order_date)                 AS expected_before_order
FROM b
GROUP BY delivery_status
ORDER BY delivery_status;

-- 3. Pattern of the ontime_delivery mismatches: days late (actual - expected) vs stored flag
WITH b AS (
    SELECT
        ontime_delivery,
        actual_delivery_date::date - expected_delivery_date::date   AS days_late
    FROM raw.src05_distributor_orders
)
SELECT
    days_late,
    count(*)                                        AS lines,
    count(*) FILTER (WHERE ontime_delivery = 'Yes') AS stored_yes,
    count(*) FILTER (WHERE ontime_delivery = 'No')  AS stored_no,
    count(*) FILTER (WHERE ontime_delivery <> CASE WHEN days_late <= 0 THEN 'Yes' ELSE 'No' END)
                                                    AS mismatch
FROM b
GROUP BY days_late
ORDER BY days_late;
