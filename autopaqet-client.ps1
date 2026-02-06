<#
.SYNOPSIS
    AutoPaqet Client for Windows.
.DESCRIPTION
    Downloads, configures, and launches the AutoPaqet client.
    Requires: Administrator privileges and Npcap.

    One-liner installation:
        irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-client.ps1 | iex

    With server configuration:
        $env:AUTOPAQET_SERVER="1.2.3.4:9999"; $env:AUTOPAQET_KEY="your-key"; irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-client.ps1 | iex

    Interactive mode (run script directly):
        .\autopaqet-client.ps1

    Direct run mode (bypass menu):
        .\autopaqet-client.ps1 -Run
#>

param(
    [switch]$Run,    # Direct execution mode - bypass menu and run client
    [switch]$Help    # Show help information
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =============================================================================
# Configuration
# =============================================================================
$script:AutoPaqetRepoUrl = "https://raw.githubusercontent.com/omid3098/autopaqet/main"
$script:ReleaseBaseUrl = "https://github.com/omid3098/autopaqet/releases/download"
$script:ReleaseTag = "v1.0.0"
$script:WorkDir = Join-Path $env:USERPROFILE "autopaqet"
$script:RequirementsDir = Join-Path $script:WorkDir "requirements"
$script:ExePath = Join-Path $script:RequirementsDir "paqet.exe"
$script:ConfigFile = Join-Path $script:RequirementsDir "client.yaml"
$script:LogFile = Join-Path $script:RequirementsDir "setup.log"
$script:TranscriptPath = $null

# =============================================================================
# Logging Functions
# =============================================================================
$script:LoggingInitialized = $false

function Initialize-Logging {
    param([string]$LogDirectory, [switch]$EnableTranscript)
    if (-not (Test-Path $LogDirectory)) { New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null }
    $script:LogFile = Join-Path $LogDirectory "setup.log"
    Set-Content -Path $script:LogFile -Value "" -Encoding UTF8
    if ($EnableTranscript) {
        $script:TranscriptPath = Join-Path $LogDirectory "setup-transcript.log"
        try {
            Start-Transcript -Path $script:TranscriptPath -Force | Out-Null
        } catch {
            # Transcript may fail in certain contexts (e.g., already running) - non-critical
            $script:TranscriptPath = $null
        }
    }
    $script:LoggingInitialized = $true
    Write-Log "========== AUTOPAQET CLIENT LOG ==========" -Level "INFO"
    Write-Log "Hostname: $env:COMPUTERNAME" -Level "INFO"
    Write-Log "Windows: $([System.Environment]::OSVersion.VersionString)" -Level "INFO"
}

function Write-Log {
    param([string]$Message, [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG", "COMMAND")][string]$Level = "INFO")
    if (-not $script:LoggingInitialized -or -not $script:LogFile) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $script:LogFile -Value "[$timestamp] [$Level] $Message" -Encoding UTF8
}

function Write-Info { param($msg); Write-Host "[INFO] $msg" -ForegroundColor Cyan; Write-Log $msg -Level "INFO" }
function Write-Success { param($msg); Write-Host "[OK] $msg" -ForegroundColor Green; Write-Log $msg -Level "SUCCESS" }
function Write-Warn { param($msg); Write-Host "[WARN] $msg" -ForegroundColor Yellow; Write-Log $msg -Level "WARN" }
function Write-ErrorAndExit {
    param([string]$Message, [int]$ExitCode = 1)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Write-Log $Message -Level "ERROR"
    if ($script:TranscriptPath) { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null }
    Write-Host "`nIf setup failed, please send this file:" -ForegroundColor Yellow
    Write-Host "  $($script:LogFile)" -ForegroundColor White
    exit $ExitCode
}

function Stop-Logging { if ($script:TranscriptPath) { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } }

# =============================================================================
# Validation Functions
# =============================================================================
function Test-ServerAddress {
    param([Parameter(Mandatory)][string]$Address)
    if ($Address -notmatch '^(\d{1,3}\.){3}\d{1,3}:\d{1,5}$') { return $false }
    $parts = $Address -split ':'; $ip = $parts[0]; $port = [int]$parts[1]
    $octets = $ip -split '\.'; foreach ($o in $octets) { if ([int]$o -gt 255) { return $false } }
    if ($port -lt 1 -or $port -gt 65535) { return $false }
    if ($ip -eq "127.0.0.1" -or $ip -eq "0.0.0.0") { Write-Warning "Using localhost is usually incorrect for remote servers." }
    return $true
}

# =============================================================================
# Network Functions
# =============================================================================
function Get-NetworkConfiguration {
    $defaultRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
    if (-not $defaultRoute) { throw "No active internet connection detected." }
    $adapter = Get-NetAdapter -InterfaceIndex $defaultRoute.InterfaceIndex
    $ipInfo = Get-NetIPAddress -InterfaceIndex $defaultRoute.InterfaceIndex -AddressFamily IPv4
    if (-not $adapter -or -not $ipInfo) { throw "Failed to resolve network adapter details." }
    $gatewayIP = $defaultRoute.NextHop
    $gatewayMAC = $null
    if ($gatewayIP -ne "0.0.0.0") {
        Test-Connection -ComputerName $gatewayIP -Count 1 -Quiet -ErrorAction SilentlyContinue | Out-Null
        $arp = Get-NetNeighbor -IPAddress $gatewayIP -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $gatewayMAC = $arp.LinkLayerAddress
    }
    if (-not $gatewayMAC) { throw "Could not detect Gateway MAC address." }
    return @{
        InterfaceName = $adapter.Name; InterfaceGUID = $adapter.InterfaceGuid
        LocalIP = $ipInfo.IPAddress; GatewayIP = $gatewayIP; GatewayMAC = $gatewayMAC
        NpcapGUID = "\Device\NPF_$($adapter.InterfaceGuid)"
    }
}

function Test-NpcapInstalled {
    $p32 = "$env:SystemRoot\System32\Npcap\wpcap.dll"; $p64 = "$env:SystemRoot\SysWOW64\Npcap\wpcap.dll"
    return (Test-Path $p32) -or (Test-Path $p64)
}

# =============================================================================
# Menu Functions
# =============================================================================
function Show-Menu {
    param([string]$Title, [string[]]$Options, [string]$Footer = "")
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "         $Title" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $Options.Length; $i++) { Write-Host "  [$($i + 1)] $($Options[$i])" -ForegroundColor White }
    Write-Host ""; Write-Host "  [0] Exit" -ForegroundColor Yellow; Write-Host ""
    if ($Footer) { Write-Host $Footer -ForegroundColor DarkGray; Write-Host "" }
    $choice = Read-Host "Select option"
    if ($choice -match '^\d+$') { $num = [int]$choice; if ($num -ge 0 -and $num -le $Options.Length) { return $num } }
    return -1
}

function Show-SubMenu {
    param([string]$Title, [string[]]$Options)
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "         $Title" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $Options.Length; $i++) { Write-Host "  [$($i + 1)] $($Options[$i])" -ForegroundColor White }
    Write-Host ""; Write-Host "  [0] Back" -ForegroundColor Yellow; Write-Host ""
    $choice = Read-Host "Select option"
    if ($choice -match '^\d+$') { $num = [int]$choice; if ($num -ge 0 -and $num -le $Options.Length) { return $num } }
    return -1
}

function Show-Confirmation {
    param([string]$Message, [bool]$DefaultYes = $true)
    $prompt = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $response = Read-Host "$Message $prompt"
    if ([string]::IsNullOrWhiteSpace($response)) { return $DefaultYes }
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Wait-ForKeypress { Write-Host ""; Read-Host "Press Enter to continue" }

function Test-InteractiveMode { return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected }

# =============================================================================
# Installation State Detection
# =============================================================================
function Get-InstallationState {
    $state = @{
        BinaryExists      = $false
        ConfigExists      = $false
        ConfigValid       = $false
        IsFullyInstalled  = $false
        State             = "NotInstalled"
        Issues            = @()
    }

    # Check binary
    $state.BinaryExists = Test-Path $script:ExePath
    if (-not $state.BinaryExists) {
        $state.Issues += "Binary not found"
    }

    # Check config file
    $state.ConfigExists = Test-Path $script:ConfigFile
    if (-not $state.ConfigExists) {
        $state.Issues += "Configuration not found"
    } else {
        # Validate config content
        try {
            $configContent = Get-Content $script:ConfigFile -Raw -ErrorAction Stop
            $hasServer = $configContent -match 'server:\s*\n\s*addr:\s*"[^"]+"'
            $hasKey = $configContent -match 'key:\s*"[^"]+"'
            $hasInterface = $configContent -match 'interface:\s*"[^"]+"'

            if (-not $hasServer) { $state.Issues += "Missing server address" }
            if (-not $hasKey) { $state.Issues += "Missing secret key" }
            if (-not $hasInterface) { $state.Issues += "Missing network interface" }

            $state.ConfigValid = $hasServer -and $hasKey -and $hasInterface
        } catch {
            $state.Issues += "Failed to read configuration"
        }
    }

    # Determine overall state
    if ($state.BinaryExists -and $state.ConfigValid) {
        $state.State = "Ready"
        $state.IsFullyInstalled = $true
    } elseif ($state.BinaryExists -and $state.ConfigExists) {
        $state.State = "Configured"
    } elseif ($state.BinaryExists -or $state.ConfigExists) {
        $state.State = "PartialInstall"
    } else {
        $state.State = "NotInstalled"
    }

    return $state
}

function Invoke-RunClient {
    param([switch]$ReturnToMenu)

    $installState = Get-InstallationState

    if (-not $installState.BinaryExists) {
        Write-Host "`n[ERROR] AutoPaqet binary not found." -ForegroundColor Red
        Write-Host "Expected: $($script:ExePath)" -ForegroundColor Yellow
        Write-Host "`nPlease run Fresh Install first." -ForegroundColor Yellow
        if ($ReturnToMenu) { Wait-ForKeypress; return $false }
        exit 1
    }

    if (-not $installState.ConfigExists) {
        Write-Host "`n[ERROR] Configuration file not found." -ForegroundColor Red
        Write-Host "Expected: $($script:ConfigFile)" -ForegroundColor Yellow
        Write-Host "`nPlease run Fresh Install first." -ForegroundColor Yellow
        if ($ReturnToMenu) { Wait-ForKeypress; return $false }
        exit 1
    }

    if (-not $installState.ConfigValid) {
        Write-Host "`n[WARN] Configuration may be incomplete:" -ForegroundColor Yellow
        foreach ($issue in $installState.Issues) {
            Write-Host "  - $issue" -ForegroundColor Yellow
        }
        if (Test-InteractiveMode) {
            if (-not (Show-Confirmation "`nAttempt to run anyway?")) {
                if ($ReturnToMenu) { return $false }
                exit 1
            }
        }
    }

    Write-Host "`n[INFO] Starting AutoPaqet Client..." -ForegroundColor Cyan
    Write-Host "Config: $($script:ConfigFile)" -ForegroundColor Gray
    Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor Gray

    try {
        & $script:ExePath run -c $script:ConfigFile
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Host "`n[WARN] Client exited with code: $exitCode" -ForegroundColor Yellow
        } else {
            Write-Host "`n[INFO] Client stopped." -ForegroundColor Cyan
        }
    } catch {
        Write-Host "`n[ERROR] Failed to start client: $_" -ForegroundColor Red
        if ($ReturnToMenu) { Wait-ForKeypress; return $false }
        exit 1
    }

    if ($ReturnToMenu -and (Test-InteractiveMode)) {
        Write-Host ""
        $action = Read-Host "Press Enter to return to menu, or 'q' to exit"
        if ($action -eq 'q' -or $action -eq 'Q') { exit 0 }
    }

    return $true
}

# =============================================================================
# Dependencies Configuration
# =============================================================================

# =============================================================================
# Core Functions
# =============================================================================
function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminElevation {
    Write-Host "[WARN] Administrator privileges required. Requesting elevation..." -ForegroundColor Yellow
    $envParams = ""
    if ($env:AUTOPAQET_SERVER) { $envParams += "`$env:AUTOPAQET_SERVER='$env:AUTOPAQET_SERVER'; " }
    if ($env:AUTOPAQET_KEY) { $envParams += "`$env:AUTOPAQET_KEY='$env:AUTOPAQET_KEY'; " }
    $scriptUrl = "$($script:AutoPaqetRepoUrl)/autopaqet-client.ps1"
    $elevatedCmd = "${envParams}irm '$scriptUrl' | iex"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile", "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $elevatedCmd
    exit
}

function Get-MissingDependencies {
    $missing = @()
    if (-not (Test-NpcapInstalled)) { $missing += "Npcap" }
    return $missing
}

function Install-Dependency {
    param([string]$Name, [string]$DownloadDir, [bool]$Silent = $false)

    if ($Name -eq "Npcap") {
        $url = "https://npcap.com/dist/npcap-1.80.exe"
        $dest = Join-Path $DownloadDir "npcap-setup.exe"
        if (-not (Test-Path $dest)) {
            Write-Info "Downloading Npcap..."
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        }
        if ($Silent) {
            Write-Info "Installing Npcap silently..."
            $proc = Start-Process $dest -ArgumentList "/S /winpcap_mode=yes" -Wait -PassThru
        } else {
            Write-Warn "IMPORTANT: Check 'Install Npcap in WinPcap API-compatible Mode' during setup."
            Read-Host "Press Enter to start Npcap setup..."
            $proc = Start-Process $dest -Wait -PassThru
        }
        return ($proc.ExitCode -eq 0)
    }

    return $false
}

function Get-PaqetBinary {
    param([switch]$Force)

    if ((Test-Path $script:ExePath) -and -not $Force) {
        Write-Success "Binary already exists: $($script:ExePath)"
        return
    }

    $url = "$($script:ReleaseBaseUrl)/$($script:ReleaseTag)/paqet-windows-amd64.exe"
    Write-Info "Downloading AutoPaqet binary..."

    $parentDir = Split-Path $script:ExePath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    Invoke-WebRequest -Uri $url -OutFile $script:ExePath -UseBasicParsing
    if (-not (Test-Path $script:ExePath)) {
        throw "Failed to download binary from: $url"
    }
    Write-Success "Binary downloaded: $($script:ExePath)"
}

function New-ClientConfig {
    param([hashtable]$NetworkConfig, [string]$ServerAddress, [string]$SecretKey)

    $randomPort = Get-Random -Minimum 10000 -Maximum 65000
    $content = @"
role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:1080"

network:
  interface: "$($NetworkConfig.InterfaceName)"
  guid: '$($NetworkConfig.NpcapGUID)'
  ipv4:
    addr: "$($NetworkConfig.LocalIP):$randomPort"
    router_mac: "$($NetworkConfig.GatewayMAC)"
  tcp:
    local_flag: ["S"]
    remote_flag: ["PA"]

server:
  addr: "$ServerAddress"

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    key: "$SecretKey"
    block: "aes"
"@
    Set-Content -Path $script:ConfigFile -Value $content -Encoding Ascii
    Write-Success "Configuration created: $($script:ConfigFile)"
}

function New-Shortcuts {
    $WshShell = New-Object -ComObject WScript.Shell

    $setAdmin = {
        param($path)
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $bytes[0x15] = $bytes[0x15] -bor 0x20
        [System.IO.File]::WriteAllBytes($path, $bytes)
    }

    # Save the script locally for shortcut execution
    $localScriptPath = Join-Path $script:WorkDir "autopaqet-client.ps1"
    if (-not (Test-Path $localScriptPath)) {
        try {
            $scriptUrl = "$($script:AutoPaqetRepoUrl)/autopaqet-client.ps1"
            Invoke-WebRequest -Uri $scriptUrl -OutFile $localScriptPath -UseBasicParsing
        } catch {
            # If download fails and we're running from a file, copy it
            $currentScript = $MyInvocation.ScriptName
            if ($currentScript -and (Test-Path $currentScript)) {
                Copy-Item -Path $currentScript -Destination $localScriptPath -Force
            }
        }
    }

    # Desktop shortcut - launches with -Run flag for direct execution
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $desktopShortcut = Join-Path $desktopPath "AutoPaqet.lnk"
    $shortcut = $WshShell.CreateShortcut($desktopShortcut)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$localScriptPath`" -Run"
    $shortcut.WorkingDirectory = $script:WorkDir
    $shortcut.Description = "AutoPaqet SOCKS5 Proxy Client"
    $shortcut.Save()
    & $setAdmin $desktopShortcut

    # Start Menu shortcut - same as desktop
    $startMenuPath = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs"
    $startMenuShortcut = Join-Path $startMenuPath "AutoPaqet.lnk"
    $shortcut = $WshShell.CreateShortcut($startMenuShortcut)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$localScriptPath`" -Run"
    $shortcut.WorkingDirectory = $script:WorkDir
    $shortcut.Description = "AutoPaqet SOCKS5 Proxy Client"
    $shortcut.Save()
    & $setAdmin $startMenuShortcut

    # Manager shortcut - opens menu for configuration/diagnostics
    $managerShortcut = Join-Path $startMenuPath "AutoPaqet Manager.lnk"
    $shortcut = $WshShell.CreateShortcut($managerShortcut)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$localScriptPath`""
    $shortcut.WorkingDirectory = $script:WorkDir
    $shortcut.Description = "AutoPaqet Configuration Manager"
    $shortcut.Save()
    & $setAdmin $managerShortcut

    # Uninstall shortcut
    $uninstallShortcut = Join-Path $startMenuPath "Uninstall AutoPaqet.lnk"
    $shortcut = $WshShell.CreateShortcut($uninstallShortcut)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$($script:AutoPaqetRepoUrl)/autopaqet-uninstall.ps1' | iex`""
    $shortcut.Description = "Uninstall AutoPaqet"
    $shortcut.Save()
    & $setAdmin $uninstallShortcut

    Write-Success "Shortcuts created (Desktop, Start Menu, Manager)"
}

# =============================================================================
# Menu Handlers
# =============================================================================
function Invoke-FreshInstall {
    # Setup directories
    if (-not (Test-Path $script:WorkDir)) { New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null }
    if (-not (Test-Path $script:RequirementsDir)) { New-Item -ItemType Directory -Path $script:RequirementsDir | Out-Null }

    # Initialize logging
    Initialize-Logging -LogDirectory $script:RequirementsDir -EnableTranscript

    Write-Host @"

=============================================
        AUTOPAQET CLIENT (WINDOWS)
=============================================
"@ -ForegroundColor Cyan

    # Check dependencies
    Write-Info "Checking system requirements..."
    $missing = Get-MissingDependencies

    if ($missing.Count -gt 0) {
        Write-Host "`nMissing dependencies:" -ForegroundColor Yellow
        foreach ($dep in $missing) { Write-Host "  - $dep" -ForegroundColor White }
        Write-Host ""

        $isInteractive = Test-InteractiveMode
        $shouldInstall = $true

        if ($isInteractive) {
            $shouldInstall = Show-Confirmation "Install all missing dependencies?"
        } else {
            Write-Info "Auto-installing dependencies (non-interactive mode)..."
        }

        if ($shouldInstall) {
            foreach ($dep in $missing) {
                $silent = -not $isInteractive -or $dep -ne "Npcap"
                Install-Dependency -Name $dep -DownloadDir $script:RequirementsDir -Silent $silent
                Write-Success "$dep ready."
            }
        }
    } else {
        Write-Success "All dependencies installed."
    }

    # Download pre-built binary
    Get-PaqetBinary

    # Network detection
    Write-Info "Detecting network configuration..."
    $networkConfig = Get-NetworkConfiguration
    Write-Success "Interface:   $($networkConfig.InterfaceName)"
    Write-Success "Local IP:    $($networkConfig.LocalIP)"
    Write-Success "Gateway IP:  $($networkConfig.GatewayIP)"
    Write-Success "Gateway MAC: $($networkConfig.GatewayMAC)"

    # Configuration
    if (-not (Test-Path $script:ConfigFile)) {
        Write-Host "`n[SETUP] Configuration Required" -ForegroundColor Yellow

        $serverInput = $env:AUTOPAQET_SERVER
        if ([string]::IsNullOrWhiteSpace($serverInput)) {
            $isInteractive = Test-InteractiveMode
            if ($isInteractive) {
                Write-Host "`nServer address is REQUIRED. This is your paqet server's public IP." -ForegroundColor Yellow
                do {
                    $serverInput = Read-Host "Enter Server Address (e.g., 203.0.113.50:9999)"
                    if ([string]::IsNullOrWhiteSpace($serverInput)) {
                        Write-Warn "Server address cannot be empty."
                    } elseif (-not (Test-ServerAddress $serverInput)) {
                        Write-Warn "Invalid format. Use IP:PORT (e.g., 1.2.3.4:9999)"
                        $serverInput = ""
                    }
                } while ([string]::IsNullOrWhiteSpace($serverInput))
            } else {
                Write-ErrorAndExit "AUTOPAQET_SERVER environment variable is required for non-interactive installation."
            }
        }
        Write-Info "Server address: $serverInput"

        $keyInput = $env:AUTOPAQET_KEY
        if ([string]::IsNullOrWhiteSpace($keyInput)) {
            $isInteractive = Test-InteractiveMode
            if ($isInteractive) {
                $keyInput = Read-Host "Enter Secret Key (Must match server) [Leave empty to auto-generate]"
            }
        }
        if ([string]::IsNullOrWhiteSpace($keyInput)) {
            Write-Info "Generating new key..."
            $keyInput = & $script:ExePath secret
        }

        New-ClientConfig -NetworkConfig $networkConfig -ServerAddress $serverInput -SecretKey $keyInput
    } else {
        Write-Success "Configuration exists: $($script:ConfigFile)"
        Write-Warn "Using existing config. Delete client.yaml and re-run if network changed."
    }

    # Create shortcuts
    Write-Info "Creating shortcuts..."
    New-Shortcuts

    # Done
    Write-Log "Setup complete" -Level "SUCCESS"
    Write-Host "`n[READY] Setup Complete." -ForegroundColor Green
    Write-Host "`nLog file: $($script:LogFile)" -ForegroundColor Yellow

    Stop-Logging

    # Launch
    Write-Info "Starting AutoPaqet Client..."
    & $script:ExePath run -c $script:ConfigFile
}

function Invoke-UpdateAutoPaqet {
    Write-Info "Downloading latest installer scripts from GitHub..."
    try {
        $clientUrl = "$($script:AutoPaqetRepoUrl)/autopaqet-client.ps1"
        $uninstallUrl = "$($script:AutoPaqetRepoUrl)/autopaqet-uninstall.ps1"

        Invoke-WebRequest -Uri $clientUrl -OutFile (Join-Path $script:WorkDir "autopaqet-client.ps1") -UseBasicParsing
        Invoke-WebRequest -Uri $uninstallUrl -OutFile (Join-Path $script:WorkDir "autopaqet-uninstall.ps1") -UseBasicParsing

        Write-Success "Installer scripts updated in: $($script:WorkDir)"
    } catch {
        Write-Host "[ERROR] Failed to download: $_" -ForegroundColor Red
    }
    Wait-ForKeypress
}

function Invoke-UpdatePaqet {
    Write-Info "Updating Paqet..."
    try {
        Get-PaqetBinary -Force
        Write-Success "Paqet updated successfully!"
    } catch {
        Write-Host "[ERROR] Update failed: $_" -ForegroundColor Red
    }
    Wait-ForKeypress
}

function Invoke-Uninstall {
    Write-Info "Launching uninstaller..."
    $uninstallUrl = "$($script:AutoPaqetRepoUrl)/autopaqet-uninstall.ps1"
    $script = Invoke-WebRequest -Uri $uninstallUrl -UseBasicParsing
    Invoke-Expression $script.Content
}

function Show-ConfigurationMenu {
    $options = @("View Current Configuration", "Edit Server Address", "Edit Secret Key", "Edit TCP Local Flag", "Re-detect Network")

    while ($true) {
        $choice = Show-SubMenu -Title "CONFIGURATION" -Options $options

        switch ($choice) {
            0 { return }
            1 {
                if (Test-Path $script:ConfigFile) {
                    Write-Host "`nCurrent Configuration:" -ForegroundColor Cyan
                    Write-Host "File: $($script:ConfigFile)" -ForegroundColor Yellow
                    Write-Host ""; Get-Content $script:ConfigFile
                } else { Write-Host "`nNo configuration file found." -ForegroundColor Yellow }
                Wait-ForKeypress
            }
            2 {
                if (-not (Test-Path $script:ConfigFile)) {
                    Write-Host "`nNo configuration file found. Run Fresh Install first." -ForegroundColor Yellow
                } else {
                    $content = Get-Content $script:ConfigFile -Raw
                    $newAddr = Read-Host "Enter new server address (IP:PORT)"
                    if (Test-ServerAddress $newAddr) {
                        $content = $content -replace '(server:\s*\n\s*addr:\s*)"[^"]+"', "`$1`"$newAddr`""
                        Set-Content -Path $script:ConfigFile -Value $content -Encoding Ascii -NoNewline
                        Write-Success "Server address updated to: $newAddr"
                    } else { Write-Host "[ERROR] Invalid address format." -ForegroundColor Red }
                }
                Wait-ForKeypress
            }
            3 {
                if (-not (Test-Path $script:ConfigFile)) {
                    Write-Host "`nNo configuration file found. Run Fresh Install first." -ForegroundColor Yellow
                } else {
                    $content = Get-Content $script:ConfigFile -Raw
                    $newKey = Read-Host "Enter new secret key (or press Enter to auto-generate)"
                    if ([string]::IsNullOrWhiteSpace($newKey) -and (Test-Path $script:ExePath)) {
                        $newKey = & $script:ExePath secret
                        Write-Info "Generated new key: $newKey"
                    }
                    if (-not [string]::IsNullOrWhiteSpace($newKey)) {
                        $content = $content -replace '(key:\s*)"[^"]+"', "`$1`"$newKey`""
                        Set-Content -Path $script:ConfigFile -Value $content -Encoding Ascii -NoNewline
                        Write-Success "Secret key updated."
                    }
                }
                Wait-ForKeypress
            }
            4 {
                if (-not (Test-Path $script:ConfigFile)) {
                    Write-Host "`nNo configuration file found. Run Fresh Install first." -ForegroundColor Yellow
                } else {
                    $content = Get-Content $script:ConfigFile -Raw
                    $currentFlag = if ($content -match 'local_flag:\s*\["([^"]+)"\]') { $Matches[1] } else { "unknown" }

                    Write-Host "`nCurrent TCP Local Flag: [$currentFlag]" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "  [1] S   - SYN (connection setup)" -ForegroundColor White
                    Write-Host "  [2] PA  - PSH+ACK (standard data)" -ForegroundColor White
                    Write-Host "  [3] A   - ACK (acknowledgment)" -ForegroundColor White
                    Write-Host ""
                    Write-Host "  [0] Cancel" -ForegroundColor Yellow

                    $flagChoice = Read-Host "`nSelect option"
                    $newFlag = switch ($flagChoice) { "1" { "S" } "2" { "PA" } "3" { "A" } default { $null } }

                    if ($newFlag) {
                        $content = $content -replace '(local_flag:\s*\[")[^"]+("\])', "`$1$newFlag`$2"
                        Set-Content -Path $script:ConfigFile -Value $content -Encoding Ascii -NoNewline
                        Write-Success "TCP local_flag updated to: [$newFlag]"
                    } elseif ($flagChoice -ne "0") {
                        Write-Host "[ERROR] Invalid selection." -ForegroundColor Red
                    }
                }
                Wait-ForKeypress
            }
            5 {
                Write-Info "Re-detecting network configuration..."
                try {
                    $networkConfig = Get-NetworkConfiguration
                    Write-Success "Interface:   $($networkConfig.InterfaceName)"
                    Write-Success "Local IP:    $($networkConfig.LocalIP)"
                    Write-Success "Gateway IP:  $($networkConfig.GatewayIP)"
                    Write-Success "Gateway MAC: $($networkConfig.GatewayMAC)"

                    if ((Test-Path $script:ConfigFile) -and (Show-Confirmation "`nUpdate configuration with new network settings?")) {
                        $content = Get-Content $script:ConfigFile -Raw
                        $content = $content -replace '(interface:\s*)"[^"]+"', "`$1`"$($networkConfig.InterfaceName)`""
                        $content = $content -replace "(guid:\s*)'[^']+'", "`$1'$($networkConfig.NpcapGUID)'"
                        $content = $content -replace '(router_mac:\s*)"[^"]+"', "`$1`"$($networkConfig.GatewayMAC)`""
                        $content = $content -replace '(addr:\s*)"(\d+\.\d+\.\d+\.\d+):(\d+)"', "`$1`"$($networkConfig.LocalIP):`$3`""
                        Set-Content -Path $script:ConfigFile -Value $content -Encoding Ascii -NoNewline
                        Write-Success "Configuration updated."
                    }
                } catch { Write-Host "[ERROR] Network detection failed: $_" -ForegroundColor Red }
                Wait-ForKeypress
            }
            -1 { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Show-DiagnosticsMenu {
    $options = @("Test Server Connection", "View Setup Log", "Network Info")

    while ($true) {
        $choice = Show-SubMenu -Title "DIAGNOSTICS" -Options $options

        switch ($choice) {
            0 { return }
            1 {
                if (Test-Path $script:ExePath) {
                    $configContent = Get-Content $script:ConfigFile -Raw -ErrorAction SilentlyContinue
                    if ($configContent -match 'server:\s*\n\s*addr:\s*"([^"]+)"') {
                        $serverAddr = $Matches[1]
                        Write-Info "Testing connection to $serverAddr..."
                        & $script:ExePath ping -s $serverAddr
                    } else { Write-Host "[ERROR] Could not find server address in config." -ForegroundColor Red }
                } else { Write-Host "[ERROR] Binary not found. Run Fresh Install first." -ForegroundColor Red }
                Wait-ForKeypress
            }
            2 {
                if (Test-Path $script:LogFile) {
                    Write-Host "`nSetup Log ($($script:LogFile)):" -ForegroundColor Cyan
                    Write-Host ""; Get-Content $script:LogFile -Tail 50
                } else { Write-Host "`nNo log file found." -ForegroundColor Yellow }
                Wait-ForKeypress
            }
            3 {
                Write-Info "Current network configuration:"
                try {
                    $networkConfig = Get-NetworkConfiguration
                    Write-Host ""
                    Write-Host "Interface:   $($networkConfig.InterfaceName)" -ForegroundColor White
                    Write-Host "Local IP:    $($networkConfig.LocalIP)" -ForegroundColor White
                    Write-Host "Gateway IP:  $($networkConfig.GatewayIP)" -ForegroundColor White
                    Write-Host "Gateway MAC: $($networkConfig.GatewayMAC)" -ForegroundColor White
                    Write-Host "Npcap GUID:  $($networkConfig.NpcapGUID)" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Npcap Installed: $(if (Test-NpcapInstalled) { 'Yes' } else { 'No' })" -ForegroundColor White
                } catch { Write-Host "[ERROR] Network detection failed: $_" -ForegroundColor Red }
                Wait-ForKeypress
            }
            -1 { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Show-MainMenuLoop {
    while ($true) {
        # Detect installation state for adaptive menu
        $installState = Get-InstallationState

        # Build menu options based on state
        $options = @()
        $actions = @{}
        $optionIndex = 1

        if ($installState.IsFullyInstalled) {
            # Installed and configured - prioritize running
            $options += "Run Client"
            $actions[$optionIndex++] = "RunClient"

            $options += "Configuration"
            $actions[$optionIndex++] = "Configuration"

            $options += "Diagnostics"
            $actions[$optionIndex++] = "Diagnostics"

            $options += "Update Paqet (download latest)"
            $actions[$optionIndex++] = "UpdatePaqet"

            $options += "Update AutoPaqet (download latest installer)"
            $actions[$optionIndex++] = "UpdateAutoPaqet"

            $options += "Reinstall (Fresh Install)"
            $actions[$optionIndex++] = "FreshInstall"

            $options += "Uninstall"
            $actions[$optionIndex++] = "Uninstall"
        } elseif ($installState.State -eq "Configured" -or $installState.State -eq "PartialInstall") {
            # Partial installation - show repair options first
            $options += "Complete/Repair Installation"
            $actions[$optionIndex++] = "FreshInstall"

            if ($installState.BinaryExists) {
                $options += "Run Client (may have issues)"
                $actions[$optionIndex++] = "RunClient"
            }

            $options += "Configuration"
            $actions[$optionIndex++] = "Configuration"

            $options += "Diagnostics"
            $actions[$optionIndex++] = "Diagnostics"

            $options += "Uninstall"
            $actions[$optionIndex++] = "Uninstall"
        } else {
            # Not installed - prioritize fresh install
            $options += "Fresh Install"
            $actions[$optionIndex++] = "FreshInstall"

            $options += "Diagnostics"
            $actions[$optionIndex++] = "Diagnostics"
        }

        # Status footer
        $statusColor = switch ($installState.State) {
            "Ready" { "Green" }
            "Configured" { "Yellow" }
            "PartialInstall" { "Yellow" }
            default { "Gray" }
        }
        $statusText = switch ($installState.State) {
            "Ready" { "Status: Ready to run" }
            "Configured" { "Status: Configured (validation issues)" }
            "PartialInstall" { "Status: Partial installation" }
            default { "Status: Not installed" }
        }
        $footer = $statusText
        if ($installState.Issues.Count -gt 0 -and $installState.State -ne "Ready") {
            $footer += " | Issues: $($installState.Issues -join '; ')"
        }

        $choice = Show-Menu -Title "AUTOPAQET CLIENT" -Options $options -Footer $footer

        if ($choice -eq 0) { return }
        if ($choice -eq -1) {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
            continue
        }

        # Execute selected action
        $action = $actions[$choice]
        switch ($action) {
            "RunClient" { Invoke-RunClient -ReturnToMenu }
            "FreshInstall" { Invoke-FreshInstall; return }
            "Configuration" { Show-ConfigurationMenu }
            "Diagnostics" { Show-DiagnosticsMenu }
            "UpdatePaqet" { Invoke-UpdatePaqet }
            "UpdateAutoPaqet" { Invoke-UpdateAutoPaqet }
            "Uninstall" { Invoke-Uninstall; return }
        }
    }
}

# =============================================================================
# Main Entry Point
# =============================================================================

# Show help if requested
if ($Help) {
    Write-Host @"

AutoPaqet Client for Windows
============================

USAGE:
    .\autopaqet-client.ps1              # Interactive menu mode
    .\autopaqet-client.ps1 -Run         # Direct execution (bypass menu)
    .\autopaqet-client.ps1 -Help        # Show this help

ONE-LINER INSTALLATION:
    irm https://raw.githubusercontent.com/omid3098/autopaqet/main/autopaqet-client.ps1 | iex

WITH SERVER CONFIGURATION:
    `$env:AUTOPAQET_SERVER="1.2.3.4:9999"; `$env:AUTOPAQET_KEY="your-key"; irm ... | iex

PARAMETERS:
    -Run    Start the client directly without showing menu
            Requires prior installation and configuration

    -Help   Display this help message

"@ -ForegroundColor Cyan
    exit 0
}

# Check admin privileges
if (-not (Test-AdminPrivileges)) {
    # Pass through -Run flag if specified during elevation
    if ($Run) {
        $localScript = Join-Path $script:WorkDir "autopaqet-client.ps1"
        if (Test-Path $localScript) {
            Start-Process powershell.exe -Verb RunAs -ArgumentList `
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$localScript`"", "-Run"
        } else {
            # If script not found locally, re-download and run
            $envParams = ""
            if ($env:AUTOPAQET_SERVER) { $envParams += "`$env:AUTOPAQET_SERVER='$env:AUTOPAQET_SERVER'; " }
            if ($env:AUTOPAQET_KEY) { $envParams += "`$env:AUTOPAQET_KEY='$env:AUTOPAQET_KEY'; " }
            $scriptUrl = "$($script:AutoPaqetRepoUrl)/autopaqet-client.ps1"
            $elevatedCmd = "${envParams}irm '$scriptUrl' | iex"
            Start-Process powershell.exe -Verb RunAs -ArgumentList `
                "-NoProfile", "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $elevatedCmd
        }
        exit
    }
    Request-AdminElevation
}

# Detect mode: piped (one-liner) or interactive
$isPiped = [Console]::IsInputRedirected

if ($Run) {
    # Direct run mode: execute client immediately
    Invoke-RunClient
    exit $LASTEXITCODE
} elseif ($isPiped) {
    # One-liner mode: run fresh install directly
    Invoke-FreshInstall
} else {
    # Interactive mode: show smart menu
    Show-MainMenuLoop
}
