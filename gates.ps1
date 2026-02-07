<#
.SYNOPSIS
    Gates - Run all tests and quality checks for AutoPaqet Installer
.DESCRIPTION
    Single entry point for all validation. Run this before committing.
    Exit code 0 = all gates passed, non-zero = failures
.EXAMPLE
    .\gates.ps1
    .\gates.ps1 -Verbose
#>

[CmdletBinding()]
param(
    [switch]$SkipBash  # Skip bash tests if bats not available
)

$ErrorActionPreference = "Continue"
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0
$script:Results = @()

function Write-Gate {
    param([string]$Name, [bool]$Passed, [string]$Details = "")
    $script:TotalTests++
    if ($Passed) {
        $script:PassedTests++
        Write-Host "[PASS] $Name" -ForegroundColor Green
    } else {
        $script:FailedTests++
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        if ($Details) { Write-Host "       $Details" -ForegroundColor Yellow }
    }
    $script:Results += @{ Name = $Name; Passed = $Passed; Details = $Details }
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# =============================================================================
# Header
# =============================================================================
Clear-Host
Write-Host ""
Write-Host "  ██████╗  █████╗ ████████╗███████╗███████╗" -ForegroundColor Magenta
Write-Host " ██╔════╝ ██╔══██╗╚══██╔══╝██╔════╝██╔════╝" -ForegroundColor Magenta
Write-Host " ██║  ███╗███████║   ██║   █████╗  ███████╗" -ForegroundColor Magenta
Write-Host " ██║   ██║██╔══██║   ██║   ██╔══╝  ╚════██║" -ForegroundColor Magenta
Write-Host " ╚██████╔╝██║  ██║   ██║   ███████╗███████║" -ForegroundColor Magenta
Write-Host "  ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚══════╝" -ForegroundColor Magenta
Write-Host ""
Write-Host "  AutoPaqet Installer Quality Gates" -ForegroundColor White
Write-Host ""

$startTime = Get-Date
$scriptDir = $PSScriptRoot

# =============================================================================
# Gate 1: PowerShell Syntax Check
# =============================================================================
Write-Section "GATE 1: PowerShell Syntax Check"

$psFiles = Get-ChildItem -Path $scriptDir -Filter "*.ps1" -Recurse
foreach ($file in $psFiles) {
    $relativePath = $file.FullName.Replace("$scriptDir\", "")
    try {
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count -eq 0) {
            Write-Gate -Name "Syntax: $relativePath" -Passed $true
        } else {
            Write-Gate -Name "Syntax: $relativePath" -Passed $false -Details "$($parseErrors.Count) parse errors"
        }
    } catch {
        Write-Gate -Name "Syntax: $relativePath" -Passed $false -Details $_.Exception.Message
    }
}

# =============================================================================
# Gate 2: Pester Unit Tests
# =============================================================================
Write-Section "GATE 2: Pester Unit Tests"

$pesterInstalled = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]"5.0" }
if (-not $pesterInstalled) {
    Write-Host "Installing Pester 5.x..." -ForegroundColor Yellow
    try {
        # Ensure NuGet is available
        $null = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $?) {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
        }
        Install-Module Pester -Force -Scope CurrentUser -MinimumVersion 5.0 -SkipPublisherCheck -ErrorAction Stop
    } catch {
        Write-Host "  Could not install Pester: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Skipping Pester tests" -ForegroundColor Yellow
        $pesterInstalled = $null
    }
}

$testPath = Join-Path $scriptDir "tests\powershell"
if (Test-Path $testPath) {
    $testFiles = Get-ChildItem -Path $testPath -Filter "*.Tests.ps1"

    if ($testFiles.Count -gt 0) {
        try {
            $config = New-PesterConfiguration
            $config.Run.Path = $testPath
            $config.Output.Verbosity = "Minimal"
            $config.Run.PassThru = $true

            $pesterResult = Invoke-Pester -Configuration $config

            $passed = $pesterResult.PassedCount
            $failed = $pesterResult.FailedCount
            $total = $pesterResult.TotalCount

            Write-Gate -Name "Pester Tests: $passed/$total passed" -Passed ($failed -eq 0) -Details $(if ($failed -gt 0) { "$failed tests failed" } else { "" })
        } catch {
            Write-Gate -Name "Pester Tests" -Passed $false -Details $_.Exception.Message
        }
    } else {
        Write-Host "  No Pester test files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Test directory not found: $testPath" -ForegroundColor Yellow
}

# =============================================================================
# Gate 3: Bash Syntax Check (if bash available)
# =============================================================================
Write-Section "GATE 3: Bash Syntax Check"

$bashAvailable = $false
$bashCmd = $null

# Check for Git Bash
$gitBash = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path $gitBash) {
    $bashAvailable = $true
    $bashCmd = $gitBash
}

# Check for WSL
if (-not $bashAvailable) {
    try {
        $wslCheck = wsl --list 2>&1
        if ($LASTEXITCODE -eq 0) {
            $bashAvailable = $true
            $bashCmd = "wsl"
        }
    } catch { }
}

