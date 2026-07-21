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

function Write-Log {
  param ([string]$Message, [string]$Level = 'INFO')
  if (-not $Quiet) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
      'WARN' { 'Yellow' }
      'ERROR' { 'Red' }
      'INFO' { 'Cyan' }
      default { 'White' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
  }
}

# 1. Load JSON Manifest
$ManifestFile = Join-Path -Path $ModuleDir -ChildPath $Manifest
if (-not (Test-Path -Path $ManifestFile)) {
  Write-Error "YANA Engine Error: Manifest file '$ManifestFile' not found."
  exit 1
}

$spec = Get-Content -Path $ManifestFile -Raw | ConvertFrom-Json

# 2. Pre-flight Requirement Checks
if ($spec.requires) {
  Write-Log 'Running pre-flight requirement checks...'
  foreach ($req in $spec.requires) {
    if (-not (Get-Command $req -ErrorAction SilentlyContinue)) {
      Write-Error "Pre-flight Check Failed: Required command/executable '$req' is missing."
      exit 1
    }
  }
  Write-Log 'Pre-flight requirement checks passed.'
}

$ModulesDir = Join-Path -Path $ModuleDir -ChildPath '.yana'
# 3. Load Module Scripts
if (Test-Path -Path $ModulesDir) {
  Get-ChildItem -Path $ModulesDir -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
  }
} else {
  Write-Log "Modules directory '$ModulesDir' not found." 'WARN'
}

# 4. Dynamic Variable Resolver
function Resolve-YanaVariables {
  param ([string]$InputString, [PSCustomObject]$Params, [PSCustomObject]$Outputs)

  if ([string]::IsNullOrEmpty($InputString)) { return $InputString }

  $pattern = '\$\{([^:]+):([^}]+)\}'
  return [regex]::Replace($InputString, $pattern, {
      param($match)
      $prefix = $match.Groups[1].Value
      $key = $match.Groups[2].Value

      switch ($prefix) {
        'param' {
          if ($Params.$key -ne $null) { return $Params.$key }
          return ''
        }
        'env' {
          return [Environment]::GetEnvironmentVariable($key)
        }
        'output' {
          if ($Outputs.$key -ne $null) { return $Outputs.$key }
          return ''
        }
        'var' {
          switch ($key) {
            'time' { return (Get-Date -Format 'o') }
            'iso_time' { return (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ') }
            'guid' { return [guid]::NewGuid().ToString() }
            'user' { return [Environment]::UserName }
            'domain' { return [Environment]::UserDomainName }
            'os' { return [System.Environment]::OSVersion.VersionString }
            'is_admin' { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
            'hostname' { return [Environment]::MachineName }
            default { return '' }
          }
        }
        default { return $match.Value }
      }
    })
}

function Resolve-StepArgs {
  param ($ArgsObject, $Params, $Outputs)
  if ($null -eq $ArgsObject) { return @{} }

  $resolved = @{}
  foreach ($prop in $ArgsObject.psobject.Properties) {
    $val = $prop.Value
    if ($val -is [string]) {
      $resolved[$prop.Name] = Resolve-YanaVariables -InputString $val -Params $Params -Outputs $Outputs
    } else {
      $resolved[$prop.Name] = $val
    }
  }
  return $resolved
}

# 5. Execution Pipeline
Write-Log "Starting YANA Execution Pipeline (VerifyOnly: $VerifyOnly)..."
$globalOutputs = [PSCustomObject]@{}
$overallStatus = 0

foreach ($step in $spec.steps) {
  $stepName = if ($step.name) { $step.name } else { "$($step.module):$($step.action)" }
  # $moduleName = $step.module
  $actionName = $step.action

  $applyFuncName = "YANAapply:${actionName}"
  $verifyFuncName = "YANAverify:${actionName}"

  Write-Log "Processing Step: '$stepName'"

  $resolvedArgs = Resolve-StepArgs -ArgsObject $step.args -Params $spec.params -Outputs $globalOutputs

  # Check if verification function exists in context
  $hasVerify = [bool](Get-Command $verifyFuncName -ErrorAction SilentlyContinue)

  # Pass 1: Pre-execution Verification (Idempotency Check)
  $alreadyCompliant = $false
  if ($hasVerify) {
    try {
      $verifyResult = & $verifyFuncName @resolvedArgs
      if ($verifyResult -eq $true) {
        $alreadyCompliant = $true
      }
    } catch {
      Write-Warning "Verification function '$verifyFuncName' failed with error: $_. Assuming non-compliance."
      $alreadyCompliant = $false
    }
  }

  # Audit Mode handling
  if ($VerifyOnly) {
    if ($alreadyCompliant) {
      Write-Log "[AUDIT: COMPLIANT] Step '$stepName' matches target state." 'INFO'
    } else {
      Write-Log "[AUDIT: NON-COMPLIANT] Step '$stepName' requires state change." 'WARN'
      $overallStatus = 1
    }
    continue
  }

  # Skip mutating action if state is already compliant
  if ($alreadyCompliant) {
    Write-Log "[SKIPPED] Step '$stepName' is already satisfied." 'INFO'
    continue
  }

  # Pass 2: Main Mutating Action
  if (-not (Get-Command $applyFuncName -ErrorAction SilentlyContinue)) {
    Write-Error "Action function '$applyFuncName' not found in loaded modules."
    exit 1
  }

  Write-Log "Executing mutating action '$applyFuncName'..."
  try {
    & $applyFuncName @resolvedArgs | Out-Null
  } catch {
    Write-Error "Action '$applyFuncName' failed with error: $_"
    exit 1
  }

  # Pass 3: Post-execution Verification
  if ($hasVerify) {
    $postVerify = & $verifyFuncName @resolvedArgs
    if ($postVerify -ne $true -and $LASTEXITCODE -ne 0) {
      Write-Error "Post-verification failed for step '$stepName'. State change did not stick."
      exit 1
    }
    Write-Log "Post-verification succeeded for step '$stepName'." 'INFO'
  }
}

Write-Log 'YANA Pipeline execution finished.' 'INFO'
exit $overallStatus
