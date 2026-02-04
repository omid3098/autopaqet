<#
.SYNOPSIS
    AutoPaqet Client for Windows.
.DESCRIPTION
    Downloads, builds, configures, and launches the AutoPaqet client.
    Requires: Administrator privileges, Go, Git, GCC (MinGW), and Npcap.

    One-liner installation:
        irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-client.ps1 | iex

    With server configuration:
        $env:AUTOPAQET_SERVER="1.2.3.4:9999"; $env:AUTOPAQET_KEY="your-key"; irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-client.ps1 | iex
#>

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$RepoUrl = "https://github.com/hanselime/paqet.git"

# -----------------------------------------------------------------------------
# 0. Self-Elevation (for one-liner support)
# -----------------------------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[WARN] Administrator privileges required. Requesting elevation..." -ForegroundColor Yellow

    # Save environment variables to pass to elevated process
    $envParams = ""
    if ($env:AUTOPAQET_SERVER) { $envParams += "`$env:AUTOPAQET_SERVER='$env:AUTOPAQET_SERVER'; " }
    if ($env:AUTOPAQET_KEY) { $envParams += "`$env:AUTOPAQET_KEY='$env:AUTOPAQET_KEY'; " }

    # Download script and run elevated
    $scriptUrl = "https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-client.ps1"
    $elevatedCmd = "${envParams}irm '$scriptUrl' | iex"

    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile", "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $elevatedCmd
    exit
}

# -----------------------------------------------------------------------------
# 0.1 Working Directory Setup (supports one-liner installation)
# -----------------------------------------------------------------------------
# Use fixed installation directory instead of $PSScriptRoot (which is empty when piped)
$WorkDir = Join-Path $env:USERPROFILE "autopaqet"
if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }

# -----------------------------------------------------------------------------
# 0.2 Logging Infrastructure
# -----------------------------------------------------------------------------
$RequirementsDir = Join-Path $WorkDir "requirements"
if (-not (Test-Path $RequirementsDir)) { New-Item -ItemType Directory -Path $RequirementsDir | Out-Null }

$LogFile = Join-Path $RequirementsDir "setup.log"

# Overwrite log file for each run
Set-Content -Path $LogFile -Value "" -Encoding UTF8

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG", "COMMAND")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
}

