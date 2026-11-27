#!/usr/bin/env bash
# Build staging.stg_sales_transactions, then run every test in sql/silver/tests/.
# Each test returns its failing rows: 0 rows = PASS (same convention as dbt).
# Run from the project root:  bash sql/silver/run_tests.sh
# Needs: docker compose with the postgres service up (credentials come from the container env).
set -u
cd "$(dirname "$0")/../.." || exit 1

psql_exec() {
    docker compose exec -T postgres sh -c 'psql -X -q -t -A -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
}

if ! psql_exec < sql/silver/stg_sales_transactions.sql >/dev/null; then
    echo "BUILD FAIL  stg_sales_transactions.sql"
    exit 1
fi
echo "BUILD OK    staging.stg_sales_transactions"

pass=0; fail=0
for f in sql/silver/tests/*.sql; do
    name=$(basename "$f")
    # Wrap the test as a subquery and count its rows (test files have no trailing semicolon)
    out=$( { printf 'SELECT count(*) FROM (\n'; cat "$f"; printf '\n) AS t;\n'; } | psql_exec 2>&1 )
    if [ $? -ne 0 ]; then
        echo "ERROR       $name: $out"; fail=$((fail + 1))
    elif [ "$out" = "0" ]; then
        echo "PASS        $name"; pass=$((pass + 1))
    else
        echo "FAIL        $name ($out failing rows)"; fail=$((fail + 1))
    fi
done
echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
