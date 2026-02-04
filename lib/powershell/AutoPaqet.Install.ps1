# AutoPaqet Installation Functions
# Windows-specific dependency installation and build logic

# Configuration constants
$script:RepoUrl = "https://github.com/hanselime/paqet.git"
$script:AutoPaqetRepoUrl = "https://raw.githubusercontent.com/omid3098/autopaqet/main"

$script:Dependencies = @{
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

$script:NpcapConfig = @{
    "URL"  = "https://npcap.com/dist/npcap-1.80.exe"
    "File" = "npcap-setup.exe"
    "SilentArgs" = "/S /winpcap_mode=yes"
}

function Get-MissingDependencies {
    <#
    .SYNOPSIS
        Checks which dependencies are missing.
    .OUTPUTS
        Array of missing dependency names
    #>
    [CmdletBinding()]
    param()

    $missing = @()

    foreach ($depName in $script:Dependencies.Keys) {
        $dep = $script:Dependencies[$depName]
        $checkResult = & $dep.Check
        if (-not $checkResult) {
            $missing += $depName
        }
    }

    # Check Npcap separately
    $npcapPath32 = "$env:SystemRoot\System32\Npcap\wpcap.dll"
    $npcapPath64 = "$env:SystemRoot\SysWOW64\Npcap\wpcap.dll"
    if (-not ((Test-Path $npcapPath32) -or (Test-Path $npcapPath64))) {
        $missing += "Npcap"
    }

    return $missing
}

function Install-Dependency {
    <#
    .SYNOPSIS
        Installs a specific dependency.
    .PARAMETER Name
        Name of the dependency (Git, Go, GCC, Npcap)
    .PARAMETER DownloadDir
        Directory to download installers to
    .PARAMETER Silent
        If true, install silently without prompts
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Git", "Go", "GCC", "Npcap")]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$DownloadDir,

        [bool]$Silent = $false
    )

    # Handle Npcap separately
    if ($Name -eq "Npcap") {
        return Install-Npcap -DownloadDir $DownloadDir -Silent $Silent
    }

    $dep = $script:Dependencies[$Name]
    if (-not $dep) {
        return $false
    }

    $dest = Join-Path $DownloadDir $dep.File

    # Download if not cached
    if (-not (Test-Path $dest)) {
        try {
            Invoke-WebRequest -Uri $dep.URL -OutFile $dest -UseBasicParsing
        } catch {
            return $false
        }
    }

    # Install
    if ($dep.MSI) {
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$dest`" $($dep.Args)" -Wait -PassThru
    } else {
        $proc = Start-Process $dest -ArgumentList $dep.Args -Wait -PassThru
    }

    return ($proc.ExitCode -eq 0)
}

function Install-Npcap {
    <#
    .SYNOPSIS
        Installs Npcap with WinPcap compatibility mode.
    .PARAMETER DownloadDir
        Directory to download installer to
    .PARAMETER Silent
        If true, install silently
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DownloadDir,

        [bool]$Silent = $false
    )

    $dest = Join-Path $DownloadDir $script:NpcapConfig.File

    # Download if not cached
    if (-not (Test-Path $dest)) {
        try {
            Invoke-WebRequest -Uri $script:NpcapConfig.URL -OutFile $dest -UseBasicParsing
        } catch {
            return $false
        }
    }

    # Install
    if ($Silent) {
        $proc = Start-Process $dest -ArgumentList $script:NpcapConfig.SilentArgs -Wait -PassThru
    } else {
        # Manual install - user needs to check WinPcap mode
        $proc = Start-Process $dest -Wait -PassThru
    }

    return ($proc.ExitCode -eq 0)
}

function Install-AllDependencies {
    <#
    .SYNOPSIS
        Installs all missing dependencies.
    .PARAMETER DownloadDir
        Directory to download installers to
    .PARAMETER Silent
        If true, install all silently
    .PARAMETER OnProgress
        Optional callback for progress updates: { param($Name, $Status) }
    .OUTPUTS
        Hashtable with results for each dependency
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DownloadDir,

        [bool]$Silent = $false,

        [scriptblock]$OnProgress = $null
    )

    $missing = Get-MissingDependencies
    $results = @{}

    foreach ($dep in $missing) {
        if ($OnProgress) {
            & $OnProgress $dep "Installing"
        }

        $success = Install-Dependency -Name $dep -DownloadDir $DownloadDir -Silent $Silent
        $results[$dep] = $success

        if ($OnProgress) {
            $status = if ($success) { "Completed" } else { "Failed" }
            & $OnProgress $dep $status
        }
    }

    return $results
}

function Invoke-CloneRepository {
    <#
    .SYNOPSIS
        Clones or updates the paqet repository.
    .PARAMETER DestinationDir
        Directory to clone into
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationDir
    )

    # Add safe directory config
    $safeDir = $DestinationDir.Replace('\', '/')

    # Temporarily allow stderr output from git (it writes progress to stderr)
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        git config --global --add safe.directory "$safeDir" 2>&1 | Out-Null

        if (-not (Test-Path $DestinationDir)) {
            # Fresh clone
            $output = git clone --depth 1 $script:RepoUrl "$DestinationDir" 2>&1
            return ($LASTEXITCODE -eq 0)
        } else {
            # Update existing
            Push-Location $DestinationDir
            try {
                $output = git pull 2>&1
                return ($LASTEXITCODE -eq 0)
            } finally {
                Pop-Location
            }
        }
    } finally {
        $ErrorActionPreference = $oldErrorAction
    }
}

function Invoke-BuildBinary {
    <#
    .SYNOPSIS
        Builds the paqet binary.
    .PARAMETER SourceDir
        Directory containing the source code
    .PARAMETER OutputPath
        Path for the output binary
    .PARAMETER Force
        If true, rebuild even if binary exists
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [switch]$Force
    )

    if ((Test-Path $OutputPath) -and -not $Force) {
        return $true  # Binary already exists
    }

    Push-Location $SourceDir
    try {
        $env:CGO_ENABLED = "1"
        $buildOutput = go build -ldflags "-s -w" -trimpath -o "$OutputPath" ./cmd/main.go 2>&1
        return ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
}

function New-DesktopShortcut {
    <#
    .SYNOPSIS
        Creates a desktop shortcut for AutoPaqet.
    .PARAMETER ExePath
        Path to the executable
    .PARAMETER ConfigPath
        Path to the configuration file
    .PARAMETER Name
        Shortcut name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [string]$Name = "AutoPaqet"
    )

    $WshShell = New-Object -ComObject WScript.Shell

    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "$Name.lnk"

    # Use cmd.exe to ensure proper console environment
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "cmd.exe"
    $shortcut.Arguments = "/k `"`"$ExePath`" run -c `"$ConfigPath`"`""
    $shortcut.WorkingDirectory = Split-Path $ExePath -Parent
    $shortcut.Description = "AutoPaqet SOCKS5 Proxy Client"
    $shortcut.Save()

    # Set Run as Administrator flag
    Set-ShortcutRunAsAdmin -ShortcutPath $shortcutPath
}

function New-StartMenuShortcut {
    <#
    .SYNOPSIS
        Creates a Start Menu shortcut for AutoPaqet.
    .PARAMETER ExePath
        Path to the executable
    .PARAMETER ConfigPath
        Path to the configuration file
    .PARAMETER Name
        Shortcut name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [string]$Name = "AutoPaqet"
    )

    $WshShell = New-Object -ComObject WScript.Shell

    $startMenuPath = [Environment]::GetFolderPath("StartMenu")
    $programsPath = Join-Path $startMenuPath "Programs"
    $shortcutPath = Join-Path $programsPath "$Name.lnk"

    # Use cmd.exe to ensure proper console environment
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "cmd.exe"
    $shortcut.Arguments = "/k `"`"$ExePath`" run -c `"$ConfigPath`"`""
    $shortcut.WorkingDirectory = Split-Path $ExePath -Parent
    $shortcut.Description = "AutoPaqet SOCKS5 Proxy Client"
    $shortcut.Save()

    Set-ShortcutRunAsAdmin -ShortcutPath $shortcutPath
}

function New-UninstallShortcut {
    <#
    .SYNOPSIS
        Creates an uninstall shortcut in Start Menu.
    #>
    [CmdletBinding()]
    param()

    $WshShell = New-Object -ComObject WScript.Shell

    $startMenuPath = [Environment]::GetFolderPath("StartMenu")
    $programsPath = Join-Path $startMenuPath "Programs"
    $shortcutPath = Join-Path $programsPath "Uninstall AutoPaqet.lnk"

    $uninstallUrl = "$($script:AutoPaqetRepoUrl)/autopaqet-uninstall.ps1"

    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$uninstallUrl' | iex`""
    $shortcut.Description = "Uninstall AutoPaqet"
    $shortcut.Save()

    Set-ShortcutRunAsAdmin -ShortcutPath $shortcutPath
}

function Set-ShortcutRunAsAdmin {
    <#
    .SYNOPSIS
        Sets the "Run as Administrator" flag on a shortcut.
    .PARAMETER ShortcutPath
        Path to the .lnk file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ShortcutPath
    )

    $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20  # Set SLDF_RUNAS_USER flag
    [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)
}

