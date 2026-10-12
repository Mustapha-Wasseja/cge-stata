<#
.SYNOPSIS
Runs the cge-stata Stata test suite in batch mode on Windows.

.PARAMETER StataExe
Full path to the Stata executable. If omitted, the newest Stata installation
under Program Files is used.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\run_stata_tests.ps1
#>
param([string]$StataExe)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$testsDir = Join-Path $repo "tests"

if (-not $StataExe) {
    $roots = @("C:\Program Files", "C:\Program Files (x86)")
    $StataExe = Get-ChildItem -Path $roots -Directory -Filter "Stata*" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object { Get-ChildItem -Path $_.FullName -Filter "Stata*-64.exe" -ErrorAction SilentlyContinue } |
        Where-Object { $_.Name -notmatch "_old" } |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $StataExe -or -not (Test-Path $StataExe)) {
    throw "Stata executable not found. Pass -StataExe 'C:\path\to\StataSE-64.exe'."
}

Write-Host "Using $StataExe"
$log = Join-Path $testsDir "run_all.log"
if (Test-Path $log) { Remove-Item $log }

Start-Process -FilePath $StataExe -ArgumentList "/e", "do", "run_all.do" `
    -WorkingDirectory $testsDir -Wait | Out-Null

if (-not (Test-Path $log)) { throw "Stata did not write $log" }

Select-String -Path $log -Pattern "^(PASS|FAIL) |^Summary:" | ForEach-Object { Write-Host $_.Line }

if (-not (Select-String -Path $log -Pattern "^Summary:" -Quiet)) {
    Write-Host "The test run did not finish; see $log"
    exit 1
}
if (Select-String -Path $log -Pattern "^FAIL " -Quiet) { exit 1 }
exit 0
