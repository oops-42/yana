#!/usr/bin/env pwsh
#Requires -Version 5.1
<#
.SYNOPSIS
    YANA Engine (Windows PowerShell / PowerShell Core Implementation)
.DESCRIPTION
    Ultra-lean, deterministic execution runner that ingests flat yanaspec.json
    manifests directly and maps them to PowerShell module functions.
#>
[CmdletBinding()]
param (
  [string]$Manifest = '.yana.json',
  [string]$ModuleDir = '.',
  [switch]$VerifyOnly,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function _yana_usage {
  Write-Host 'Usage: yana-apply.ps1 [-Manifest <manifest file>] [-ModuleDir <module directory>] [-VerifyOnly] [-Quiet]'
  exit 1
}

function yana_log([string]$Message, [string]$Level = 'INFO') {
  $_yana_log_levels = @{
    'INFO'  = 'Cyan'
    'WARN'  = 'Yellow'
    'ERROR' = 'Red'
  }
  if (-not $Quiet) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = $_yana_log_levels[$Level]
    if (-not $color) { $color = 'White' }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
  }
}

function yana_error([string]$Message) {
  yana_log -Message $Message -Level 'ERROR'
}

$ERR_GENERAL = 1
$ERR_MISUSE = 64
$ERR_DATA_FORMAT = 65
$ERR_NO_INPUT = 66
function yana_throw([string]$Message, [int]$ErrorCode = $ERR_GENERAL) {
  yana_log -Message $Message -Level 'ERROR'
  exit $ErrorCode
}

function _yana_check_prerequisites([string[]]$Requirements) {
  foreach ($req in $Requirements) {
    if (-not (Get-Command $req -ErrorAction SilentlyContinue)) {
      yana_throw "Prerequisite tool '$req' is missing on host node." $ERR_MISUSE
    }
  }
}

function _yana_resolve_vars([string]$InputString, [hashtable]$Params, [hashtable]$Outputs) {
  $_max_iterations = 50
  $_iteration = 0
  $_varPattern = '\$\{(param|env|var|output):([a-zA-Z0-9_]+)\}'
  $_outputString = $InputString
  while ($_outputString -match $_varPattern) {
    if ($_iteration -ge $_max_iterations) {
      yana_throw "Variable resolution exceeded $_max_iterations iterations (possible circular reference)." $ERR_DATA_FORMAT
    }
    $_iteration++
    $_var = $Matches[0]
    $_ctx = $Matches[1]
    $_key = $Matches[2]
    $_value = ''
    switch ($_ctx) {
      'param' {
        if ($Params.ContainsKey($_key)) {
          $_value = $Params[$_key]
        } else {
          yana_log "Parameter '$_key' not found in spec parameters." 'WARN'
        }
      }
      'env' { if (Test-Path env:$_key) {
          $_value = [Environment]::GetEnvironmentVariable($_key)
        } else {
          yana_log "Environment variable '$_key' not found." 'WARN'
        }
      }
      'output' { if ($Outputs.ContainsKey($_key)) {
          $_value = $Outputs[$_key]
        } else {
          yana_log "Output variable '$_key' not found in previous step outputs." 'WARN'
        }
        break
      }
      'var' { $_fn = "yanavar_${_key}"
        if (Get-Command $_fn -ErrorAction:Ignore) {
          $_value = & $_fn
        } else {
          yana_log "Variable function '$_fn' not found." 'WARN'
        }
      }
      default { yana_error "Unknown variable type '$_ctx' in variable reference '$_var'. This should never happen. Please report this as a bug." }
    }
    $_outputString = $_outputString -replace [regex]::Escape($_var), $_value
  }
  $_outputString
}

