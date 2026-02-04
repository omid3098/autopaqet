# AutoPaqet Logging Functions
# Centralized logging infrastructure

# Script-level variables (set via Initialize-Logging)
$script:LogFile = $null
$script:TranscriptPath = $null
$script:LoggingInitialized = $false

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initializes the logging system.
    .PARAMETER LogDirectory
        Directory where log files will be stored
    .PARAMETER LogFileName
        Name of the main log file (default: setup.log)
    .PARAMETER EnableTranscript
        Whether to enable PowerShell transcript logging
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogDirectory,

        [string]$LogFileName = "setup.log",

        [switch]$EnableTranscript
    )

    # Create log directory if needed
    if (-not (Test-Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $script:LogFile = Join-Path $LogDirectory $LogFileName

    # Clear log file for new session
    Set-Content -Path $script:LogFile -Value "" -Encoding UTF8

    # Start transcript if requested
    if ($EnableTranscript) {
        $script:TranscriptPath = Join-Path $LogDirectory "setup-transcript.log"
        Start-Transcript -Path $script:TranscriptPath -Force | Out-Null
    }

    $script:LoggingInitialized = $true

    # Log header
    Write-Log "========== AUTOPAQET LOG ==========" -Level "INFO"
    Write-Log "Session started" -Level "INFO"
    Write-Log "Log file: $($script:LogFile)" -Level "DEBUG"
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to the log file.
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (INFO, SUCCESS, WARN, ERROR, DEBUG, COMMAND)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG", "COMMAND")]
        [string]$Level = "INFO"
    )

    if (-not $script:LoggingInitialized -or -not $script:LogFile) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $logLine -Encoding UTF8
}

function Write-Info {
    <#
    .SYNOPSIS
        Writes an info message to console and log.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[INFO] $Message" -ForegroundColor Cyan
    Write-Log $Message -Level "INFO"
}

function Write-Success {
    <#
    .SYNOPSIS
        Writes a success message to console and log.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green
    Write-Log $Message -Level "SUCCESS"
}

function Write-Warn {
    <#
    .SYNOPSIS
        Writes a warning message to console and log.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[WARN] $Message" -ForegroundColor Yellow
    Write-Log $Message -Level "WARN"
}

function Write-ErrorAndExit {
    <#
    .SYNOPSIS
        Writes an error message and exits.
    .PARAMETER Message
        The error message
    .PARAMETER ExitCode
        Exit code (default: 1)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [int]$ExitCode = 1
    )

    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Write-Log $Message -Level "ERROR"
    Write-Log "Setup failed. See log for details." -Level "ERROR"

    if ($script:TranscriptPath) {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Host ""
    Write-Host "If setup failed, please send this file:" -ForegroundColor Yellow
    if ($script:LogFile) {
        Write-Host "  $($script:LogFile)" -ForegroundColor White
    }

    exit $ExitCode
}

function Stop-Logging {
    <#
    .SYNOPSIS
        Stops the logging system and transcript.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Session ended" -Level "INFO"

    if ($script:TranscriptPath) {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    }

    $script:LoggingInitialized = $false
}

function Get-LogFilePath {
    <#
    .SYNOPSIS
        Returns the current log file path.
    #>
    [CmdletBinding()]
    param()

    return $script:LogFile
}

function Invoke-LoggedCommand {
    <#
    .SYNOPSIS
        Executes a command and logs the output.
    .PARAMETER Command
        The command to execute
    .PARAMETER Description
        Description of what the command does
    .OUTPUTS
        The stdout of the command
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string]$Description = ""
    )

    Write-Log "Executing: $Command" -Level "COMMAND"
    if ($Description) {
        Write-Log "Description: $Description" -Level "DEBUG"
    }

    $tempOut = [System.IO.Path]::GetTempFileName()
    $tempErr = [System.IO.Path]::GetTempFileName()

    try {
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $Command > `"$tempOut`" 2> `"$tempErr`"" -Wait -NoNewWindow -PassThru
        $stdout = Get-Content $tempOut -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content $tempErr -Raw -ErrorAction SilentlyContinue

        if ($stdout) { Write-Log "Stdout: $stdout" -Level "DEBUG" }
        if ($stderr) { Write-Log "Stderr: $stderr" -Level "DEBUG" }
        Write-Log "Exit code: $($process.ExitCode)" -Level "DEBUG"

        $global:LASTEXITCODE = $process.ExitCode
        return $stdout
    } finally {
        Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
        Remove-Item $tempErr -Force -ErrorAction SilentlyContinue
    }
}

# Export functions (only when loaded as a module)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Initialize-Logging',
        'Write-Log',
        'Write-Info',
        'Write-Success',
        'Write-Warn',
        'Write-ErrorAndExit',
        'Stop-Logging',
        'Get-LogFilePath',
        'Invoke-LoggedCommand'
    )
}
