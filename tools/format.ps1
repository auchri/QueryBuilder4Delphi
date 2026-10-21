param(
    [string]$Formatter = (Get-Command Formatter.exe -ErrorAction Stop).Source,
    [string]$Config
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Config) {
    $Config = Join-Path (Split-Path -Parent $Formatter) 'config/Formatter_Default.config'
}
if (-not (Test-Path -LiteralPath $Config)) {
    throw "Formatter profile not found: $Config"
}
# Only immediate source/test files; leave build outputs and IDE history alone.
$files = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src'), (Join-Path $repoRoot 'test') -File |
    Where-Object { $_.Extension -in '.pas', '.dpr' } |
    Sort-Object FullName
& $Formatter -delphi -config $Config @($files.FullName)
if ($LASTEXITCODE -ne 0) { throw "Formatter failed (exit code $LASTEXITCODE)." }
