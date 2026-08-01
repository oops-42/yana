#!/usr/bin/env pwsh
#Requires -Version 5.1
# ---------------------------------------------------------------------------
# YANA - Yet Another Node Automator (PowerShell)
# ---------------------------------------------------------------------------

Set-Variable -Name YANA_TITLE -Value 'YANA - Yet Another Node Automator (PowerShell)' -Option Constant -Scope Script -ErrorAction:Ignore
Set-Variable -Name YANA_VERSION -Value 'YANAVERSIONPLACEHOLDER' -Option Constant -Scope Script -ErrorAction:Ignore

function log([string]$Level, [string]$Message) {
  if ($Level -eq 'trace' -and [bool]${-Trace} -eq $false) { return }
  if ($Level -eq 'debug' -and [bool]${-Debug} -eq $false -and [bool]${-Trace} -eq $false) { return }
  $logMessage = "[$([datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))]`t$($Level.ToUpper())`t$Message"
  try {
    if ($level -in @('trace', 'debug')) { [Console]::ForegroundColor = [ConsoleColor]::DarkGray }
    elseif ($level -eq 'info') { [Console]::ForegroundColor = [ConsoleColor]::Cyan }
    elseif ($level -in @('ok', 'success', 'pass')) { [Console]::ForegroundColor = [ConsoleColor]::DarkGreen }
    elseif ($level -in @('skip')) { [Console]::ForegroundColor = [ConsoleColor]::Yellow }
    elseif ($level -in @('warn', 'warning')) { [Console]::ForegroundColor = [ConsoleColor]::DarkYellow }
    elseif ($level -in @('fail', 'failure', 'error')) { [Console]::ForegroundColor = [ConsoleColor]::Red }
    elseif ($level -eq 'fatal') { [Console]::ForegroundColor = [ConsoleColor]:: DarkRed }
    [Console]::Error.WriteLine($logMessage)
  } finally { [Console]::ResetColor() }
  if ($LogFile) {
    try {
      Add-Content -Path $LogFile -Value $logMessage -Force -ErrorAction Stop
    } catch {
      $LogFile = $null
      throw "Failed to write to log file '$LogFile': $($_.Exception.Message)"
    }
  }
}

function Out-Colored {
  # .SYNOPSIS
  # 	Outputs colored text to the output stream.
  # 	Takes care of logging to a file if $LogFile is specified.
  # 	If $Quiet is specified, suppresses output.
  # 	If $NoColor is specified, disables colored output.
  param(
    # The color of the text (e.g., 'Red', 'Green', 'Blue').
    [string]$Color,
    # The main message to display.
    [string]$Message,
    # Additional details to display (optional). Will be displayed in dimmed color.
    [string]$MessageDetail = ''
  )
  if ($Message.Length -gt 0) { $Message = "$Message " }
  if ($LogFile) {
    $logMessage = "[$([datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))] ${Message}${MessageDetail}"
    try {
      Add-Content -Path $LogFile -Value $logMessage -Force -ErrorAction Stop
    } catch {
      Write-Warning "Failed to write to log file '$($LogFile)': $($_.Exception.Message)"
    }
  }
  if ($Quiet) { return }
  if ($NoColor) {
    $message = "${Message}$MessageDetail"
  } else {
    $colorCode = switch ($Color) {
      'Black' { 30 }
      'Red' { 31 }
      'Green' { 32 }
      'Yellow' { 33 }
      'Blue' { 34 }
      'Magenta' { 35 }
      'Cyan' { 36 }
      'White' { 37 }
      default { 0 } # Default to no color
    }
    $ansiEscape = [char]27
    "${ansiEscape}[${colorCode}m${Message}${ansiEscape}[2m${MessageDetail}${ansiEscape}[0m"
  }
}
function Out-ColoredStdout {
  # .SYNOPSIS
  # 	Outputs colored text to the standard output.
  if ($local:output = Out-Colored @args) { [Console]::Out.WriteLine($local:output)	}
}
function Out-ColoredStderr {
  # .SYNOPSIS
  # 	Outputs colored text to the standard error.
  if ($local:output = Out-Colored @args) { [Console]::Error.WriteLine($local:output)	}
}

