# AutoPaqet Validation Functions
# Reusable input validation logic

function Test-ServerAddress {
    <#
    .SYNOPSIS
        Validates a server address in IP:PORT format.
    .PARAMETER Address
        The address to validate (e.g., "192.168.1.1:9999")
    .OUTPUTS
        Boolean indicating if the address is valid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address
    )

    # Check basic format: IP:PORT
    if ($Address -notmatch '^(\d{1,3}\.){3}\d{1,3}:\d{1,5}$') {
        return $false
    }

    $parts = $Address -split ':'
    $ip = $parts[0]
    $port = [int]$parts[1]

    # Validate IP octets (0-255)
    $octets = $ip -split '\.'
    foreach ($octet in $octets) {
        $octetInt = [int]$octet
        if ($octetInt -lt 0 -or $octetInt -gt 255) {
            return $false
        }
    }

    # Validate port range (1-65535)
    if ($port -lt 1 -or $port -gt 65535) {
        return $false
    }

    # Warn if using localhost/0.0.0.0 (but still valid)
    if ($ip -eq "127.0.0.1" -or $ip -eq "0.0.0.0") {
        Write-Warning "Using localhost or 0.0.0.0 as server address is usually incorrect for remote connections."
    }

    return $true
}

function Test-SecretKey {
    <#
    .SYNOPSIS
        Validates a secret key.
    .PARAMETER Key
        The key to validate
    .PARAMETER MinLength
        Minimum acceptable key length (default: 1)
    .OUTPUTS
        Boolean indicating if the key is valid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Key,

        [int]$MinLength = 1
    )

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return $false
    }

    if ($Key.Length -lt $MinLength) {
        return $false
    }

    # Warn if key is very short (but still valid if >= MinLength)
    if ($Key.Length -lt 8) {
        Write-Warning "Secret key is very short. Consider using a longer key for better security."
    }

    return $true
}

function Test-PortNumber {
    <#
    .SYNOPSIS
        Validates a port number.
    .PARAMETER Port
        The port number to validate
    .OUTPUTS
        Boolean indicating if the port is valid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    return ($Port -ge 1 -and $Port -le 65535)
}

function Test-IPAddress {
    <#
    .SYNOPSIS
        Validates an IPv4 address.
    .PARAMETER IP
        The IP address to validate
    .OUTPUTS
        Boolean indicating if the IP is valid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IP
    )

    if ($IP -notmatch '^(\d{1,3}\.){3}\d{1,3}$') {
        return $false
    }

    $octets = $IP -split '\.'
    foreach ($octet in $octets) {
        $octetInt = [int]$octet
        if ($octetInt -lt 0 -or $octetInt -gt 255) {
            return $false
        }
    }

    return $true
}

function Test-MACAddress {
    <#
    .SYNOPSIS
        Validates a MAC address.
    .PARAMETER MAC
        The MAC address to validate (supports : or - separators)
    .OUTPUTS
        Boolean indicating if the MAC is valid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MAC
    )

    # Support both colon and hyphen separators
    $pattern = '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$'
    return $MAC -match $pattern
}

# Export functions for module use (only when loaded as a module)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Test-ServerAddress',
        'Test-SecretKey',
        'Test-PortNumber',
        'Test-IPAddress',
        'Test-MACAddress'
    )
}