function Invoke-LoggedCommand {
    param(
        [string]$Command,
        [string]$Description
    )
    Write-Log "Executing: $Command" -Level "COMMAND"
    Write-Log "Description: $Description" -Level "DEBUG"

    # Use cmd /c to properly capture both stdout and stderr without PowerShell treating stderr as errors
    $tempOut = [System.IO.Path]::GetTempFileName()
    $tempErr = [System.IO.Path]::GetTempFileName()

    try {
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $Command > `"$tempOut`" 2> `"$tempErr`"" -Wait -NoNewWindow -PassThru
        $stdout = Get-Content $tempOut -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content $tempErr -Raw -ErrorAction SilentlyContinue

        if ($stdout) { Write-Log "Stdout: $stdout" -Level "DEBUG" }
        if ($stderr) { Write-Log "Stderr: $stderr" -Level "DEBUG" }
        Write-Log "Exit code: $($process.ExitCode)" -Level "DEBUG"

        # Set LASTEXITCODE for callers to check
        $global:LASTEXITCODE = $process.ExitCode
        return $stdout
    } finally {
        Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
        Remove-Item $tempErr -Force -ErrorAction SilentlyContinue
    }
}

# Start transcript as safety net
$transcriptPath = Join-Path $RequirementsDir "setup-transcript.log"
Start-Transcript -Path $transcriptPath -Force | Out-Null

# Colors (also log to file)
function Write-Info {
    param($msg)
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
    Write-Log $msg -Level "INFO"
}
function Write-Success {
    param($msg)
    Write-Host "[OK] $msg" -ForegroundColor Green
    Write-Log $msg -Level "SUCCESS"
}
function Write-Warn {
    param($msg)
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
    Write-Log $msg -Level "WARN"
}
function Write-Error {
    param($msg)
    Write-Host "[ERROR] $msg" -ForegroundColor Red
    Write-Log $msg -Level "ERROR"
    Write-Log "Setup failed. See log for details." -Level "ERROR"
    Stop-Transcript | Out-Null
    Write-Host ""
    Write-Host "If setup failed, please send this file:" -ForegroundColor Yellow
    Write-Host "  $LogFile" -ForegroundColor White
    exit 1
}

# Log system information header
Write-Log "========== AUTOPAQET CLIENT LOG ==========" -Level "INFO"
Write-Log "Setup started" -Level "INFO"
Write-Log "Hostname: $env:COMPUTERNAME" -Level "INFO"
Write-Log "Username: $env:USERNAME" -Level "INFO"
Write-Log "Windows Version: $([System.Environment]::OSVersion.VersionString)" -Level "INFO"
Write-Log "Architecture: $env:PROCESSOR_ARCHITECTURE" -Level "INFO"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"
Write-Log "Working Directory: $WorkDir" -Level "INFO"
Write-Log "PATH: $env:PATH" -Level "DEBUG"

Write-Log "Running as Administrator: $isAdmin" -Level "INFO"

# -----------------------------------------------------------------------------
# 1. Privileges Check (already elevated at this point)
# -----------------------------------------------------------------------------

Write-Host @"
=============================================
        AUTOPAQET CLIENT (WINDOWS)
=============================================
"@ -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# 2. Requirement Detection & Setup
# -----------------------------------------------------------------------------
Write-Info "Checking system requirements..."
Write-Log "Requirements directory: $RequirementsDir" -Level "DEBUG"

$Dependencies = @{
    "Git" = @{
        "Check" = { Get-Command "git" -ErrorAction SilentlyContinue }
        "URL"   = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"
        "File"  = "Git-Setup.exe"
        "Args"  = "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS"
    }
    "Go" = @{
        "Check" = { Get-Command "go" -ErrorAction SilentlyContinue }
        "URL"   = "https://go.dev/dl/go1.23.4.windows-amd64.msi"
        "File"  = "Go-Setup.msi"
        "Args"  = "/quiet /norestart"
        "MSI"   = $true
    }
    "GCC" = @{
        "Check" = { Get-Command "gcc" -ErrorAction SilentlyContinue }
        "URL"   = "https://github.com/jmeubank/tdm-gcc/releases/download/v10.3.0-tdm64-2/tdm64-gcc-10.3.0-2.exe"
        "File"  = "GCC-Setup.exe"
        "Args"  = "/S /D=C:\TDM-GCC-64"
    }
}

$isInteractive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected

foreach ($depName in $Dependencies.Keys) {
    $dep = $Dependencies[$depName]
    Write-Log "Checking dependency: $depName" -Level "DEBUG"
    $checkResult = & $dep.Check
    if ($checkResult) {
        $cmdPath = $checkResult.Source
        Write-Log "$depName found at: $cmdPath" -Level "DEBUG"
        Write-Success "$depName detected."
    } else {
        Write-Log "$depName not found in PATH" -Level "WARN"
        Write-Warn "$depName is missing."

        # Auto-install in non-interactive mode, or prompt in interactive mode
        $shouldInstall = $true
        if ($isInteractive) {
            $choice = Read-Host "Download and set up $depName? [Y/n]"
            $shouldInstall = ($choice -eq '' -or $choice -eq 'y' -or $choice -eq 'Y')
        } else {
            Write-Info "Auto-installing $depName (non-interactive mode)..."
        }

        if ($shouldInstall) {
            $dest = Join-Path $RequirementsDir $dep.File
            if (-not (Test-Path $dest)) {
                Write-Info "Downloading $depName..."
                Write-Log "Download URL: $($dep.URL)" -Level "DEBUG"
                Write-Log "Download destination: $dest" -Level "DEBUG"
                try {
                    Invoke-WebRequest -Uri $dep.URL -OutFile $dest -UseBasicParsing
                    Write-Log "Download completed successfully" -Level "DEBUG"
                } catch {
                    Write-Log "Download failed: $_" -Level "ERROR"
                    Write-Error "Failed to download $depName"
                }
            } else {
                Write-Log "Using cached file: $dest" -Level "DEBUG"
            }
            Write-Info "Setting up $depName..."
            Write-Log "Setup args: $($dep.Args)" -Level "DEBUG"
            if ($dep.MSI) {
                $proc = Start-Process msiexec.exe -ArgumentList "/i `"$dest`" $($dep.Args)" -Wait -PassThru
            } else {
                $proc = Start-Process $dest -ArgumentList $dep.Args -Wait -PassThru
            }
            Write-Log "Setup exit code: $($proc.ExitCode)" -Level "DEBUG"
            Write-Success "$depName ready. You may need to restart the terminal if it's not detected immediately."
        } else {
            Write-Log "User declined to set up $depName" -Level "WARN"
        }
    }
}

