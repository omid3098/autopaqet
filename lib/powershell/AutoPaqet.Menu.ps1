# AutoPaqet Menu System
# Terminal-based interactive menu for Windows client

function Show-Menu {
    <#
    .SYNOPSIS
        Displays a menu and returns the user's selection.
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of option strings
    .PARAMETER Footer
        Optional footer text
    .OUTPUTS
        Selected option number (0 for exit, -1 for invalid)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string[]]$Options,

        [string]$Footer = ""
    )

    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "         $Title" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host "  [$($i + 1)] $($Options[$i])" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "  [0] Exit" -ForegroundColor Yellow
    Write-Host ""

    if ($Footer) {
        Write-Host $Footer -ForegroundColor DarkGray
        Write-Host ""
    }

    $choice = Read-Host "Select option"

    # Validate input
    if ($choice -match '^\d+$') {
        $num = [int]$choice
        if ($num -ge 0 -and $num -le $Options.Length) {
            return $num
        }
    }

    return -1
}

function Show-SubMenu {
    <#
    .SYNOPSIS
        Displays a submenu (same as Show-Menu but with "Back" instead of "Exit").
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of option strings
    .OUTPUTS
        Selected option number (0 for back, -1 for invalid)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string[]]$Options
    )

    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "         $Title" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host "  [$($i + 1)] $($Options[$i])" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "  [0] Back" -ForegroundColor Yellow
    Write-Host ""

    $choice = Read-Host "Select option"

    if ($choice -match '^\d+$') {
        $num = [int]$choice
        if ($num -ge 0 -and $num -le $Options.Length) {
            return $num
        }
    }

    return -1
}

function Show-Confirmation {
    <#
    .SYNOPSIS
        Shows a Y/n confirmation prompt.
    .PARAMETER Message
        The confirmation message
    .PARAMETER DefaultYes
        If true, default is Yes; if false, default is No
    .OUTPUTS
        Boolean indicating user's choice
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [bool]$DefaultYes = $true
    )

    $prompt = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $response = Read-Host "$Message $prompt"

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }

    return ($response -eq 'y' -or $response -eq 'Y')
}

function Show-InputPrompt {
    <#
    .SYNOPSIS
        Shows an input prompt with optional default value.
    .PARAMETER Message
        The prompt message
    .PARAMETER Default
        Default value if user presses Enter
    .PARAMETER Required
        If true, empty input is not allowed
    .OUTPUTS
        User input or default value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Default = "",

        [bool]$Required = $false
    )

    $prompt = $Message
    if ($Default) {
        $prompt += " [Default: $Default]"
    }

    do {
        $input = Read-Host $prompt

        if ([string]::IsNullOrWhiteSpace($input)) {
            if ($Default) {
                return $Default
            }
            if ($Required) {
                Write-Host "This field is required." -ForegroundColor Yellow
            }
        } else {
            return $input
        }
    } while ($Required)

    return $input
}

function Show-Banner {
    <#
    .SYNOPSIS
        Displays the AutoPaqet banner.
    .PARAMETER Role
        Either "CLIENT" or "SERVER"
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("CLIENT", "SERVER")]
        [string]$Role = "CLIENT"
    )

    Write-Host @"
=============================================
        AUTOPAQET $Role (WINDOWS)
=============================================
"@ -ForegroundColor Cyan
}

function Show-MainMenu {
    <#
    .SYNOPSIS
        Shows the main menu and handles navigation.
    .PARAMETER Handlers
        Hashtable of handler functions for each option
    .DESCRIPTION
        The Handlers hashtable should contain:
        - FreshInstall: scriptblock
        - UpdateAutoPaqet: scriptblock
        - UpdatePaqet: scriptblock
        - Uninstall: scriptblock
        - ConfigurationMenu: scriptblock
        - DiagnosticsMenu: scriptblock
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Handlers
    )

    $options = @(
        "Fresh Install",
        "Update AutoPaqet (download latest installer)",
        "Update Paqet (git pull + rebuild binary)",
        "Uninstall",
        "Configuration",
        "Diagnostics"
    )

    while ($true) {
        $choice = Show-Menu -Title "AUTOPAQET CLIENT" -Options $options

        switch ($choice) {
            0 { return }  # Exit
            1 { if ($Handlers.FreshInstall) { & $Handlers.FreshInstall } }
            2 { if ($Handlers.UpdateAutoPaqet) { & $Handlers.UpdateAutoPaqet } }
            3 { if ($Handlers.UpdatePaqet) { & $Handlers.UpdatePaqet } }
            4 { if ($Handlers.Uninstall) { & $Handlers.Uninstall } }
            5 { if ($Handlers.ConfigurationMenu) { & $Handlers.ConfigurationMenu } }
            6 { if ($Handlers.DiagnosticsMenu) { & $Handlers.DiagnosticsMenu } }
            -1 {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Show-ConfigurationMenu {
    <#
    .SYNOPSIS
        Shows the configuration submenu.
    .PARAMETER Handlers
        Hashtable of handler functions
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Handlers
    )

    $options = @(
        "View Current Configuration",
        "Edit Server Address",
        "Edit Secret Key",
        "Re-detect Network"
    )

    while ($true) {
        $choice = Show-SubMenu -Title "CONFIGURATION" -Options $options

        switch ($choice) {
            0 { return }  # Back
            1 { if ($Handlers.ViewConfig) { & $Handlers.ViewConfig } }
            2 { if ($Handlers.EditServerAddress) { & $Handlers.EditServerAddress } }
            3 { if ($Handlers.EditSecretKey) { & $Handlers.EditSecretKey } }
            4 { if ($Handlers.RedetectNetwork) { & $Handlers.RedetectNetwork } }
            -1 {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Show-DiagnosticsMenu {
    <#
    .SYNOPSIS
        Shows the diagnostics submenu.
    .PARAMETER Handlers
        Hashtable of handler functions
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Handlers
    )

    $options = @(
        "Test Server Connection",
        "View Setup Log",
        "Network Info"
    )

    while ($true) {
        $choice = Show-SubMenu -Title "DIAGNOSTICS" -Options $options

        switch ($choice) {
            0 { return }  # Back
            1 { if ($Handlers.TestConnection) { & $Handlers.TestConnection } }
            2 { if ($Handlers.ViewLog) { & $Handlers.ViewLog } }
            3 { if ($Handlers.NetworkInfo) { & $Handlers.NetworkInfo } }
            -1 {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Wait-ForKeypress {
    <#
    .SYNOPSIS
        Waits for user to press Enter to continue.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Test-InteractiveMode {
    <#
    .SYNOPSIS
        Checks if the script is running interactively (not piped).
    .OUTPUTS
        Boolean indicating interactive mode
    #>
    [CmdletBinding()]
    param()

    return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
}

# Export functions (only when loaded as a module)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Show-Menu',
        'Show-SubMenu',
        'Show-Confirmation',
        'Show-InputPrompt',
        'Show-Banner',
        'Show-MainMenu',
        'Show-ConfigurationMenu',
        'Show-DiagnosticsMenu',
        'Wait-ForKeypress',
        'Test-InteractiveMode'
    )
}
