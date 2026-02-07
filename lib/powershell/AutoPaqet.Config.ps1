# AutoPaqet Configuration Management
# YAML configuration file handling

function New-ClientConfiguration {
    <#
    .SYNOPSIS
        Creates a new client configuration YAML content.
    .PARAMETER NetworkConfig
        Network configuration hashtable
    .PARAMETER ServerAddress
        Server address (IP:PORT)
    .PARAMETER SecretKey
        KCP secret key
    .PARAMETER LocalPort
        Local port for the client (0 for random)
    .PARAMETER Socks5Listen
        SOCKS5 listen address (default: 127.0.0.1:1080)
    .OUTPUTS
        YAML configuration string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$NetworkConfig,

        [Parameter(Mandatory = $true)]
        [string]$ServerAddress,

        [Parameter(Mandatory = $true)]
        [string]$SecretKey,

        [int]$LocalPort = 0,

        [string]$Socks5Listen = "127.0.0.1:1080",

        [string]$LocalFlag = "PA",

        [string]$RemoteFlag = "PA",

        [string]$KcpMode = "fast",

        [int]$Conn = 1
    )

    # Validate TCP flag values
    $validFlags = @("S", "PA", "A")
    if ($LocalFlag -notin $validFlags) {
        throw "Invalid LocalFlag '$LocalFlag'. Must be one of: $($validFlags -join ', ')"
    }
    if ($RemoteFlag -notin $validFlags) {
        throw "Invalid RemoteFlag '$RemoteFlag'. Must be one of: $($validFlags -join ', ')"
    }

    # Validate KCP mode
    $validModes = @("normal", "fast", "fast2", "fast3", "manual")
    if ($KcpMode -notin $validModes) {
        throw "Invalid KcpMode '$KcpMode'. Must be one of: $($validModes -join ', ')"
    }

    # Use random port if not specified
    if ($LocalPort -eq 0) {
        $LocalPort = Get-Random -Minimum 10000 -Maximum 65000
    }

    $localAddr = "$($NetworkConfig.LocalIP):$LocalPort"

    $configContent = @"
role: "client"

log:
  level: "info"

socks5:
  - listen: "$Socks5Listen"

network:
  interface: "$($NetworkConfig.InterfaceName)"
  guid: '$($NetworkConfig.NpcapGUID)'
  ipv4:
    addr: "$localAddr"
    router_mac: "$($NetworkConfig.GatewayMAC)"
  tcp:
    local_flag: ["$LocalFlag"]
    remote_flag: ["$RemoteFlag"]

server:
  addr: "$ServerAddress"

transport:
  protocol: "kcp"
  conn: $Conn
  kcp:
    mode: "$KcpMode"
    key: "$SecretKey"
    block: "aes"
"@

    return $configContent
}

function Save-Configuration {
    <#
    .SYNOPSIS
        Saves configuration content to a file.
    .PARAMETER Path
        File path to save to
    .PARAMETER Content
        Configuration content string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    Set-Content -Path $Path -Value $Content -Encoding Ascii
}

function Get-ConfigurationValue {
    <#
    .SYNOPSIS
        Gets a specific value from a YAML configuration file.
    .PARAMETER Path
        Path to the configuration file
    .PARAMETER Key
        The key to search for (supports nested keys like "server.addr")
    .OUTPUTS
        The value or $null if not found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $content = Get-Content $Path -Raw

    # Simple regex-based extraction (handles basic cases)
    switch -Regex ($Key) {
        '^server\.addr$' {
            if ($content -match 'server:\s*\n\s*addr:\s*"([^"]+)"') {
                return $Matches[1]
            }
        }
        '^transport\.kcp\.key$' {
            if ($content -match 'key:\s*"([^"]+)"') {
                return $Matches[1]
            }
        }
        '^socks5\[0\]\.listen$' {
            if ($content -match 'socks5:\s*\n\s*-\s*listen:\s*"([^"]+)"') {
                return $Matches[1]
            }
        }
        '^network\.interface$' {
            if ($content -match 'interface:\s*"([^"]+)"') {
                return $Matches[1]
            }
        }
        '^network\.ipv4\.router_mac$' {
            if ($content -match 'router_mac:\s*"([^"]+)"') {
                return $Matches[1]
            }
        }
        default {
            # Generic single-line key: "value" pattern
            $escapedKey = [regex]::Escape($Key)
            if ($content -match "$escapedKey`:\s*`"([^`"]+)`"") {
                return $Matches[1]
            }
        }
    }

    return $null
}

function Set-ConfigurationValue {
    <#
    .SYNOPSIS
        Updates a specific value in a YAML configuration file.
    .PARAMETER Path
        Path to the configuration file
    .PARAMETER Key
        The key to update
    .PARAMETER Value
        The new value
    .OUTPUTS
        Boolean indicating success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    $content = Get-Content $Path -Raw

    # Regex-based replacement (preserves formatting)
    switch -Regex ($Key) {
        '^server\.addr$' {
            $content = $content -replace '(server:\s*\n\s*addr:\s*)"[^"]+"', "`$1`"$Value`""
        }
        '^transport\.kcp\.key$' {
            $content = $content -replace '(key:\s*)"[^"]+"', "`$1`"$Value`""
        }
        default {
            # Generic single-line replacement
            $escapedKey = [regex]::Escape($Key)
            $content = $content -replace "($escapedKey`:\s*)`"[^`"]+`"", "`$1`"$Value`""
        }
    }

    Set-Content -Path $Path -Value $content -Encoding Ascii -NoNewline
    return $true
}

function Test-ConfigurationExists {
    <#
    .SYNOPSIS
        Checks if a configuration file exists.
    .PARAMETER Path
        Path to the configuration file
    .OUTPUTS
        Boolean
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return Test-Path $Path
}

function Get-ConfigurationSummary {
    <#
    .SYNOPSIS
        Gets a summary of the current configuration.
    .PARAMETER Path
        Path to the configuration file
    .OUTPUTS
        Hashtable with key configuration values
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    return @{
        ServerAddress  = Get-ConfigurationValue -Path $Path -Key "server.addr"
        Socks5Listen   = Get-ConfigurationValue -Path $Path -Key "socks5[0].listen"
        Interface      = Get-ConfigurationValue -Path $Path -Key "network.interface"
        RouterMAC      = Get-ConfigurationValue -Path $Path -Key "network.ipv4.router_mac"
        HasKey         = $null -ne (Get-ConfigurationValue -Path $Path -Key "transport.kcp.key")
    }
}

# Export functions (only when loaded as a module)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'New-ClientConfiguration',
        'Save-Configuration',
        'Get-ConfigurationValue',
        'Set-ConfigurationValue',
        'Test-ConfigurationExists',
        'Get-ConfigurationSummary'
    )
}
