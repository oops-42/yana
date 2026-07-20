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
Usage: yana.ps1 apply -source <path|url> [-routine <name>]
  Applies the specified YANA Module.

Options:
  -source <path|url>         Specifies the source of YANA Module to apply.
  -routine <name>            Specifies the routine to execute within the YANA Module.
'@
      break
    }
    'verify' {
      Write-Host @'
Usage: yana.ps1 verify -source <path|url> [-routine <name>]
  Compares the state of the system with the state specified by the YANA Module without making any changes.

Options:
  -source <path|url>         Specifies the source of YANA Module to verify.
  -routine <name>            Specifies the routine to execute within the YANA Module.
'@
      break
    }
    'fetch' {
      Write-Host @'
Usage: yana.ps1 fetch -source <path|url>
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

function Get-YanaValue {
  # .SYNOPSIS
  # 	Reads a value from a hashtable based on the specified filter expression.
  # .DESCRIPTION
  # 	The filter expression is in the format 'name[index].property' where:
  # 	- 'name' is the key in the hashtable.
  # 	- 'index' is an optional index for array values.
  # 	- 'property' is an optional property name for object values.
  #   The filter expression can be nested to access deeper levels of the hashtable.
  # .OUTPUTS
  # 	The value corresponding to the filter expression, or $null if not found.
  param(
    # The hashtable from which to read the value.
    [hashtable]$Hashtable,
    # The filter expression specifying the value to read.
    [string]$Filter
  )
  if ($Hashtable.ContainsKey($Filter)) { return $Hashtable[$Filter] }
  $parts = $Filter.TrimStart('.').Split('.')
  if ($parts.Count -eq 0) { throw "Invalid filter expression: '$Filter'. No parts found." }
  $current = $Hashtable
  foreach ($part in $parts) {
    if ([string]::IsNullOrEmpty($part)) { throw "Invalid filter expression: '$Filter'. Empty part found." }
    # This shall support array of arrays, e.g., b[1][0] or b[1][0][3].a
    $match = [regex]::Match($part, '^(?<name>\w+)?(\[(?<index>\d+)\])*$')
    if (-not $match.Success) { throw "Invalid filter expression: '$Filter'. Part '$part' is not valid." }
    $name = $match.Groups['name'].Value
    if ("$name" -ne '') {
      if ($current -isnot [System.Collections.IDictionary]) { throw "Current value is not a hashtable, cannot access key '$name'." }
      if (-not $current.ContainsKey($name)) { throw "Key '$name' not found in hashtable." }
      $current = $current[$name]
    }
    $match.Groups['index'].Captures | ForEach-Object {
      $i = [int]$_.Value
      if ($current -isnot [System.Collections.IList]) { throw "Current value is not an array, cannot access index $i." }
      if ($i -ge $current.Count) { throw "Index $i is out of bounds for array with count $($current.Count)." }
      $current = $current[$i]
    }
  }
  return $current
}

function Expand-YanaString {
  # .SYNOPSIS
  # 	Expands placeholders in the format ${category:name} within a string.
  # .DESCRIPTION
  # 	Supported categories: params, env, fn, outputs.
  # 	Supported name characters: alphanumeric, underscore.
  # .OUTPUTS
  # 	The string with placeholders replaced by their corresponding values.
  # 	If input string is exactly a placeholder, the function returns the value directly.
  # 	If input string contains multiple placeholders, they are replaced in the string as nested.
  param(
    # The input string containing placeholders.
    [Parameter(ValueFromPipeline = $true, Position = 0)]
    [string]$InputValue,
    # A hashtable containing parameter values for expansion.
    [hashtable]$Params = @{},
    # A hashtable containing output values for expansion.
    [hashtable]$Outputs = @{},
    # An object containing item values for expansion.
    $Item = $null
  )
  $pattern = '\$\{(param|output|item|env|var):(\w[\w\.\[\]]+)\}'
  $outputValue = $InputValue
  while ($outputValue -match $pattern) {
    $varPlaceholder = $matches[0]
    $varCategory = $matches[1]
    $varName = $matches[2]
    $replacementValue = switch ($varCategory) {
      'param' { Get-YanaValue $Params $varName }
      'output' { Get-YanaValue $Outputs $varName }
      # 'item' { if ($Item -and $Item.PSObject.Properties.Name -contains $varName) { $Item.$varName } else { $null } }
      'env' { [System.Environment]::GetEnvironmentVariable($varName) }
      'var' { if ($cmd = Get-Command -Name "YANAvar:$varName" -ErrorAction:Ignore) { & $cmd } else { $null } }
    }
    $replacementValue = $replacementValue | ConvertTo-HashTable
    if ($outputValue -eq $varPlaceholder) { return $replacementValue }
    if ($replacementValue -is [array] -or $replacementValue -is [hashtable]) {
      $outputValue = $outputValue.Replace($varPlaceholder, ($replacementValue | ConvertTo-Json -Compress -Depth 10))
    } else {
      $outputValue = $outputValue.Replace($varPlaceholder, "$replacementValue")
    }
  }
  $outputValue
}

function ConvertTo-HashTable {
  # .SYNOPSIS
  # 	Converts an object to a PowerShell hashtable.
  #   Accepts PSCustomObject, IDictionary, ICollection. Other types are returned as-is.
  # .OUTPUTS
  #   - A hashtable representing the InputObject if it is a PSCustomObject or IDictionary.
  #   - An array if the InputObject is an ICollection.
  #   - The InputObject itself if it is of any other type.
  param(
    # The object to convert.
    [Parameter(ValueFromPipeline = $true)]
    $InputObject
  )
  $Local:resultValue = @{}
  if ($InputObject -is [System.Collections.IDictionary]) {
    foreach ($key in $InputObject.Keys) { $Local:resultValue[$key] = ConvertTo-HashTable $InputObject[$key] }
  } elseif ($InputObject -is [System.Collections.ICollection]) {
    $Local:resultValue = @()
    $InputObject | ForEach-Object { $Local:resultValue += ConvertTo-HashTable $_ }
  } elseif ($InputObject -is [System.Management.Automation.PSCustomObject]) {
    foreach ($prop in $InputObject.PSObject.Properties) { $Local:resultValue[$prop.Name] = ConvertTo-HashTable $prop.Value }
  } else {
    $Local:resultValue = $InputObject
  }
  Write-Output $Local:resultValue -NoEnumerate:($Local:resultValue -is [Array])
}

function Read-YanaSpec {
  # .SYNOPSIS
  # 	Reads and parses a YANA specification file.
  param(
    # The directory of the YANA specification file.
    [string]$YanaDir
  )
  if (-not (Test-Path -Path $YanaDir -PathType Container)) { throw "Directory not found: $YanaDir" }
  $FilePath = Join-Path -Path $YanaDir -ChildPath '.yana.json'
  if (-not (Test-Path -Path $FilePath -PathType Leaf)) { throw "YANA specification file not found: $FilePath" }
  try {
    $jsonContent = Get-Content -Path $FilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop | ConvertTo-HashTable
    if ($jsonContent -isnot [hashtable]) { throw 'Parsed content is not a hashtable.' }
    if ($jsonContent.Count -eq 0) { throw 'Parsed content is empty.' }
    return $jsonContent
  } catch {
    throw "Failed to read or parse YANA specification file '$FilePath': $($_.Exception.Message)"
  }
}

function Invoke-YanaRoutineStepRoutine {
  # .SYNOPSIS
  # 	Invokes a routine within a YANA specification.
  param(
    # The routine step to invoke (must be a hashtable with 'routine' key).
    [hashtable]$Step,
    # A hashtable containing parameter values for expansion.
    [hashtable]$Params = @{},
    # A hashtable containing output values for expansion.
    [hashtable]$Outputs = @{},
    # An object containing item values for expansion.
    $Item = $null
  )
  $stepName = $Step['name']
  $stepRoutine = $Step['routine']
  if ([string]::IsNullOrEmpty($stepRoutine)) { throw 'Step routine is required.' }
  if ([string]::IsNullOrEmpty($stepName)) { $stepName = "routine___$stepRoutine" }
  throw "Routine invocation is not implemented yet. Routine: $stepRoutine, Step name: $stepName"
  # Placeholder for actual routine invocation logic
  # This would typically involve looking up the routine in the YANA specification and executing its steps
}

function Invoke-YanaRoutineStepAction {
  # .SYNOPSIS
  # 	Invokes a single action within a YANA routine.
  param(
    # The action to invoke (must be a hashtable with 'action' key).
    [hashtable]$Step,
    # A hashtable containing parameter values for expansion.
    [hashtable]$Params = @{},
    # A hashtable containing output values for expansion.
    [hashtable]$Outputs = @{},
    # An object containing item values for expansion.
    $Item = $null
  )
  $stepName = $Step['name']
  $stepAction = $Step['action']
  $stepOutput, $stepError = $null, $null

  if ([string]::IsNullOrEmpty($stepAction)) { throw 'Step action is required.' }
  if ([string]::IsNullOrEmpty($stepName)) { $stepName = "action___$stepAction" }
  # $cmd = Get-Command -Name "YANAaction:$stepName" -ErrorAction:Ignore
  # if (-not $cmd) { throw "Action '$stepName' not found." }
  $expandedArgs = @{}
  if ($Step.ContainsKey('args')) {
    foreach ($key in $Step.args.Keys) {
      $expandedArgs[$key] = Expand-YanaString -InputValue $Step.args[$key] -Params $Params -Outputs $Outputs -Item $Item
    }
  }
  # try {
  #   $stepOutput = & $cmd @expandedArgs
  # } catch {
  #   $stepError = $_.Exception.Message
  # }
  Write-Host "Executing step $stepName with action: $stepAction and args: $($expandedArgs | ConvertTo-Json -Depth 3 -Compress)" -ForegroundColor Cyan
  @{
    out     = $stepOutput
    err     = $stepError
    success = if ($stepError) { $false } else { $true }
    failed  = if ($stepError) { $true } else { $false }
  }
}
function Invoke-YanaRoutineStep {
  # .SYNOPSIS
  # 	Invokes a single step within a YANA routine.
  param(
    # The step to invoke (must be a hashtable with 'action' or 'routine').
    [hashtable]$Step,
    # A hashtable containing parameter values for expansion.
    [hashtable]$Params = @{},
    # A hashtable containing output values for expansion.
    [hashtable]$Outputs = @{},
    # An object containing item values for expansion.
    $Item = $null
  )
  $stepIsAction = $Step.ContainsKey('action')
  $stepIsRoutine = $Step.ContainsKey('routine')
  if ($stepIsAction -and $stepIsRoutine) { throw "Step cannot contain both 'action' and 'routine'." }

  $stepCondition = $Step['if']
  if ($stepCondition) {
    if ($stepCondition -is [Hashtable]) { throw 'Step condition must be a string, not a hashtable.' }
    if ($stepCondition -is [Array]) { throw 'Step condition must be a string, not an array.' }
    $conditionResult = Expand-YanaString -InputValue $stepCondition -Params $Params -Outputs $Outputs -Item $Item
    if ("$conditionResult" -in @('false', '0', '')) {
      Out-ColoredStderr -Color 'Yellow' -Message "Skipping step $stepName due to condition: $stepCondition"
      return
    }
  }
  if ($stepIsAction) {
    Invoke-YanaRoutineStepAction -Step $Step -Params $Params -Outputs $Outputs -Item $Item
  } elseif ($stepIsRoutine) {
    Invoke-YanaRoutineStepRoutine -Step $Step -Params $Params -Outputs $Outputs -Item $Item
  } else {
    throw "Step must contain either 'action' or 'routine'."
  }
}

function Set-YanaParams {
  # .SYNOPSIS
  # 	Merges the specified parameters into the YANA parameters hashtable.
  param(
    # A hashtable containing current parameter values.
    [hashtable]$CurrentParams,
    # A hashtable containing new parameter values to merge.
    [hashtable]$NewParams,
    [switch]$OverwriteExisting
  )
  if (-not $CurrentParams) { throw 'CurrentParams hashtable is required.' }
  if (-not $NewParams) { throw 'NewParams hashtable is required.' }
  foreach ($key in $NewParams.Keys) {
    if ($OverwriteExisting -or -not $CurrentParams.ContainsKey($key)) {
      $CurrentParams[$key] = $NewParams[$key]
    }
  }
  return $CurrentParams

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
function Invoke-YanaApply {
  # .SYNOPSIS
  # 	Applies the specified YANA Module.
  param(
    # The source of the YANA Module to apply (e.g., a file path or URL).
    [string]$Source,
    # The routine to execute within the YANA Module (optional).
    [string]$RoutineName
  )
  if ([string]::IsNullOrEmpty($Source)) { throw 'Source is required for ''apply'' mode.' }
  if ([string]::IsNullOrEmpty($RoutineName)) { $RoutineName = '.' }
  if (-not (Test-Path -Path $Source -PathType Container)) { throw "Source directory not found: $Source" }
  Out-ColoredStderr -Color 'Magenta' -Message "Applying YANA Module from source: $Source"
  $spec = Read-YanaSpec -YanaDir $Source
  Out-ColoredStderr -Color 'Magenta' -Message "`tName: $($spec.name)"
  Out-ColoredStderr -Color 'Magenta' -Message "`tVersion: $($spec.version)"
  Out-ColoredStderr -Color 'Magenta' -Message "`tDescription: $($spec.description)"
  Out-ColoredStderr -Color 'Magenta' -Message "`tAuthor: $($spec.author)"
  Out-ColoredStderr -Color 'Magenta' -Message "`tLicense: $($spec.license)"
  Out-ColoredStderr -Color 'Magenta' -Message "`tSupports: $($spec.supports -join ', ')"
  $specParams = $spec['params']
  if ($null -eq $specParams) { $specParams = @{} }
  if ($specParams -isnot [hashtable]) { throw 'YANA specification ''params'' must be a hashtable.' }
  Out-ColoredStderr -Color 'Magenta' -Message "`tParams:"
  foreach ($key in $specParams.Keys) {
    Out-ColoredStderr -Color 'Magenta' -Message "`t`t${key}: $($specParams[$key] | ConvertTo-Json -Compress -Depth 5)"
  }
  if (-not $spec.routines.ContainsKey($RoutineName)) { throw "Routine '$RoutineName' not found in YANA specification." }
  $routine = $spec.routines[$RoutineName]
  Out-ColoredStderr -Color 'Magenta' -Message "`tRoutine: $RoutineName"
  Out-ColoredStderr -Color 'Magenta' -Message "`tSteps:"
  foreach ($step in $routine) {
    Invoke-YanaRoutineStep -Step $step -Params $specParams -Outputs @{} -Item $null
  }
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
    if (-not $_.Exception.WasThrownFromThrowStatement) {
      [Console]::Error.WriteLine("Stack Trace: $($_.ScriptStackTrace)")
    }
    [Console]::ForegroundColor = $_fc
    exit 1
  }
}