function Invoke-UpdateAutoPaqet {
    <#
    .SYNOPSIS
        Downloads the latest installer scripts from GitHub.
    .PARAMETER DestinationDir
        Directory to save scripts to
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationDir
    )

    $files = @(
        "autopaqet-client.ps1",
        "autopaqet-uninstall.ps1"
    )

    $success = $true

    foreach ($file in $files) {
        $url = "$($script:AutoPaqetRepoUrl)/$file"
        $dest = Join-Path $DestinationDir $file

        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        } catch {
            $success = $false
        }
    }

    return $success
}

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Checks if running with administrator privileges.
    .OUTPUTS
        Boolean indicating admin status
    #>
    [CmdletBinding()]
    param()

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminElevation {
    <#
    .SYNOPSIS
        Requests elevation to administrator if not already elevated.
    .PARAMETER ScriptUrl
        URL of the script to run elevated
    .PARAMETER EnvVars
        Hashtable of environment variables to preserve
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptUrl,

        [hashtable]$EnvVars = @{}
    )

    $envParams = ""
    foreach ($key in $EnvVars.Keys) {
        $value = $EnvVars[$key]
        if ($value) {
            $envParams += "`$env:$key='$value'; "
        }
    }

    $elevatedCmd = "${envParams}irm '$ScriptUrl' | iex"

    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile", "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $elevatedCmd
}

# Export functions (only when loaded as a module)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Get-MissingDependencies',
        'Install-Dependency',
        'Install-Npcap',
        'Install-AllDependencies',
        'Invoke-CloneRepository',
        'Invoke-BuildBinary',
        'New-DesktopShortcut',
        'New-StartMenuShortcut',
        'New-UninstallShortcut',
        'Set-ShortcutRunAsAdmin',
        'Invoke-UpdateAutoPaqet',
        'Test-AdminPrivileges',
        'Request-AdminElevation'
    )
}
