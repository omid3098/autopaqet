<#
.SYNOPSIS
    Paqet Client Installer and Launcher for Windows.
.DESCRIPTION
    Downloads, builds, configures, and launches the Paqet client.
    Requires: Administrator privileges, Go, Git, GCC (MinGW), and Npcap.
#>

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/hanselime/paqet.git"
$WorkDir = $PSScriptRoot

# Colors
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# -----------------------------------------------------------------------------
# 1. Privileges Check
# -----------------------------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warn "Administrator privileges are required to configure network adapters and capture packets."
    Write-Warn "Please right-click this script and select 'Run as Administrator'."
    exit 1
}

Write-Host @"
=============================================
      PAQET CLIENT INSTALLER (WINDOWS)
=============================================
"@ -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# 2. Requirement Detection
# -----------------------------------------------------------------------------
Write-Info "Checking system requirements..."

# Check Git
if (Get-Command "git" -ErrorAction SilentlyContinue) {
    Write-Success "Git detected."
} else {
    Write-Error "Git is missing. Please install Git for Windows: https://git-scm.com/download/win"
}

# Check Go
if (Get-Command "go" -ErrorAction SilentlyContinue) {
    Write-Success "Go detected: $(go version)"
} else {
    Write-Error "Go is missing. Please install Go: https://go.dev/dl/"
}

# Check GCC (Needed for CGO)
if (Get-Command "gcc" -ErrorAction SilentlyContinue) {
    Write-Success "GCC detected."
} else {
    Write-Warn "GCC (MinGW/TDM-GCC) is missing. It is required for CGO build."
    Write-Warn "Please install TDM-GCC: https://jmeubank.github.io/tdm-gcc/"
    $cont = Read-Host "Continue anyway (build will likely fail)? [y/N]"
    if ($cont -ne 'y') { exit 1 }
}

# Check Npcap
$npcapInstalled = (Test-Path "$env:SystemRoot\System32\Npcap\wpcap.dll") -or (Test-Path "$env:SystemRoot\SysWOW64\Npcap\wpcap.dll")
if ($npcapInstalled) {
    Write-Success "Npcap detected."
} else {
    Write-Error "Npcap is missing. Please install Npcap: https://npcap.com/`nIMPORTANT: Check 'Install Npcap in WinPcap API-compatible Mode' during installation."
}

# -----------------------------------------------------------------------------
# 3. Clone and Build
# -----------------------------------------------------------------------------
$srcDir = Join-Path $WorkDir "paqet"
$exePath = Join-Path $WorkDir "paqet.exe"

if (-not (Test-Path $srcDir)) {
    Write-Info "Cloning Paqet repository..."
    git config --global --add safe.directory $srcDir.Replace('\', '/')
    git clone --depth 1 $RepoUrl $srcDir
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to clone repository." }
} else {
    Write-Info "Updating Paqet repository..."
    git config --global --add safe.directory $srcDir.Replace('\', '/')
    Push-Location $srcDir
    git pull
    Pop-Location
}

if (-not (Test-Path $exePath)) {
    Write-Info "Building Paqet binary..."
    Push-Location $srcDir
    $env:CGO_ENABLED = "1"
    go build -ldflags "-s -w" -trimpath -o "$exePath" ./cmd/main.go
    if ($LASTEXITCODE -ne 0) { 
        Pop-Location
        Write-Error "Build failed. Check GCC/Go installation." 
    }
    Pop-Location
    Write-Success "Build complete: $exePath"
} else {
    Write-Success "Binary already exists: $exePath"
}

# -----------------------------------------------------------------------------
# 4. Network Auto-Detection
# -----------------------------------------------------------------------------
Write-Info "Detecting active network configuration..."

# Find the interface with the default route (Metric based)
$defaultRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                Sort-Object RouteMetric | Select-Object -First 1

if (-not $defaultRoute) {
    Write-Error "No active internet connection detected (Default Route missing)."
}

$ifIndex = $defaultRoute.InterfaceIndex
$adapter = Get-NetAdapter -InterfaceIndex $ifIndex
$ipInfo = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4

if (-not $adapter -or -not $ipInfo) {
    Write-Error "Failed to resolve network adapter details."
}

$netInterface = $adapter.Name
$netGuid = $adapter.InterfaceGuid
$localIP = $ipInfo.IPAddress
$gatewayIP = $defaultRoute.NextHop

# Ping gateway to ensure ARP entry exists
$gatewayMAC = ""
if ($gatewayIP -ne "0.0.0.0") {
    Write-Info "Pinging gateway ($gatewayIP) to refresh ARP..."
    Test-Connection -ComputerName $gatewayIP -Count 1 -Quiet | Out-Null
    $arp = Get-NetNeighbor -IPAddress $gatewayIP -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $gatewayMAC = $arp.LinkLayerAddress
}

if ([string]::IsNullOrEmpty($gatewayMAC)) {
    Write-Error "Could not detect Gateway MAC address."
}

# Format GUID for paqet config (Windows Npcap style)
$npcapGuid = "\Device\NPF_$netGuid"

Write-Success "Interface:   $netInterface"
Write-Success "Local IP:    $localIP"
Write-Success "Gateway IP:  $gatewayIP"
Write-Success "Gateway MAC: $gatewayMAC"
Write-Success "Npcap GUID:  $npcapGuid"

# -----------------------------------------------------------------------------
# 5. Configuration Setup
# -----------------------------------------------------------------------------
$configFile = Join-Path $WorkDir "client.yaml"

if (-not (Test-Path $configFile)) {
    Write-Host "`n[SETUP] New Configuration Required" -ForegroundColor Yellow
    
    $serverInput = Read-Host "Enter Server Address (IP:PORT) [Default: 127.0.0.1:9999]"
    if ([string]::IsNullOrWhiteSpace($serverInput)) { $serverInput = "127.0.0.1:9999" }
    
    $keyInput = Read-Host "Enter Secret Key (Must match server) [Default: Auto-Generated]"
    if ([string]::IsNullOrWhiteSpace($keyInput)) { 
        Write-Info "Generating a new key. Ensure you update the SERVER with this key!"
        $keyInput = & $exePath secret
    }

    $randomPort = Get-Random -Minimum 10000 -Maximum 65000
    $configContent = @"
role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:1080"

network:
  interface: "$netInterface"
  guid: '$npcapGuid'
  ipv4:
    addr: "${localIP}:$randomPort"
    router_mac: "$gatewayMAC"
  tcp:
    local_flag: ["S"]
    remote_flag: ["PA"]

server:
  addr: "$serverInput"

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    key: "$keyInput"
    block: "aes"
"@
    Set-Content -Path $configFile -Value $configContent -Encoding Ascii
    Write-Success "Configuration created: $configFile"
} else {
    Write-Success "Configuration file found: $configFile"
    Write-Warn "Using existing config. If network changed (IP/MAC), delete client.yaml and re-run."
}

# -----------------------------------------------------------------------------
# 6. Launch
# -----------------------------------------------------------------------------
Write-Host "`n[READY] Installation and Setup Complete." -ForegroundColor Green
$choice = Read-Host "Do you want to start the Paqet Client now? [Y/n]"
if ($choice -eq '' -or $choice -eq 'y' -or $choice -eq 'Y') {
    Write-Info "Starting Paqet..."
    & $exePath run -c $configFile
}