function _yana_usage {
  # .SYNOPSIS
  # 	Outputs help information for the specified mode.
  #   If mode is not specified, displays general help information.
  param(
    # The mode for which to display help information (e.g., 'apply', 'verify', 'fetch').
    [string]$Mode
  )
  switch ($Mode) {
    'apply' {
      Write-Host 'Usage: yana.ps1 apply -source <path|url> [-routine <name>]'
      Write-Host '  Applies the specified YANA Module.'
      Write-Host 'Options:'
      Write-Host '  -source <path|url>         Specifies the source of YANA Module to apply. Can be a local path or a URL. Uses YANA_SOURCE environment variable.'
      Write-Host '  -routine <name>            Specifies the routine to execute within the YANA Module. Uses YANA_ROUTINE environment variable.'
      break
    }
    'verify' {
      Write-Host 'Usage: yana.ps1 verify -source <path|url> [-routine <name>]'
      Write-Host '  Compares the state of the system with the state specified by the YANA Module without making any changes.'
      Write-Host 'Options:'
      Write-Host '  -source <path|url>         Specifies the source of YANA Module to verify. Can be a local path or a URL. Uses YANA_SOURCE environment variable.'
      Write-Host '  -routine <name>            Specifies the routine to execute within the YANA Module. Uses YANA_ROUTINE environment variable.'
      break
    }
    'fetch' {
      Write-Host 'Usage: yana.ps1 fetch -source <path|url>'
      Write-Host '  Fetches the specified YANA Module from the given source (path or URL).'
      Write-Host 'Options:'
      Write-Host '  -source <path|url>         Specifies the source of YANA Module to fetch. Can be path or URL. Uses YANA_SOURCE environment variable.'
    }
    'version' {
      Write-Host 'Usage: yana.ps1 version'
      Write-Host '  Displays the version of YANA.'
    }
    default {
      Write-Host 'Usage: yana.ps1 <general options> [mode] <mode options>'
      Write-Host 'Modes:'
      Write-Host '  version                    Displays the version of YANA.'
      Write-Host '  apply                      Applies the specified YANA Module.'
      Write-Host '  verify                     Compares the state of the system with the state specified by the YANA Module without making any changes.'
      Write-Host '  fetch                      Fetches the specified YANA Module.'
    }
  }
  Write-Host 'General Options:'
  Write-Host '  -help                      Displays this help message.'
  Write-Host '  -help <mode>               Displays help for the specified mode.'
  Write-Host '  -logfile <file>            Log file path. Uses YANA_LOGFILE environment variable. If not specified, logs are not written to a file.'

}

function Invoke-YanaApply {
  # .SYNOPSIS
  # 	Applies the specified YANA Module.
  param(
    # The source of the YANA Module to apply (e.g., a file path or URL).
    [string]$Source
  )
  if ([string]::IsNullOrEmpty($Source)) { throw 'Source is required for ''apply'' mode.' }
  Out-ColoredStderr -Color 'Magenta' -Message "Applying YANA Module from source: $Source"
  # Placeholder for actual implementation of applying the YANA module
}

function Invoke-YanaVerify {
  # .SYNOPSIS
  # 	Verifies the state of the system against the specified YANA Module.
  param(
    # The source of the YANA Module to verify (e.g., a file path or URL).
    [string]$Source
  )
  if ([string]::IsNullOrEmpty($Source)) { throw 'Source is required for ''verify'' mode.' }
  Out-ColoredStderr -Color 'Magenta' -Message "Verifying YANA Module from source: $Source"
  # Placeholder for actual implementation of verifying the YANA module
}

function Invoke-YanaFetch {
  # .SYNOPSIS
  # 	Fetches the specified YANA Module.
  param(
    # The source of the YANA Module to fetch (e.g., a file path or URL).
    [string]$Source
  )
  if ([string]::IsNullOrEmpty($Source)) { throw 'Source is required for ''fetch'' mode.' }
  Out-ColoredStderr -Color 'Magenta' -Message "Fetching YANA Module from source: $Source"
  # Placeholder for actual implementation of fetching the YANA module
}

function _yana_ {
  # .SYNOPSIS
  # 	The main entry point for YANA.
  param(
    # If specified, outputs help information and exits.
    [switch]$Help,
    [Parameter(Position = 0)]
    [ValidateSet('apply', 'verify', 'fetch', 'version')]
    [string]$Mode = $Env:YANA_MODE,
    # If specified, the source of the YANA Module to apply/verify/fetch.
    [Parameter(Position = 1)]
    [string]$Source = $Env:YANA_SOURCE,
    # If specified, the routine of the YANA Module to apply/verify/fetch.
    [Parameter(Position = 2)]
    [string]$Routine = $Env:YANA_ROUTINE,
    # If specified, outputs log messages to the given file.
    # Uses YANA_LOGFILE environment variable if set.
    [string]$LogFile = $Env:YANA_LOGFILE,
    # If specified, enables debug level logging.
    [switch]${-Debug} = $Env:YANA_DEBUG -eq 'true',
    # If specified, enables trace level logging.
    [switch]${-Trace} = $Env:YANA_TRACE -eq 'true'
  )
  # Disable progress bar output
  $Script:ProgressPreference = 'SilentlyContinue'
  log info "$Script:YANA_TITLE Version: $Script:YANA_VERSION"
  $Script:YANA_TRACE = [bool]${-Trace}
  $Script:YANA_DEBUG = [bool]${-Debug} -or $Script:YANA_TRACE

  if ($Help) { _yana_usage -Mode $Mode; return }
  switch ($Mode) {
    'apply' { Invoke-YanaApply -Source $Source }
    'verify' { Invoke-YanaVerify -Source $Source }
    'fetch' { Invoke-YanaFetch -Source $Source }
    'version' { $Script:YANA_VERSION }
    '' {
      throw 'No mode specified. Use -help to see available modes.'
    }
    default {
      throw "Unknown mode: $Mode. Use -help to see available modes."
    }
  }
}

# Prevent running when dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
  try {
    _yana_ @args
  } catch {
    log fatal "An unexpected error occurred at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    $_.ScriptStackTrace | ForEach-Object { log trace $_ }
    exit 1
  }
}