if ($bashAvailable -and -not $SkipBash) {
    $bashFiles = Get-ChildItem -Path $scriptDir -Filter "*.sh" -Recurse
    foreach ($file in $bashFiles) {
        $relativePath = $file.FullName.Replace("$scriptDir\", "").Replace("\", "/")
        $unixPath = $file.FullName.Replace("\", "/").Replace("D:", "/d")

        try {
            if ($bashCmd -eq "wsl") {
                $result = wsl bash -n "$unixPath" 2>&1
            } else {
                $result = & $bashCmd -n "$unixPath" 2>&1
            }

            if ($LASTEXITCODE -eq 0) {
                Write-Gate -Name "Syntax: $relativePath" -Passed $true
            } else {
                Write-Gate -Name "Syntax: $relativePath" -Passed $false -Details "$result"
            }
        } catch {
            Write-Gate -Name "Syntax: $relativePath" -Passed $false -Details $_.Exception.Message
        }
    }
} else {
    Write-Host "  Bash not available (Git Bash or WSL required)" -ForegroundColor Yellow
    Write-Host "  Use -SkipBash to silence this warning" -ForegroundColor DarkGray
}

# =============================================================================
# Gate 4: Bats Tests (if available)
# =============================================================================
Write-Section "GATE 4: Bats Tests"

$batsAvailable = $false
if ($bashAvailable -and -not $SkipBash) {
    try {
        if ($bashCmd -eq "wsl") {
            $batsCheck = wsl which bats 2>&1
        } else {
            $batsCheck = & $bashCmd -c "which bats" 2>&1
        }
        $batsAvailable = ($LASTEXITCODE -eq 0)
    } catch { }
}

if ($batsAvailable) {
    $batsPath = Join-Path $scriptDir "tests\bash"
    $batsFiles = Get-ChildItem -Path $batsPath -Filter "*.bats" -ErrorAction SilentlyContinue

    if ($batsFiles.Count -gt 0) {
        foreach ($file in $batsFiles) {
            $relativePath = $file.FullName.Replace("$scriptDir\", "").Replace("\", "/")
            $unixPath = $file.FullName.Replace("\", "/").Replace("D:", "/d")

            try {
                if ($bashCmd -eq "wsl") {
                    $result = wsl bats "$unixPath" 2>&1
                } else {
                    # Git Bash typically doesn't have bats installed
                    $result = & $bashCmd -c "bats '$unixPath'" 2>&1
                }

                if ($LASTEXITCODE -eq 0) {
                    Write-Gate -Name "Bats: $relativePath" -Passed $true
                } else {
                    Write-Gate -Name "Bats: $relativePath" -Passed $false -Details "Some tests failed"
                }
            } catch {
                Write-Gate -Name "Bats: $relativePath" -Passed $false -Details $_.Exception.Message
            }
        }
    } else {
        Write-Host "  No bats test files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Bats not available (install bats-core in WSL)" -ForegroundColor Yellow
    Write-Host "  WSL: sudo apt install bats" -ForegroundColor DarkGray
}

# =============================================================================
# Gate 5: Critical Files Exist
# =============================================================================
Write-Section "GATE 5: Critical Files Check"

$criticalFiles = @(
    "autopaqet-client.ps1",
    "autopaqet-server.sh",
    "autopaqet-uninstall.ps1",
    "autopaqet-uninstall.sh",
    "lib\powershell\AutoPaqet.Validate.ps1",
    "lib\powershell\AutoPaqet.Menu.ps1",
    "lib\bash\validate.sh",
    "lib\bash\menu.sh",
    ".github\workflows\test.yml"
)

foreach ($file in $criticalFiles) {
    $fullPath = Join-Path $scriptDir $file
    $exists = Test-Path $fullPath
    Write-Gate -Name "File exists: $file" -Passed $exists
}

# =============================================================================
# Gate 6: Go Tests (GUI Backend)
# =============================================================================
Write-Section "GATE 6: Go Tests (GUI Backend)"

$goAvailable = $false
try {
    $goVersion = go version 2>&1
    $goAvailable = ($LASTEXITCODE -eq 0)
} catch { }

if ($goAvailable) {
    $guiDir = Join-Path $scriptDir "gui"
    if (Test-Path (Join-Path $guiDir "go.mod")) {
        try {
            # Create dummy embed file if needed
            $binDir = Join-Path $guiDir "bin"
            if (-not (Test-Path $binDir)) {
                New-Item -ItemType Directory -Path $binDir -Force | Out-Null
            }
            $dummyBin = Join-Path $binDir "paqet"
            if (-not (Test-Path $dummyBin)) {
                Set-Content -Path $dummyBin -Value "dummy"
            }

            Push-Location $guiDir
            $result = go test ./internal/... -timeout 60s 2>&1
            $testExitCode = $LASTEXITCODE
            Pop-Location

            if ($testExitCode -eq 0) {
                Write-Gate -Name "Go Tests: GUI Backend" -Passed $true
            } else {
                Write-Gate -Name "Go Tests: GUI Backend" -Passed $false -Details "Tests failed"
            }
        } catch {
            Write-Gate -Name "Go Tests: GUI Backend" -Passed $false -Details $_.Exception.Message
        }
    } else {
        Write-Host "  GUI directory not found or missing go.mod" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Go not available, skipping GUI backend tests" -ForegroundColor Yellow
}

# =============================================================================
# Summary
# =============================================================================
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor $(if ($script:FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host "  SUMMARY" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════" -ForegroundColor $(if ($script:FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host ""
Write-Host "  Total:  $($script:TotalTests)" -ForegroundColor White
Write-Host "  Passed: $($script:PassedTests)" -ForegroundColor Green
Write-Host "  Failed: $($script:FailedTests)" -ForegroundColor $(if ($script:FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host "  Time:   $($duration.TotalSeconds.ToString('F2'))s" -ForegroundColor DarkGray
Write-Host ""

if ($script:FailedTests -eq 0) {
    Write-Host "  [PASS] ALL GATES PASSED" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "  [FAIL] GATES FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Failed gates:" -ForegroundColor Yellow
    foreach ($result in $script:Results | Where-Object { -not $_.Passed }) {
        Write-Host "    - $($result.Name)" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}