# Check Npcap (Manual setup usually preferred for the specific options)
Write-Log "Checking Npcap" -Level "DEBUG"
$npcapPath32 = "$env:SystemRoot\System32\Npcap\wpcap.dll"
$npcapPath64 = "$env:SystemRoot\SysWOW64\Npcap\wpcap.dll"
$npcapInstalled = (Test-Path $npcapPath32) -or (Test-Path $npcapPath64)
Write-Log "Npcap check paths: $npcapPath32, $npcapPath64" -Level "DEBUG"
Write-Log "Npcap present: $npcapInstalled" -Level "DEBUG"

if ($npcapInstalled) {
    Write-Success "Npcap detected."
} else {
    Write-Warn "Npcap is missing."

    # Auto-install in non-interactive mode, or prompt in interactive mode
    $shouldInstall = $true
    if ($isInteractive) {
        $choice = Read-Host "Download and set up Npcap? [Y/n]"
        $shouldInstall = ($choice -eq '' -or $choice -eq 'y' -or $choice -eq 'Y')
    } else {
        Write-Info "Auto-installing Npcap (non-interactive mode)..."
    }

    if ($shouldInstall) {
        $url = "https://npcap.com/dist/npcap-1.80.exe"
        $dest = Join-Path $RequirementsDir "npcap-setup.exe"
        if (-not (Test-Path $dest)) {
            Write-Info "Downloading Npcap..."
            Write-Log "Download URL: $url" -Level "DEBUG"
            Write-Log "Download destination: $dest" -Level "DEBUG"
            try {
                Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
                Write-Log "Npcap download completed" -Level "DEBUG"
            } catch {
                Write-Log "Npcap download failed: $_" -Level "ERROR"
                Write-Error "Failed to download Npcap"
            }
        } else {
            Write-Log "Using cached Npcap file: $dest" -Level "DEBUG"
        }

        if ($isInteractive) {
            Write-Warn "IMPORTANT: Check 'Install Npcap in WinPcap API-compatible Mode' during setup."
            Read-Host "Press Enter to start Npcap setup..."
            $proc = Start-Process $dest -Wait -PassThru
        } else {
            # Silent install with WinPcap compatibility mode
            Write-Info "Installing Npcap silently with WinPcap API-compatible mode..."
            $proc = Start-Process $dest -ArgumentList "/S /winpcap_mode=yes" -Wait -PassThru
        }
        Write-Log "Npcap setup exit code: $($proc.ExitCode)" -Level "DEBUG"
        Write-Success "Npcap setup finished."
    } else {
        Write-Log "User declined to set up Npcap" -Level "WARN"
    }
}

# -----------------------------------------------------------------------------
# 3. Clone and Build
# -----------------------------------------------------------------------------
$srcDir = Join-Path $RequirementsDir "autopaqet"
$exePath = Join-Path $RequirementsDir "autopaqet.exe"

Write-Log "Source directory: $srcDir" -Level "DEBUG"
Write-Log "Binary path: $exePath" -Level "DEBUG"
Write-Log "Repository URL: $RepoUrl" -Level "DEBUG"

