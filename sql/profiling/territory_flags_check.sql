-- A-DQ09 – Territory flags under the decided rule (checked on the staging views, not raw)
-- Rule: a territory mapping ends at the mapped rep's resign date; revenue is credited to the selling rep.
--   is_off_territory       = mapping active on the order date
--                            (mapped rep never resigned, or order_date <= mapped rep's resign_date)
--                            AND mapped rep <> selling rep                      expected 0
--   is_unassigned_customer = the customer's mapped rep resigned before the order date
--                            (order_date > resign_date), regardless of who sold  expected 4,739
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/territory_flags_check.sql
--       (needs the dbt staging views: dbt build -s staging)
-- Pass: off_territory_lines = 0, unassigned_customer_lines = 4739 (6,361,734,300 VND),
--       unassigned_sold_by_other_rep = 4192 (the DQ09 lines), unassigned_sold_by_mapped_rep = 547 (the DQ08 lines)
-- resign_date comes from stg_employees v2 (A-DQ08).

WITH resigned AS (
    SELECT employee_id, resign_date
    FROM staging.stg_employees
    WHERE employee_version = 'v2'
      AND resign_date IS NOT NULL
),
lines AS (
    SELECT
        s.order_id,
        s.product_id,
        s.order_date,
        s.employee_id                       AS selling_employee_id,
        s.net_amount,
        m.employee_id                       AS mapped_employee_id,
        r.resign_date                       AS mapped_rep_resign_date
    FROM staging.stg_sales_transactions s
    LEFT JOIN staging.stg_territory_mapping m ON m.customer_id = s.customer_id
    LEFT JOIN resigned r                      ON r.employee_id = m.employee_id
),
flags AS (
    SELECT
        *,
        mapped_employee_id IS NOT NULL
            AND (mapped_rep_resign_date IS NULL OR order_date <= mapped_rep_resign_date)   AS mapping_active,
        mapped_rep_resign_date IS NOT NULL
            AND order_date > mapped_rep_resign_date                                         AS is_unassigned_customer
    FROM lines
)
SELECT
    count(*)                                                                        AS lines,
    count(*) FILTER (WHERE mapped_employee_id IS NOT NULL)                          AS lines_with_mapping,
    count(*) FILTER (WHERE mapped_employee_id <> selling_employee_id)               AS seller_differs_from_mapped_rep,
    count(*) FILTER (WHERE mapping_active AND mapped_employee_id <> selling_employee_id)
                                                                                    AS off_territory_lines,
    count(*) FILTER (WHERE is_unassigned_customer)                                  AS unassigned_customer_lines,
    sum(net_amount) FILTER (WHERE is_unassigned_customer)                           AS unassigned_customer_net_vnd,
    count(*) FILTER (WHERE is_unassigned_customer
                       AND mapped_employee_id = selling_employee_id)                AS unassigned_sold_by_mapped_rep,
    count(*) FILTER (WHERE is_unassigned_customer
                       AND mapped_employee_id <> selling_employee_id)               AS unassigned_sold_by_other_rep
FROM flags;

-- 2. The 196 customers mapped to a resigned rep (dbt test warn_stg_territory_mapping_resigned_rep)
--    vs the 178 customers on the 4,192 DQ09 lines: what each of them bought after the resign date.
--    Pass: mapped_to_resigned = 196 = bought_from_other_after_resign (178)
--          + only_from_resigned_rep_after (2) + no_purchase_after_resign (16)
WITH resigned AS (
    SELECT employee_id, resign_date
    FROM staging.stg_employees
    WHERE employee_version = 'v2' AND resign_date IS NOT NULL
),
c AS (
    SELECT
        m.customer_id,
        EXISTS (SELECT 1 FROM staging.stg_sales_transactions s WHERE s.customer_id = m.customer_id
                AND s.order_date > r.resign_date AND s.employee_id <> m.employee_id)       AS other_after,
        EXISTS (SELECT 1 FROM staging.stg_sales_transactions s WHERE s.customer_id = m.customer_id
                AND s.order_date > r.resign_date AND s.employee_id = m.employee_id)        AS mapped_after,
        EXISTS (SELECT 1 FROM staging.stg_sales_transactions s WHERE s.customer_id = m.customer_id
                AND s.order_date > r.resign_date)                                          AS any_after,
        EXISTS (SELECT 1 FROM staging.stg_sales_transactions s WHERE s.customer_id = m.customer_id)
                                                                                           AS any_sale
    FROM staging.stg_territory_mapping m
    JOIN resigned r ON r.employee_id = m.employee_id
)
SELECT
    count(*)                                                    AS mapped_to_resigned,
    count(*) FILTER (WHERE other_after)                         AS bought_from_other_after_resign,
    count(*) FILTER (WHERE mapped_after)                        AS bought_from_resigned_rep_after_resign,
    count(*) FILTER (WHERE mapped_after AND NOT other_after)    AS only_from_resigned_rep_after,
    count(*) FILTER (WHERE NOT any_after)                       AS no_purchase_after_resign,
    count(*) FILTER (WHERE NOT any_sale)                        AS no_sales_at_all
FROM c;