function _yana_execute_fn([string]$FunctionName, [hashtable]$FunctionArgs) {
  # Executes a function by name with provided arguments. Throws error if function is not found.
  $_fn = Get-Command $FunctionName -ErrorAction:Ignore
  if (-not $_fn) {
    yana_throw "Function '$FunctionName' not found in loaded modules." $ERR_NO_INPUT
  }
  & $_fn @FunctionArgs

  # # TODO: Uses runspace to invoke the function in isolated context.
  # $iss = [initialsessionstate]::CreateDefault()
  # $iss.Commands.Add([System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($FunctionName, $_fn.Definition))
  # Get-Command 'yana_*' -ErrorAction SilentlyContinue | ForEach-Object {
  #   $iss.Commands.Add([System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($_.Name, $_.Definition))
  # }
  # $rs = [runspacefactory]::CreateRunspace($host, $iss)
  # $rs.Open()
  # $pl = $rs.CreatePipeline()

  # $pl.Commands.Add($FunctionName) | Out-Null
  # foreach ($key in $FunctionArgs.Keys) {
  #   $pl.Commands[0].Parameters.Add($key, $FunctionArgs[$key])
  # }
  # $result = $pl.Invoke()
  # if ($pl.HadErrors) {
  #   $errorMsg = $pl.Error | ForEach-Object { $_.ToString() } | Out-String
  #   yana_throw "Function '$FunctionName' execution failed with errors: $errorMsg" $ERR_GENERAL
  # }
  # $rs.Close()
  # $result
}

function _yana_parse_action_name([string]$ActionString) {
  # Parses action name in the format '[module/]script.function'
  $pattern = '^((\w+)/)?(\w+)\.(\w+)$'
  if ($ActionString -match $pattern) {
    return @{ module = $Matches[2]; script = $Matches[3]; function = $Matches[4] }
  } else {
    yana_raise "Invalid action format '$ActionString'. Expected format: '[module/]script.function'" $ERR_DATA_FORMAT
  }
}

function _yana_exec_step([hashtable]$Step, [hashtable]$Params, [hashtable]$Outputs) {
  $stepAction = $Step['action']
  $stepActionParts = _yana_parse_action_name -ActionString $stepAction
  $stepModule = $stepActionParts['module']
  $stepScript = $stepActionParts['script']
  $stepFunction = $stepActionParts['function']
  $stepName = $Step['name']
  if ([string]::IsNullOrEmpty($stepName)) { yana_throw 'Step name is required for each step in the spec.' $ERR_MISUSE }

  $stepId = $step['id']
  if ([string]::IsNullOrEmpty($stepId)) {
    yana_log "Step ID is missing for step '$stepName'." 'WARN'
    $stepId = ''
  } elseif ($stepId -notmatch '^\w+$') {
    yana_log "Step ID '$stepId' for step '$stepName' contains invalid characters. Only alphanumeric and underscore are allowed." 'WARN'
    $stepId = ''
  }

  Get-ChildItem -Path (Join-Path -Path $ModuleDir -ChildPath '.yana') -Filter '.ps1' | ForEach-Object {
    try {
      . $_.FullName
    } catch {
      yana_throw "Failed to source common script '$($_.FullName)' for step '$stepName'. Error: $_" $ERR_GENERAL
    }
  }
  $stepScriptPath = [System.IO.Path]::Combine($ModuleDir, '.yana', "$stepScript.ps1")
  if (-not (Test-Path -Path $stepScriptPath)) {
    yana_throw "Step script '$stepScriptPath' for step '$stepName' not found." $ERR_NO_INPUT
  }
  try {
    . $stepScriptPath
  } catch {
    yana_throw "Failed to source step script '$stepScriptPath' for step '$stepName'. Error: $_" $ERR_GENERAL
  }

  # Resolve arguments with variable substitution
  $YANA_ARGS = @{}
  foreach ($prop in $Step['args'].Keys) {
    $val = $Step['args'][$prop]
    if ($val -is [string]) {
      $YANA_ARGS[$prop] = _yana_resolve_vars -InputString $val -Params $Params -Outputs $Outputs
    } else {
      $YANA_ARGS[$prop] = $val
    }
  }

  $applyFuncName = "yanaapply_${stepFunction}"
  $verifyFuncName = "yanaverify_${stepFunction}"

  if (-not (Get-Command $applyFuncName -ErrorAction SilentlyContinue)) {
    yana_throw "Action function '$applyFuncName' not found for step '$stepName'." $ERR_NO_INPUT
  }
  if (-not (Get-Command $verifyFuncName -ErrorAction SilentlyContinue)) {
    $verifyFuncName = $null
  }

  $startTime = Get-Date
  if ([string]::IsNullOrEmpty($verifyFuncName)) {
    yana_log "  - [SKIPPED] $stepName (verification function does not exist for this action)"
    if ($VerifyOnly) { return $true }
  } else {
    $verifyResult = _yana_execute_fn -FunctionName $verifyFuncName -FunctionArgs $YANA_ARGS
    if ($verifyResult -eq $true) {
      if ($VerifyOnly) {
        yana_log "  - [COMPLIANT] $stepName (no changes needed)"
        return $true
      } else {
        yana_log "  - [SKIPPED] $stepName (already compliant)"
        return $true
      }
    } else {
      if ($VerifyOnly) {
        yana_log "  - [NON-COMPLIANT] $stepName (changes needed)" 'WARN'
        return $false
      }
    }
  }

  yana_log "  - [EXECUTING] $stepName"
  try {
    $applyResult = _yana_execute_fn -FunctionName $applyFuncName -FunctionArgs $YANA_ARGS
    if ([bool]$stepId -and $null -ne $applyResult) {
      $Outputs[$stepId] = $applyResult
    }
  } catch {
    yana_throw "Action '$applyFuncName' failed for step '$stepName' with error: $_" $ERR_GENERAL
  }

  if (-not [string]::IsNullOrEmpty($verifyFuncName)) {
    $postVerifyResult = _yana_execute_fn -FunctionName $verifyFuncName -FunctionArgs $YANA_ARGS
    if ($postVerifyResult -ne $true) {
      yana_throw "Post-verification failed for step '$stepName'. State change did not stick." $ERR_GENERAL
    } else {
      yana_log "  - [COMPLETED] $stepName (state change verified)"
    }
  } else {
    yana_log "  - [COMPLETED] $stepName (no verification function to confirm state)"
  }
  $endTime = Get-Date
  $duration = $endTime - $startTime
  yana_log "  - Step '$stepName' completed in $($duration.TotalSeconds) seconds."
}

