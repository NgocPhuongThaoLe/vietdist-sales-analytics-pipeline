# Build staging.stg_sales_transactions, then run every test in sql/silver/tests/.
# Each test returns its failing rows: 0 rows = PASS (same convention as dbt).
# Run from the project root:  powershell -ExecutionPolicy Bypass -File sql/silver/run_tests.ps1
# Needs: docker compose with the postgres service up (credentials come from the container env).

# Windows PowerShell 5.1 pipes text to native programs as ASCII by default, which would turn
# Vietnamese literals ('Công nợ') into '?'. Force UTF-8 both ways.
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $root
$psql = 'psql -X -q -t -A -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'

$model = Get-Content -Raw -Encoding UTF8 "sql/silver/stg_sales_transactions.sql"
$null = $model | docker compose exec -T postgres sh -c $psql
if ($LASTEXITCODE -ne 0) {
    Write-Host "BUILD FAIL  stg_sales_transactions.sql"
    exit 1
}
Write-Host "BUILD OK    staging.stg_sales_transactions"

$pass = 0; $fail = 0
foreach ($f in Get-ChildItem "sql/silver/tests/*.sql" | Sort-Object Name) {
    # Wrap the test as a subquery and count its rows (test files have no trailing semicolon)
    $sql = "SELECT count(*) FROM (`n" + (Get-Content -Raw -Encoding UTF8 $f.FullName) + "`n) AS t;`n"
    $out = ($sql | docker compose exec -T postgres sh -c "$psql 2>&1") -join " "
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("ERROR       {0}: {1}" -f $f.Name, $out); $fail++
    } elseif ($out.Trim() -eq "0") {
        Write-Host ("PASS        {0}" -f $f.Name); $pass++
    } else {
        Write-Host ("FAIL        {0} ({1} failing rows)" -f $f.Name, $out.Trim()); $fail++
    }
}
Write-Host "----"
Write-Host "$pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }
