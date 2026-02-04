<#
.SYNOPSIS
    AutoPaqet Uninstaller for Windows.
.DESCRIPTION
    Removes AutoPaqet installation, shortcuts, and configuration files.
    Does NOT remove dependencies (Git, Go, GCC, Npcap).

    One-liner uninstall:
        irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-uninstall.ps1 | iex
#>

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Self-Elevation
# -----------------------------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARN] Administrator privileges required. Requesting elevation..." -ForegroundColor Yellow
    $url = "https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-uninstall.ps1"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm '$url' | iex"
    exit
}

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------
Write-Host @"
=============================================
      AUTOPAQET UNINSTALLER (WINDOWS)
=============================================
"@ -ForegroundColor Cyan

$installDir = Join-Path $env:USERPROFILE "autopaqet"

# Check if installed
if (-not (Test-Path $installDir)) {
    Write-Host "[INFO] AutoPaqet is not installed at: $installDir" -ForegroundColor Yellow
    Write-Host "Nothing to uninstall." -ForegroundColor White
    Read-Host "Press Enter to close"
    exit
}

# Confirm
Write-Host ""
Write-Host "This will remove:" -ForegroundColor Yellow
Write-Host "  - Installation folder: $installDir" -ForegroundColor White
Write-Host "  - Desktop shortcut" -ForegroundColor White
Write-Host "  - Start Menu shortcuts" -ForegroundColor White
Write-Host ""
Write-Host "Dependencies (Git, Go, GCC, Npcap) will NOT be removed." -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "Continue with uninstall? [y/N]"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Uninstall cancelled." -ForegroundColor Yellow
    exit
}

Write-Host ""

# Remove shortcuts
$WshShell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs"

$shortcuts = @(
    (Join-Path $desktop "AutoPaqet.lnk"),
    (Join-Path $startMenu "AutoPaqet.lnk"),
    (Join-Path $startMenu "Uninstall AutoPaqet.lnk")
)

foreach ($shortcut in $shortcuts) {
    if (Test-Path $shortcut) {
        Remove-Item $shortcut -Force
        Write-Host "[OK] Removed: $shortcut" -ForegroundColor Green
    }
}

# Remove installation directory
if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force
    Write-Host "[OK] Removed: $installDir" -ForegroundColor Green
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "  AutoPaqet has been uninstalled." -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Dependencies (Git, Go, GCC, Npcap) were not removed." -ForegroundColor Yellow
Write-Host "      You can uninstall them manually via Windows Settings if needed." -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to close"
