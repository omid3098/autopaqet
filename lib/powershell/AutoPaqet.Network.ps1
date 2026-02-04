# AutoPaqet Network Detection Functions
# Windows-specific network auto-detection using Npcap/WinPcap

function Get-DefaultNetworkInterface {
    <#
    .SYNOPSIS
        Gets the default network interface based on the default route.
    .OUTPUTS
        Hashtable with interface details or $null if detection fails
    #>
    [CmdletBinding()]
    param()

    # Find the interface with the default route (lowest metric)
    $defaultRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Sort-Object RouteMetric | Select-Object -First 1

    if (-not $defaultRoute) {
        return $null
    }

    $ifIndex = $defaultRoute.InterfaceIndex
    $adapter = Get-NetAdapter -InterfaceIndex $ifIndex -ErrorAction SilentlyContinue
    $ipInfo = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

    if (-not $adapter -or -not $ipInfo) {
        return $null
    }

    return @{
        Name        = $adapter.Name
        Index       = $ifIndex
        GUID        = $adapter.InterfaceGuid
        Status      = $adapter.Status
        LocalIP     = $ipInfo.IPAddress
        GatewayIP   = $defaultRoute.NextHop
        RouteMetric = $defaultRoute.RouteMetric
    }
}

function Get-GatewayMACAddress {
    <#
    .SYNOPSIS
        Gets the MAC address of the gateway by pinging and checking ARP.
    .PARAMETER GatewayIP
        The IP address of the gateway
    .OUTPUTS
        MAC address string or $null if detection fails
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GatewayIP
    )

    if ($GatewayIP -eq "0.0.0.0") {
        return $null
    }

    # Ping gateway to ensure ARP entry exists
    Test-Connection -ComputerName $GatewayIP -Count 1 -Quiet -ErrorAction SilentlyContinue | Out-Null

    # Get MAC from ARP cache
    $arp = Get-NetNeighbor -IPAddress $GatewayIP -AddressFamily IPv4 -ErrorAction SilentlyContinue

    if ($arp -and $arp.LinkLayerAddress) {
        return $arp.LinkLayerAddress
    }

    return $null
}

function Get-NpcapGUID {
    <#
    .SYNOPSIS
        Formats a Windows GUID for Npcap device path.
    .PARAMETER GUID
        The Windows interface GUID
    .OUTPUTS
        Npcap-formatted device path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GUID
    )

    return "\Device\NPF_$GUID"
}

function Get-NetworkConfiguration {
    <#
    .SYNOPSIS
        Detects complete network configuration for AutoPaqet.
    .OUTPUTS
        Hashtable with all network configuration or throws on failure
    #>
    [CmdletBinding()]
    param()

    $interface = Get-DefaultNetworkInterface
    if (-not $interface) {
        throw "No active internet connection detected (Default Route missing)."
    }

    $gatewayMAC = Get-GatewayMACAddress -GatewayIP $interface.GatewayIP
    if (-not $gatewayMAC) {
        throw "Could not detect Gateway MAC address."
    }

    $npcapGuid = Get-NpcapGUID -GUID $interface.GUID

    return @{
        InterfaceName = $interface.Name
        InterfaceGUID = $interface.GUID
        LocalIP       = $interface.LocalIP
        GatewayIP     = $interface.GatewayIP
        GatewayMAC    = $gatewayMAC
        NpcapGUID     = $npcapGuid
    }
}

function Test-NpcapInstalled {
    <#
    .SYNOPSIS
        Checks if Npcap is installed.
    .OUTPUTS
        Boolean indicating if Npcap is installed
    #>
    [CmdletBinding()]
    param()

    $npcapPath32 = "$env:SystemRoot\System32\Npcap\wpcap.dll"
    $npcapPath64 = "$env:SystemRoot\SysWOW64\Npcap\wpcap.dll"

    return (Test-Path $npcapPath32) -or (Test-Path $npcapPath64)
}

function Format-NetworkInfo {
    <#
    .SYNOPSIS
        Formats network configuration for display.
    .PARAMETER Config
        Network configuration hashtable from Get-NetworkConfiguration
    .OUTPUTS
        Formatted string for display
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    $output = @"
Interface:   $($Config.InterfaceName)
Local IP:    $($Config.LocalIP)
Gateway IP:  $($Config.GatewayIP)
Gateway MAC: $($Config.GatewayMAC)
Npcap GUID:  $($Config.NpcapGUID)
"@
    return $output
}

# Export functions (only when loaded as a module)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Get-DefaultNetworkInterface',
        'Get-GatewayMACAddress',
        'Get-NpcapGUID',
        'Get-NetworkConfiguration',
        'Test-NpcapInstalled',
        'Format-NetworkInfo'
    )
}
