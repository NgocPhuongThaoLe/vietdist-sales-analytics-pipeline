-- DQ06 – FK: distributor -> supervisor
-- Question: does every SRC06.assigned_supervisor_id exist in SRC07 (employee master),
--           and is that employee a supervisor who is still employed?
-- Run:  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/profiling/fk_distributor_supervisor.sql
-- Pass: orphan_distributors = 0

-- 1. Orphans (supervisor id not found in either employee version)
SELECT
    count(*)                                                    AS distributors,
    count(DISTINCT d.assigned_supervisor_id)                    AS distinct_supervisors,
    count(*) FILTER (WHERE d.assigned_supervisor_id IS NULL)    AS null_supervisor,
    count(*) FILTER (WHERE d.assigned_supervisor_id IS NOT NULL
                       AND NOT EXISTS (SELECT 1 FROM raw.src07_employee_master e
                                       WHERE e.employee_id = d.assigned_supervisor_id))
                                                                AS orphan_distributors
FROM raw.src06_distributor_master d;

-- 2. Who the supervisors are, per employee version (position, status, resign date)
SELECT
    e._sheet_name,
    e.employee_id,
    e.position,
    e.status,
    e.resign_date,
    count(*) AS distributors_assigned
FROM raw.src06_distributor_master d
JOIN raw.src07_employee_master e ON e.employee_id = d.assigned_supervisor_id
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1, 2;
