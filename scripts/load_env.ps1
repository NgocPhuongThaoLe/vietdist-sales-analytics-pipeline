# Load .env into the current PowerShell session (needed by dbt, which does not read .env).
# Run from the project root, dot-sourced:  . .\scripts\load_env.ps1
$envFile = Join-Path (Get-Location) ".env"
if (-not (Test-Path $envFile)) {
    Write-Error ".env not found in $(Get-Location). Run from the project root, or copy .env.example to .env first."
    return
}
Get-Content $envFile | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
    $name, $value = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim(), "Process")
}
Write-Host "Loaded .env into this session."
