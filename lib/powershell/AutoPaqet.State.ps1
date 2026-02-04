# AutoPaqet State Detection Functions
# Installation state detection and validation logic

function Get-InstallationState {
    <#
    .SYNOPSIS
        Detects the current installation state of AutoPaqet.
    .PARAMETER BinaryPath
        Path to the paqet.exe binary
    .PARAMETER ConfigPath
        Path to the client.yaml configuration file
    .OUTPUTS
        Hashtable with installation state information:
        - BinaryExists: [bool] paqet.exe found
        - ConfigExists: [bool] client.yaml found
        - ConfigValid: [bool] config has required fields
        - IsFullyInstalled: [bool] binary + valid config
        - State: [string] "NotInstalled", "PartialInstall", "Configured", "Ready"
        - Issues: [string[]] List of problems found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BinaryPath,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $state = @{
        BinaryExists      = $false
        ConfigExists      = $false
        ConfigValid       = $false
        IsFullyInstalled  = $false
        State             = "NotInstalled"
        Issues            = @()
    }

    # Check binary
    $state.BinaryExists = Test-Path $BinaryPath
    if (-not $state.BinaryExists) {
        $state.Issues += "Binary not found: $BinaryPath"
    }

    # Check config file
    $state.ConfigExists = Test-Path $ConfigPath
    if (-not $state.ConfigExists) {
        $state.Issues += "Configuration not found: $ConfigPath"
    } else {
        # Validate config content
        $validation = Test-ConfigurationValid -ConfigPath $ConfigPath
        $state.ConfigValid = $validation.IsValid
        $state.Issues += $validation.Issues
    }

    # Determine overall state
    if ($state.BinaryExists -and $state.ConfigValid) {
        $state.State = "Ready"
        $state.IsFullyInstalled = $true
    } elseif ($state.BinaryExists -and $state.ConfigExists) {
        $state.State = "Configured"  # Has config but may be invalid
    } elseif ($state.BinaryExists -or $state.ConfigExists) {
        $state.State = "PartialInstall"
    } else {
        $state.State = "NotInstalled"
    }

    return $state
}

function Test-ConfigurationValid {
    <#
    .SYNOPSIS
        Validates that a configuration file has all required fields.
    .PARAMETER ConfigPath
        Path to the configuration file
    .OUTPUTS
        Hashtable with:
        - IsValid: [bool] all required fields present
        - Issues: [string[]] list of missing/invalid fields
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $result = @{
        IsValid = $false
        Issues  = @()
    }

    if (-not (Test-Path $ConfigPath)) {
        $result.Issues += "Configuration file does not exist"
        return $result
    }

    try {
        $configContent = Get-Content $ConfigPath -Raw -ErrorAction Stop

        # Check for server address
        $hasServer = $configContent -match 'server:\s*\n\s*addr:\s*"[^"]+"'
        if (-not $hasServer) {
            $result.Issues += "Missing server address"
        }

        # Check for secret key
        $hasKey = $configContent -match 'key:\s*"[^"]+"'
        if (-not $hasKey) {
            $result.Issues += "Missing secret key"
        }

        # Check for network interface
        $hasInterface = $configContent -match 'interface:\s*"[^"]+"'
        if (-not $hasInterface) {
            $result.Issues += "Missing network interface"
        }

        $result.IsValid = $hasServer -and $hasKey -and $hasInterface
    } catch {
        $result.Issues += "Failed to read configuration: $_"
    }

    return $result
}

function Get-InstallationStateMessage {
    <#
    .SYNOPSIS
        Returns a user-friendly message for the installation state.
    .PARAMETER State
        The state string from Get-InstallationState
    .OUTPUTS
        String with status message
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("NotInstalled", "PartialInstall", "Configured", "Ready")]
        [string]$State
    )

    switch ($State) {
        "Ready"          { return "Ready to run" }
        "Configured"     { return "Configured (validation issues)" }
        "PartialInstall" { return "Partial installation" }
        "NotInstalled"   { return "Not installed" }
    }
}

# Export functions for module use (only when loaded as a module)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Get-InstallationState',
        'Test-ConfigurationValid',
        'Get-InstallationStateMessage'
    )
}
