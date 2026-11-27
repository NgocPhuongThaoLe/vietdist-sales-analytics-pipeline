-- DQ17 – SRC10 applicable_products holds several product ids in one cell ('|'-separated)
-- Question: how many products does each promotion cover, and does every split product id
--           exist in SRC04 (product master)? This is the future bridge_promotion_product.
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/promotion_products.sql
-- Pass: orphan_product_ids = 0, empty_parts = 0, duplicate_pairs = 0
-- Split on '|' and trim each part (raw has no spaces today, trim guards the bridge anyway).

WITH bridge AS (
    SELECT
        p.promotion_id,
        trim(x.product_id)      AS product_id
    FROM raw.src10_promotion_program p
    CROSS JOIN LATERAL unnest(string_to_array(p.applicable_products, '|')) AS x(product_id)
),
per_promo AS (
    SELECT promotion_id, count(*) AS products
    FROM bridge
    GROUP BY promotion_id
)

-- 1. Promotions by number of products in applicable_products
SELECT
    products            AS products_per_promotion,
    count(*)            AS promotions
FROM per_promo
GROUP BY products
ORDER BY products;

-- 2. Summary of the split and FK check against SRC04
WITH bridge AS (
    SELECT
        p.promotion_id,
        trim(x.product_id)      AS product_id
    FROM raw.src10_promotion_program p
    CROSS JOIN LATERAL unnest(string_to_array(p.applicable_products, '|')) AS x(product_id)
)
SELECT
    (SELECT count(*) FROM raw.src10_promotion_program)                          AS promotions,
    (SELECT count(*) FROM raw.src10_promotion_program
      WHERE applicable_products LIKE '%|%')                                     AS promotions_with_more_than_one_product,
    (SELECT count(*) FROM raw.src10_promotion_program
      WHERE applicable_products IS NULL)                                        AS null_applicable_products,
    count(*)                                                                    AS bridge_rows,
    count(*) FILTER (WHERE product_id = '')                                     AS empty_parts,
    count(*) - count(DISTINCT (promotion_id, product_id))                       AS duplicate_pairs,
    count(DISTINCT product_id)                                                  AS distinct_products,
    count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM raw.src04_product_master m
                                       WHERE m.product_id = bridge.product_id)) AS orphan_product_ids
FROM bridge;