function _yana_hashtable([Parameter(ValueFromPipeline = $true)]$InputObject) {
  $Local:resultValue = @{}
  if ($InputObject -is [System.Collections.IDictionary]) {
    foreach ($key in $InputObject.Keys) { $Local:resultValue[$key] = _yana_hashtable($InputObject[$key]) }
  } elseif ($InputObject -is [System.Collections.ICollection]) {
    $Local:resultValue = @()
    $InputObject | ForEach-Object { $Local:resultValue += _yana_hashtable($_) }
  } elseif ($InputObject -is [System.Management.Automation.PSCustomObject]) {
    foreach ($prop in $InputObject.PSObject.Properties) { $Local:resultValue[$prop.Name] = _yana_hashtable($prop.Value) }
  } else {
    $Local:resultValue = $InputObject
  }
  Write-Output $Local:resultValue -NoEnumerate:($Local:resultValue -is [Array])
}
function _yana_read_spec_file([string]$ManifestFile) {
  if ([string]::IsNullOrEmpty($ManifestFile)) { yana_throw 'No spec file provided.' $ERR_MISUSE }
  if (-not (Test-Path -Path $ManifestFile)) { yana_throw "Spec file '$ManifestFile' not found." $ERR_NO_INPUT }
  try {
    $spec = Get-Content -Path $ManifestFile -Raw | ConvertFrom-Json | _yana_hashtable
  } catch {
    yana_throw "Failed to parse YANA spec file '$ManifestFile'. Ensure it is valid JSON. Error: $_" $ERR_DATA_FORMAT
  }
  return $spec
}
function _yana_apply_spec() {
  $ManifestFile = [System.IO.Path]::Combine($ModuleDir, $Manifest)
  $_yana_spec = _yana_read_spec_file -ManifestFile $ManifestFile
  _yana_check_prerequisites -Requirements $_yana_spec.requires

  $_yana_spec_params = $_yana_spec['params']

  yana_log "=== YANA Engine Execution Target: $ManifestFile ==="
  if ($VerifyOnly) { yana_log 'Mode: Compliance Audit (--verify-only)' }

  $_yana_outputs = @{}
  $yana_spec_steps = $_yana_spec['steps']
  foreach ($step in $yana_spec_steps) {
    _yana_exec_step -Step $step -Params $_yana_spec_params -Outputs $_yana_outputs
  }
}

_yana_apply_spec
