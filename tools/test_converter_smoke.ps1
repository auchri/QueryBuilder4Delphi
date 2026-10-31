param(
    [ValidateSet('Win32', 'Win64', 'Both')][string]$Platform = 'Both',
    [string]$BdsRoot = $env:BDS,
    [switch]$TestsOnly
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $repoRoot 'website\generate-smoke.mjs'
if ($TestsOnly) { & node $generator --check } else { & node $generator }
if ($LASTEXITCODE -ne 0) { throw 'Smoke fixture generation/verification failed.' }
$fixtureRoot = Join-Path $repoRoot 'build\converter-smoke'
if (-not $BdsRoot -and -not $TestsOnly) {
    $BdsRoot = Split-Path -Parent (Split-Path -Parent (Get-Command dcc32.exe -ErrorAction Stop).Source)
}
$platforms = if ($Platform -eq 'Both') { @('Win32', 'Win64') } else { @($Platform) }
$failures = @()
$libraryTimestamp = (Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Filter '*.pas' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
foreach ($target in $platforms) {
    $outDir = Join-Path $fixtureRoot $target
    $dcuDir = Join-Path $outDir 'dcu'
    New-Item -ItemType Directory -Force $dcuDir | Out-Null
    foreach ($dialect in @('MySQL', 'PostgreSQL', 'TransactSQL', 'SQLite')) {
        $project = "ConverterSmoke$dialect"
        $source = Join-Path $fixtureRoot "$project.dpr"
        $exe = Join-Path $outDir "$project.exe"
        if (-not $TestsOnly) {
            $compilerName = if ($target -eq 'Win32') { 'dcc32.exe' } else { 'dcc64.exe' }
            $compiler = Join-Path $BdsRoot "bin\$compilerName"
            $rtlPath = Join-Path $BdsRoot "lib\$target\release"
            $started = Get-Date
            & $compiler -B "-U$rtlPath;$repoRoot\src" "-I$repoRoot\src" '-NSSystem;Xml;Data;Winapi' "-E$outDir" "-NU$dcuDir" $source 2>&1 |
                Tee-Object -FilePath (Join-Path $outDir "$project-build.log")
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe) -or (Get-Item -LiteralPath $exe).LastWriteTime -lt $started) {
                $failures += "$target/${dialect}: no successful compilation (see build log)"
                continue
            }
        }
        if (-not (Test-Path -LiteralPath $exe) -or (Get-Item -LiteralPath $exe).LastWriteTime -lt (Get-Item -LiteralPath $source).LastWriteTime -or (Get-Item -LiteralPath $exe).LastWriteTime -lt $libraryTimestamp) {
            $failures += "$target/${dialect}: missing or outdated executable; rebuild in Delphi"
            continue
        }
        & $exe 2>&1 | Tee-Object -FilePath (Join-Path $outDir "$project-tests.log")
        if ($LASTEXITCODE -ne 0) { $failures += "$target/${dialect}: runtime binding assertions failed" }
    }
}
if ($failures.Count) {
    throw (($failures -join "`n") + "`nA Delphi edition with command-line compilation is required. With Community Edition, build all generated .dproj projects for Win32 and Win64 in the IDE, then run this script with -TestsOnly.")
}
Write-Output 'All requested generated Delphi compilation and runtime smoke checks passed.'
