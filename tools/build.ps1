param(
    [ValidateSet('Win32', 'Win64', 'Both')][string]$Platform = 'Both',
    [string]$BdsRoot = $env:BDS,
    [switch]$TestsOnly
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $BdsRoot -and -not $TestsOnly) {
    $compilerCommand = Get-Command dcc32.exe -ErrorAction Stop
    $BdsRoot = Split-Path -Parent (Split-Path -Parent $compilerCommand.Source)
}
$platforms = if ($Platform -eq 'Both') { @('Win32', 'Win64') } else { @($Platform) }
Push-Location $repoRoot
try {
    foreach ($target in $platforms) {
        $outDir = Join-Path $repoRoot "build\$target"
        $dcuDir = Join-Path $outDir 'dcu'
        New-Item -ItemType Directory -Force $dcuDir | Out-Null
        $exe = Join-Path $outDir 'QueryBuilder.Tests.exe'
        if (-not $TestsOnly) {
            $compilerName = if ($target -eq 'Win32') { 'dcc32.exe' } else { 'dcc64.exe' }
            $compiler = Join-Path $BdsRoot "bin\$compilerName"
            $rtlPath = Join-Path $BdsRoot "lib\$target\release"
            $dunitPath = Join-Path $BdsRoot 'source\DUnitX'
            $started = Get-Date
            & $compiler -B "-U$rtlPath;$repoRoot\src;$dunitPath" "-I$repoRoot\src;$dunitPath" '-NSSystem;Xml;Data;Winapi' "-E$outDir" "-NU$dcuDir" 'test\QueryBuilder.Tests.dpr' 2>&1 |
                Tee-Object -FilePath (Join-Path $outDir 'build.log')
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe) -or
                (Get-Item -LiteralPath $exe).LastWriteTime -lt $started) {
                throw "No successful $target build. Community Edition: build test\QueryBuilder.Tests.dproj in the IDE, then use tools\build.ps1 -TestsOnly."
            }
        }
        if (-not (Test-Path -LiteralPath $exe)) { throw "Test executable not found: $exe" }
        & $exe *> (Join-Path $outDir 'tests.log')
        $testExit = $LASTEXITCODE
        Get-Content (Join-Path $outDir 'tests.log') -Tail 8
        if ($testExit -ne 0) { throw "DUnitX failed for $target (exit code $testExit)." }
    }
} finally { Pop-Location }
