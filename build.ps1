<#
.SYNOPSIS
    Build script for AutoPaqet Installer.
.DESCRIPTION
    Validates that bundled scripts are in sync with lib/ modules and runs quality gates.

    The root-level scripts (autopaqet-client.ps1, autopaqet-server.sh) are the "bundled"
    distributable versions with all functions defined inline. The lib/ directory contains
    modular versions of the same functions for testing and development.

.EXAMPLE
    .\build.ps1              # Run validation
    .\build.ps1 -RunGates    # Run quality gates
#>

[CmdletBinding()]
param(
    [switch]$RunGates
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot

Write-Host ""
Write-Host "  AutoPaqet Installer Build" -ForegroundColor Cyan
Write-Host "  =========================" -ForegroundColor Cyan
Write-Host ""

# Check required files exist
$requiredFiles = @(
    "autopaqet-client.ps1",
    "autopaqet-server.sh",
    "autopaqet-uninstall.ps1",
    "autopaqet-uninstall.sh",
    "lib\powershell\AutoPaqet.Validate.ps1",
    "lib\powershell\AutoPaqet.Menu.ps1",
    "lib\powershell\AutoPaqet.Config.ps1",
    "lib\powershell\AutoPaqet.Network.ps1",
    "lib\powershell\AutoPaqet.Install.ps1",
    "lib\powershell\AutoPaqet.Logging.ps1",
    "lib\bash\validate.sh",
    "lib\bash\menu.sh",
    "lib\bash\config.sh",
    "lib\bash\service.sh",
    "lib\bash\install.sh",
    "gui\go.mod",
    "gui\wails.json"
)

Write-Host "Checking required files..." -ForegroundColor Yellow
$missing = @()
foreach ($file in $requiredFiles) {
    $path = Join-Path $scriptDir $file
    if (-not (Test-Path $path)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    Write-Host "[FAIL] Missing files:" -ForegroundColor Red
    foreach ($f in $missing) {
        Write-Host "  - $f" -ForegroundColor Red
    }
    exit 1
}
Write-Host "[OK] All required files present" -ForegroundColor Green

# Syntax check PowerShell files
Write-Host ""
Write-Host "Checking PowerShell syntax..." -ForegroundColor Yellow
$psFiles = Get-ChildItem -Path $scriptDir -Filter "*.ps1" -Recurse
$syntaxErrors = 0

foreach ($file in $psFiles) {
    $relativePath = $file.FullName.Replace("$scriptDir\", "")
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors.Count -gt 0) {
        Write-Host "[FAIL] $relativePath - $($parseErrors.Count) errors" -ForegroundColor Red
        $syntaxErrors++
    }
}

if ($syntaxErrors -eq 0) {
    Write-Host "[OK] All PowerShell files have valid syntax" -ForegroundColor Green
} else {
    Write-Host "[FAIL] $syntaxErrors files have syntax errors" -ForegroundColor Red
    exit 1
}

# Check bash syntax if available
Write-Host ""
Write-Host "Checking Bash syntax..." -ForegroundColor Yellow

$bashAvailable = $false
$gitBash = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path $gitBash) {
    $bashAvailable = $true
}

if ($bashAvailable) {
    $shFiles = Get-ChildItem -Path $scriptDir -Filter "*.sh" -Recurse
    $bashErrors = 0

    foreach ($file in $shFiles) {
        $relativePath = $file.FullName.Replace("$scriptDir\", "").Replace("\", "/")
        $unixPath = $file.FullName.Replace("\", "/").Replace("D:", "/d")

        $result = & $gitBash -n "$unixPath" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] $relativePath" -ForegroundColor Red
            $bashErrors++
        }
    }

    if ($bashErrors -eq 0) {
        Write-Host "[OK] All Bash files have valid syntax" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $bashErrors files have syntax errors" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[SKIP] Git Bash not found, skipping bash syntax check" -ForegroundColor Yellow
}

# Run gates if requested
if ($RunGates) {
    Write-Host ""
    Write-Host "Running quality gates..." -ForegroundColor Yellow
    Write-Host ""
    & "$scriptDir\gates.ps1"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Build validation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Project Structure:" -ForegroundColor Cyan
Write-Host "  Root scripts (bundled for one-liner use):"
Write-Host "    - autopaqet-client.ps1   (Windows client installer)"
Write-Host "    - autopaqet-server.sh    (Linux server installer)"
Write-Host "    - autopaqet-uninstall.*  (Uninstallers)"
Write-Host ""
Write-Host "  lib/ directory (modular code for testing):"
Write-Host "    - lib/powershell/        (PowerShell modules)"
Write-Host "    - lib/bash/              (Bash modules)"
Write-Host ""
Write-Host "  tests/ directory (unit tests):"
Write-Host "    - tests/powershell/      (Pester tests)"
Write-Host "    - tests/bash/            (Bats tests)"
Write-Host ""
Write-Host "Run '.\gates.ps1' to execute all quality gates." -ForegroundColor Yellow
Write-Host ""
