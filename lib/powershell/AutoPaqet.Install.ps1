# AutoPaqet Installation Functions
# Windows-specific dependency installation and binary download logic

# Configuration constants
$script:AutoPaqetRepoUrl = "https://raw.githubusercontent.com/omid3098/autopaqet/main"
$script:ReleaseBaseUrl = "https://github.com/omid3098/autopaqet/releases/download"
$script:ReleaseTag = "v1.0.0"

$script:NpcapConfig = @{
    "URL"  = "https://npcap.com/dist/npcap-1.80.exe"
    "File" = "npcap-setup.exe"
    "SilentArgs" = "/S /winpcap_mode=yes"
}

function Get-BinaryDownloadUrl {
    <#
    .SYNOPSIS
        Constructs the GitHub Release download URL for the paqet binary.
    .PARAMETER ReleaseTag
        The release tag (e.g., v1.0.0)
    .PARAMETER Platform
        The platform identifier (e.g., windows-amd64)
    .OUTPUTS
        The download URL string
    #>
    [CmdletBinding()]
    param(
        [string]$ReleaseTag = $script:ReleaseTag,
        [string]$Platform = "windows-amd64"
    )

    $extension = if ($Platform -like "windows*") { ".exe" } else { "" }
    return "$($script:ReleaseBaseUrl)/$ReleaseTag/paqet-${Platform}${extension}"
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

    # Check Npcap (only runtime dependency needed)
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
        Name of the dependency (Npcap)
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
        [ValidateSet("Npcap")]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$DownloadDir,

        [bool]$Silent = $false
    )

    if ($Name -eq "Npcap") {
        return Install-Npcap -DownloadDir $DownloadDir -Silent $Silent
    }

    return $false
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

function Get-PaqetBinary {
    <#
    .SYNOPSIS
        Downloads the pre-built paqet binary from GitHub Releases.
    .PARAMETER OutputPath
        Path to save the binary to
    .PARAMETER ReleaseTag
        The release tag to download (e.g., v1.0.0)
    .PARAMETER Force
        If true, re-download even if binary exists
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [string]$ReleaseTag = $script:ReleaseTag,

        [switch]$Force
    )

    if ((Test-Path $OutputPath) -and -not $Force) {
        return $true  # Binary already exists
    }

    $url = Get-BinaryDownloadUrl -ReleaseTag $ReleaseTag -Platform "windows-amd64"

    try {
        $parentDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        Invoke-WebRequest -Uri $url -OutFile $OutputPath -UseBasicParsing
        return (Test-Path $OutputPath)
    } catch {
        return $false
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
        'Get-BinaryDownloadUrl',
        'Get-MissingDependencies',
        'Install-Dependency',
        'Install-Npcap',
        'Install-AllDependencies',
        'Get-PaqetBinary',
        'New-DesktopShortcut',
        'New-StartMenuShortcut',
        'New-UninstallShortcut',
        'Set-ShortcutRunAsAdmin',
        'Invoke-UpdateAutoPaqet',
        'Test-AdminPrivileges',
        'Request-AdminElevation'
    )
}
