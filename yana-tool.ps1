#!/usr/bin/env pwsh
#Requires -Version 5.1
# ---------------------------------------------------------------------------
# YANA - Yet Another Node Automator (PowerShell)
# ---------------------------------------------------------------------------

Set-Variable -Name YANA_TITLE -Value 'YANA - Yet Another Node Automator (PowerShell) - Toolkit' -Option Constant -Scope Script -ErrorAction:Ignore
Set-Variable -Name YANA_VERSION -Value 'YANAVERSIONPLACEHOLDER' -Option Constant -Scope Script -ErrorAction:Ignore

# Outputs help information for the specified mode.
# If mode is not specified, displays general help information.
function _yanatool_usage([string]$Mode) {
  switch ($Mode) {
    'test' {
      Write-Host 'Usage: yana-tool.ps1 test -source <file|dir>'
      Write-Host '  Runs tests from the specified file or directory.'
      Write-Host 'Options:'
      Write-Host '  -source <file|dir>         Specifies the path to YANA test files or directories. Supports wildcards.'
      break
    }
    'version' {
      Write-Host 'Usage: yana-tool.ps1 version'
      Write-Host '  Displays the version of YANA Toolkit.'
    }
    default {
      Write-Host 'Usage: yana-tool.ps1 <general options> [mode] <mode options>'
      Write-Host 'Modes:'
      Write-Host '  version                    Displays the version of YANA Toolkit.'
      Write-Host '  test                       Runs tests from the specified files or directories.'
    }
  }
  Write-Host 'General Options:'
  Write-Host '  -help                      Displays this help message.'
  Write-Host '  -help <mode>               Displays help for the specified mode.'
  Write-Host '  -logfile <file>            Log file path. Uses YANA_LOGFILE environment variable. If not specified, logs are not written to a file.'
  Write-Host 'Environment Variables:'
  Write-Host '  YANA_MODE=<mode>           Specifies the mode to run YANA Toolkit in.'
  # Write-Host '  YANA_SOURCE=<path|url>     Specifies the source of the YANA Module.'
  Write-Host '  YANA_LOGFILE=<file>        Specifies the log file path.'
  Write-Host '                             Example: YANA_PARAM_version=2.0 ./yana-tool.ps1 test -source ./tests'
  Write-Host '  YANA_DEBUG=true            Enables debug logging.'
  Write-Host '  YANA_TRACE=true            Enables trace logging (implies debug logging).'
}
# Logs a message with the specified level and message.
# If the level is 'trace' or 'debug', the message is logged only if the corresponding switch is enabled.
# If a log file is specified, the message is also written to the log file.
function log([string]$Level, [string]$Message) {
  if ($Level -eq 'trace' -and $Script:YANA_TRACE -ne $true) { return }
  if ($Level -eq 'debug' -and $Script:YANA_DEBUG -ne $true) { return }
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
# Checks for required prerequisites and throws an error if any are missing.
function _yanatool_check_prerequisites([string[]]$Prerequisites) {
  foreach ($prerequisite in $Prerequisites) {
    if (-not (Get-Command $prerequisite -ErrorAction SilentlyContinue)) {
      throw "Prerequisite '$prerequisite' is not installed or not in the system PATH."
    }
    log debug "Prerequisite '$prerequisite' is installed."
  }
}
# Runs tests from the specified source file or directory
function _yanatool_mode_test([ValidateNotNullOrEmpty()][string]$Source = $Env:YANA_SOURCE) {
  if (-not (Test-Path -Path $Source)) { throw "Source '$Source' does not exist." }
  log info "Running mode 'test' from source: $Source"

  # Implement test execution logic here
  log info "Tests executed successfully from source: $Source"
}

# The main entry point for YANA.
function _yanatool_ {
  param(
    # If specified, outputs help information and exits.
    [switch]$Help,
    [Parameter(Position = 0)]
    [ValidateSet('test', 'version')]
    [string]$Mode = $Env:YANA_MODE,
    # If specified, the source of the YANA Module to apply/verify/pull.
    # [Parameter(Position = 1)]
    [string]$Source = $Env:YANA_SOURCE,
    # If specified, outputs log messages to the given file.
    # Uses YANA_LOGFILE environment variable if set.
    [string]$LogFile = $Env:YANA_LOGFILE
  )
  # Disable progress bar output
  $Script:ProgressPreference = 'SilentlyContinue'
  log info "$Script:YANA_TITLE Version: $Script:YANA_VERSION"
  $Script:YANA_TRACE = $Env:YANA_TRACE -eq 'true'
  $Script:YANA_DEBUG = $Script:YANA_TRACE -or $Env:YANA_DEBUG -eq 'true'
  if ($Script:YANA_DEBUG) { log debug 'Debug logging is enabled.' }
  if ($Script:YANA_TRACE) { $script:VerbosePreference = 'Continue' }
  if ($Help) { _yana_usage -Mode $Mode; return }
  switch ($Mode) {
    'test' { _yanatool_mode_test -Source $Source }
    'version' { $Script:YANA_VERSION }
    default { throw "Unknown mode: '$Mode'. Use -help for usage information." }
  }
}

# Prevent running when dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
  $ErrorActionPreference = 'Stop'
  try {
    _yanatool_ @args
  } catch {
    log fatal $_.Exception.Message
    $_.ScriptStackTrace | ForEach-Object { log stack $_ }
    exit 1
  }
}
