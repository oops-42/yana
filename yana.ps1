#!/usr/bin/env pwsh
#Requires -Version 5.1
# ---------------------------------------------------------------------------
# YANA - Yet Another Node Automator (PowerShell)
# ---------------------------------------------------------------------------

Set-Variable -Name YANA_TITLE -Value 'YANA - Yet Another Node Automator (PowerShell)' -Option Constant -Scope Script -ErrorAction:Ignore
Set-Variable -Name YANA_VERSION -Value 'YANAVERSIONPLACEHOLDER' -Option Constant -Scope Script -ErrorAction:Ignore

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

function Out-Help {
  # .SYNOPSIS
  # 	Outputs help information for the specified mode.
  #   If mode is not specified, displays general help information.
  param(
    # The mode for which to display help information (e.g., 'apply', 'verify', 'fetch').
    [string]$Mode
  )
  switch ($Mode) {
    'apply' {
      Write-Host @'
Usage: yana.ps1 apply <options>
  Applies the specified YANA Module.

Options:
  -source <path|url>         Specifies the source of YANA Module to apply.
'@
      break
    }
    'verify' {
      Write-Host @'
Usage: yana.ps1 verify <options>
  Compares the state of the system with the state specified by the YANA Module without making any changes.

Options:
  -source <path|url>         Specifies the source of YANA Module to verify.
'@
      break
    }
    'fetch' {
      Write-Host @'
Usage: yana.ps1 fetch <options>
  Fetches the specified YANA Module.

Options:
  -source <path|url>         Specifies the source of YANA Module to fetch.
'@
      break
    }
    default {
      Write-Host @'
Usage: yana.ps1 <general options> [mode] <mode options>

Modes:
  apply                      Applies the specified YANA Module.
  verify                     Compares the state of the system with the state specified by the YANA Module without making any changes.
  fetch                      Fetches the specified YANA Module.
'@
    }
  }
  Write-Host @'

General Options:
  -version                   Displays the version of YANA.
  -help                      Displays this help message.
  -help <mode>               Displays help for the specified mode.
  -logfile <path>            Log file path. Uses YANA_LOGFILE environment variable. If not specified, logs are not written to a file.
  -quiet                     Suppresses output messages. Uses YANA_QUIET environment variable if set.
  -nocolor                   Disables colored output. Uses YANA_NOCOLOR environment variable if set.
'@

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

function Invoke-Yana {
  # .SYNOPSIS
  # 	The main entry point for YANA.
  param(
    # If specified, outputs the version and exits.
    [switch]$Version,
    # If specified, outputs help information and exits.
    [switch]$Help,
    [Parameter(Position = 0)]
    [string]$Mode = $Env:YANA_MODE,
    [Parameter(Position = 1)]
    [string]$Source = $Env:YANA_SOURCE,
    # If specified, outputs log messages to the given file.
    # Uses YANA_LOGFILE environment variable if set.
    [string]$LogFile = $Env:YANA_LOGFILE,
    # If specified, suppresses output messages.
    # Uses YANA_QUIET environment variable if set.
    [switch]$Quiet = "$Env:YANA_QUIET" -notin ('0', 'false', ''),
    # If specified, disables colored output.
    # Uses YANA_NOCOLOR environment variable if set.
    [switch]$NoColor = "$Env:YANA_NOCOLOR" -notin ('0', 'false', '')
  )
  # Disable progress bar output
  $Script:ProgressPreference = 'SilentlyContinue'

  Out-ColoredStderr -Message $Script:YANA_TITLE -MessageDetail "Version: $Script:YANA_VERSION"

  if ($Help) { Out-Help -Mode $Mode; return }
  if ($Version) { Write-Output $Script:YANA_VERSION; return }
  switch ($Mode) {
    'apply' {
      Invoke-YanaApply -Source $Source
      break
    }
    'verify' {
      Invoke-YanaVerify -Source $Source
      break
    }
    'fetch' {
      Invoke-YanaFetch -Source $Source
      break
    }
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
    Invoke-Yana @args
  } catch {
    $_fc = [Console]::ForegroundColor
    [Console]::ForegroundColor = 'Red'
    [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
    [Console]::ForegroundColor = $_fc
    exit 1
  }
}
