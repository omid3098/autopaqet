<#
.SYNOPSIS
    Fetch paqet binary from GitHub Release for local development.
.PARAMETER Version
    Release version tag (e.g., v1.0.0). Defaults to "latest".
.EXAMPLE
    .\scripts\fetch-binary.ps1
    .\scripts\fetch-binary.ps1 -Version v1.0.0
#>
param(
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$BinDir = Join-Path (Split-Path $ScriptDir) "bin"
$Repo = "omid3098/autopaqet"
$BinaryName = "paqet-windows-amd64.exe"

if ($Version -eq "latest") {
    $DownloadUrl = "https://github.com/$Repo/releases/latest/download/$BinaryName"
} else {
    $DownloadUrl = "https://github.com/$Repo/releases/download/$Version/$BinaryName"
}

if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}

$OutputPath = Join-Path $BinDir "paqet.exe"

Write-Host "Downloading $BinaryName..."
Write-Host "URL: $DownloadUrl"

Invoke-WebRequest -Uri $DownloadUrl -OutFile $OutputPath -UseBasicParsing

$hash = (Get-FileHash -Path $OutputPath -Algorithm SHA256).Hash
Write-Host "Binary saved to $OutputPath"
Write-Host "SHA256: $hash"
