-- DQ10 – Customers with no territory mapping vs customer status
-- Question: are the 157 customers missing from SRC08 the same as the 157 'Inactive' customers in SRC03?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/unmapped_customers.sql
-- Pass: read the counts. Same set if inactive_and_unmapped = unmapped = inactive.
-- status values (checked 2026-11-28): 'Active', 'Inactive'.

WITH c AS (
    SELECT
        c.customer_id,
        c.status,
        EXISTS (SELECT 1 FROM raw.src08_territory_mapping m
                WHERE m.customer_id = c.customer_id)              AS is_mapped,
        EXISTS (SELECT 1 FROM raw.src01_sales_transactions s
                WHERE s.customer_id = c.customer_id)              AS has_sales
    FROM raw.src03_customer_master c
)
SELECT
    count(*)                                                        AS customers,
    count(*) FILTER (WHERE NOT is_mapped)                           AS unmapped,
    count(*) FILTER (WHERE status = 'Inactive')                     AS inactive,
    count(*) FILTER (WHERE status = 'Inactive' AND NOT is_mapped)   AS inactive_and_unmapped,
    count(*) FILTER (WHERE status = 'Inactive' AND is_mapped)       AS inactive_but_mapped,
    count(*) FILTER (WHERE status = 'Active'   AND NOT is_mapped)   AS active_but_unmapped,
    count(*) FILTER (WHERE NOT is_mapped AND has_sales)             AS unmapped_with_sales,
    count(*) FILTER (WHERE NOT has_sales)                           AS customers_without_sales,
    count(*) FILTER (WHERE status = 'Inactive' AND NOT has_sales)   AS inactive_without_sales
FROM c;
