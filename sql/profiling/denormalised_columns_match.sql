-- DQ14 / DQ20 – Denormalised columns in the fact files vs their master tables
-- Question: staging drops region / province / channel / product_category from SRC01 and region /
--           channel / product_category from SRC05, because Gold takes them from dim_customers,
--           dim_distributors and dim_products. Do the stored copies equal the master values?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/denormalised_columns_match.sql
-- Pass: every *_mismatch = 0 (then dropping the copies loses no information)

-- 1. SRC01 sales lines vs SRC03 customers and SRC04 products
SELECT
    count(*)                                                    AS src01_lines,
    count(c.customer_id)                                        AS with_customer,
    count(p.product_id)                                         AS with_product,
    count(*) FILTER (WHERE s.region   IS DISTINCT FROM c.region)    AS region_mismatch,
    count(*) FILTER (WHERE s.province IS DISTINCT FROM c.province)  AS province_mismatch,
    count(*) FILTER (WHERE s.channel  IS DISTINCT FROM c.channel)   AS channel_mismatch,
    count(*) FILTER (WHERE s.product_category IS DISTINCT FROM p.category) AS category_mismatch
FROM raw.src01_sales_transactions s
LEFT JOIN raw.src03_customer_master c ON c.customer_id = s.customer_id
LEFT JOIN raw.src04_product_master  p ON p.product_id  = s.product_id;

-- 2. SRC05 distributor order lines vs SRC06 distributors and SRC04 products
SELECT
    count(*)                                                    AS src05_lines,
    count(x.distributor_id)                                     AS with_distributor,
    count(p.product_id)                                         AS with_product,
    count(*) FILTER (WHERE d.region  IS DISTINCT FROM x.region)     AS region_mismatch,
    count(*) FILTER (WHERE d.channel IS DISTINCT FROM x.channel)    AS channel_mismatch,
    count(*) FILTER (WHERE d.product_category IS DISTINCT FROM p.category) AS category_mismatch
FROM raw.src05_distributor_orders d
LEFT JOIN raw.src06_distributor_master x ON x.distributor_id = d.distributor_id
LEFT JOIN raw.src04_product_master     p ON p.product_id     = d.product_id;
