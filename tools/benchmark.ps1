param(
  [ValidateSet('Win32','Win64')][string]$Platform = 'Win64',
  [ValidateRange(1,100)][int]$Processes = 3,
  [string]$Output
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $repoRoot "build/Benchmarks/$Platform/MappingBenchmarks.exe"
if (-not (Test-Path -LiteralPath $exe)) {
  throw 'Build benchmarks/MappingBenchmarks.dproj first (Delphi 12+, optimized Base configuration).'
}
if (-not $Output) { $Output = Join-Path $repoRoot "build/Benchmarks/$Platform/results.csv" }
$lines = [Collections.Generic.List[string]]::new()
foreach ($count in @(100,10000,100000)) {
  foreach ($method in @('list','stream')) {
    for ($processIndex = 1; $processIndex -le $Processes; $processIndex++) {
      # Fresh process per size/API: first call is genuinely cold metadata.
      $result = @(& $exe $count $method)
      if ($LASTEXITCODE -ne 0) { throw "Benchmark failed: $count $method" }
      if ($lines.Count -eq 0) { $lines.Add('process,' + $result[0]) }
      foreach ($line in $result[1..($result.Count - 1)]) { $lines.Add("$processIndex,$line") }
    }
  }
}
$lines | Set-Content -LiteralPath $Output
Get-Content -LiteralPath $Output