if (-not (Test-Path $srcDir)) {
    Write-Info "Cloning AutoPaqet repository..."
    Write-Log "Adding safe.directory: $($srcDir.Replace('\', '/'))" -Level "DEBUG"
    $safeDir = $srcDir.Replace('\', '/')
    $output = Invoke-LoggedCommand "git config --global --add safe.directory `"$safeDir`"" "Add safe directory to git config"

    Write-Log "Starting git clone..." -Level "DEBUG"
    $output = Invoke-LoggedCommand "git clone --depth 1 $RepoUrl `"$srcDir`"" "Clone AutoPaqet repository"
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to clone repository." }
    Write-Log "Clone completed successfully" -Level "SUCCESS"
} else {
    Write-Info "Updating AutoPaqet repository..."
    Write-Log "Source directory already exists, pulling updates" -Level "DEBUG"
    $safeDir = $srcDir.Replace('\', '/')
    $output = Invoke-LoggedCommand "git config --global --add safe.directory `"$safeDir`"" "Add safe directory to git config"

    Push-Location $srcDir
    $output = Invoke-LoggedCommand "git pull" "Pull latest changes"
    Pop-Location
    Write-Log "Repository update completed" -Level "DEBUG"
}

if (-not (Test-Path $exePath)) {
    Write-Info "Building AutoPaqet binary..."
    Push-Location $srcDir
    $env:CGO_ENABLED = "1"
    Write-Log "CGO_ENABLED set to 1" -Level "DEBUG"
    Write-Log "Build command: go build -ldflags '-s -w' -trimpath -o '$exePath' ./cmd/main.go" -Level "COMMAND"

    $buildOutput = go build -ldflags "-s -w" -trimpath -o "$exePath" ./cmd/main.go 2>&1
    $buildExitCode = $LASTEXITCODE
    Write-Log "Build output: $buildOutput" -Level "DEBUG"
    Write-Log "Build exit code: $buildExitCode" -Level "DEBUG"

    if ($buildExitCode -ne 0) {
        Pop-Location
        Write-Error "Build failed. Check GCC/Go setup."
    }
    Pop-Location
    Write-Success "Build complete: $exePath"
} else {
    Write-Log "Binary already exists, skipping build" -Level "DEBUG"
    Write-Success "Binary already exists: $exePath"
}

# -----------------------------------------------------------------------------
# 4. Network Auto-Detection
# -----------------------------------------------------------------------------
Write-Info "Detecting active network configuration..."
Write-Log "Starting network auto-detection" -Level "DEBUG"

# Find the interface with the default route (Metric based)
$defaultRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Sort-Object RouteMetric | Select-Object -First 1

if (-not $defaultRoute) {
    Write-Log "No default route found (0.0.0.0/0)" -Level "ERROR"
    Write-Error "No active internet connection detected (Default Route missing)."
}

$ifIndex = $defaultRoute.InterfaceIndex
Write-Log "Default route interface index: $ifIndex" -Level "DEBUG"
Write-Log "Default route metric: $($defaultRoute.RouteMetric)" -Level "DEBUG"
Write-Log "Default route next hop: $($defaultRoute.NextHop)" -Level "DEBUG"

$adapter = Get-NetAdapter -InterfaceIndex $ifIndex
$ipInfo = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4

if (-not $adapter -or -not $ipInfo) {
    Write-Log "Failed to get adapter or IP info for interface $ifIndex" -Level "ERROR"
    Write-Error "Failed to resolve network adapter details."
}

$netInterface = $adapter.Name
$netGuid = $adapter.InterfaceGuid
$localIP = $ipInfo.IPAddress
$gatewayIP = $defaultRoute.NextHop

Write-Log "Adapter Name: $netInterface" -Level "DEBUG"
Write-Log "Adapter Status: $($adapter.Status)" -Level "DEBUG"
Write-Log "Adapter GUID: $netGuid" -Level "DEBUG"
Write-Log "Local IP: $localIP" -Level "DEBUG"
Write-Log "Gateway IP: $gatewayIP" -Level "DEBUG"

# Ping gateway to ensure ARP entry exists
$gatewayMAC = ""
if ($gatewayIP -ne "0.0.0.0") {
    Write-Info "Pinging gateway ($gatewayIP) to refresh ARP..."
    Write-Log "Pinging gateway to populate ARP table" -Level "DEBUG"
    Test-Connection -ComputerName $gatewayIP -Count 1 -Quiet | Out-Null
    $arp = Get-NetNeighbor -IPAddress $gatewayIP -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $gatewayMAC = $arp.LinkLayerAddress
    Write-Log "ARP lookup result: $gatewayMAC" -Level "DEBUG"
}

if ([string]::IsNullOrEmpty($gatewayMAC)) {
    Write-Log "Gateway MAC address not found in ARP table" -Level "ERROR"
    Write-Error "Could not detect Gateway MAC address."
}

# Format GUID for AutoPaqet config (Windows Npcap style)
$npcapGuid = "\Device\NPF_$netGuid"

Write-Log "Network detection complete" -Level "SUCCESS"
Write-Log "Interface: $netInterface" -Level "INFO"
Write-Log "Local IP: $localIP" -Level "INFO"
Write-Log "Gateway IP: $gatewayIP" -Level "INFO"
Write-Log "Gateway MAC: $gatewayMAC" -Level "INFO"
Write-Log "Npcap GUID: $npcapGuid" -Level "INFO"

Write-Success "Interface:   $netInterface"
Write-Success "Local IP:    $localIP"
Write-Success "Gateway IP:  $gatewayIP"
Write-Success "Gateway MAC: $gatewayMAC"
Write-Success "Npcap GUID:  $npcapGuid"

# -----------------------------------------------------------------------------
# 5. Configuration Setup
# -----------------------------------------------------------------------------
$configFile = Join-Path $RequirementsDir "client.yaml"

Write-Log "Configuration file path: $configFile" -Level "DEBUG"

if (-not (Test-Path $configFile)) {
    Write-Host "`n[SETUP] New Configuration Required" -ForegroundColor Yellow
    Write-Log "Configuration file not found, creating new one" -Level "INFO"

    # Use environment variable if set, otherwise prompt (or use default for non-interactive)
    $serverInput = $env:AUTOPAQET_SERVER
    if ([string]::IsNullOrWhiteSpace($serverInput)) {
        # Check if running interactively
        $isInteractive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
        if ($isInteractive) {
            $serverInput = Read-Host "Enter Server Address (IP:PORT) [Default: 127.0.0.1:9999]"
        }
        if ([string]::IsNullOrWhiteSpace($serverInput)) { $serverInput = "127.0.0.1:9999" }
    }
    Write-Log "Server address: $serverInput" -Level "INFO"
    Write-Info "Server address: $serverInput"

    # Use environment variable if set, otherwise prompt (or auto-generate for non-interactive)
    $keyInput = $env:AUTOPAQET_KEY
    if ([string]::IsNullOrWhiteSpace($keyInput)) {
        $isInteractive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
        if ($isInteractive) {
            $keyInput = Read-Host "Enter Secret Key (Must match server) [Default: Auto-Generated]"
        }
    }
    if ([string]::IsNullOrWhiteSpace($keyInput)) {
        Write-Info "Generating a new key. Ensure you update the SERVER with this key!"
        Write-Log "Generating new secret key" -Level "DEBUG"
        $keyInput = & $exePath secret
        Write-Log "Key generated (redacted for security)" -Level "DEBUG"
    } else {
        Write-Log "User provided secret key (redacted for security)" -Level "DEBUG"
    }

    $randomPort = Get-Random -Minimum 10000 -Maximum 65000
    Write-Log "Random local port: $randomPort" -Level "DEBUG"

    Write-Log "Configuration parameters:" -Level "DEBUG"
    Write-Log "  Interface: $netInterface" -Level "DEBUG"
    Write-Log "  GUID: $npcapGuid" -Level "DEBUG"
    Write-Log "  Local address: ${localIP}:$randomPort" -Level "DEBUG"
    Write-Log "  Router MAC: $gatewayMAC" -Level "DEBUG"
    Write-Log "  Server: $serverInput" -Level "DEBUG"

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
    Write-Log "Configuration file created" -Level "SUCCESS"
    Write-Success "Configuration created: $configFile"
} else {
    Write-Log "Using existing configuration file" -Level "DEBUG"
    Write-Success "Configuration file found: $configFile"
    Write-Warn "Using existing config. If network changed (IP/MAC), delete client.yaml and re-run."
}

# -----------------------------------------------------------------------------
# 6. Launch
# -----------------------------------------------------------------------------
Write-Log "Setup complete" -Level "SUCCESS"
Write-Host "`n[READY] Setup Complete." -ForegroundColor Green

Write-Host ""
Write-Host "Log file location:" -ForegroundColor Yellow
Write-Host "  $LogFile" -ForegroundColor White

Write-Host ""
Write-Info "Starting AutoPaqet Client..."
Write-Log "Launching AutoPaqet client: $exePath run -c $configFile" -Level "COMMAND"
Stop-Transcript | Out-Null
& $exePath run -c $configFile
