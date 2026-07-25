function YANAapply_ensure {
  param ([string]$Name, [string]$State)
  $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
  if ($null -eq $service) {
    Write-Error "Service '$Name' does not exist."
    return
  }
  if ($State -eq 'Running') {
    Start-Service -Name $Name
  } elseif ($State -eq 'Stopped') {
    Stop-Service -Name $Name
  }
}

function YANAverify_ensure {
  param ([string]$Name, [string]$State)
  if ([string]::IsNullOrEmpty($Name)) { throw 'Name cannot be null or empty.' }
  if ([string]::IsNullOrEmpty($State)) { throw 'State cannot be null or empty.' }
  # Return true if service matches the desired state
  $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
  $null -ne $service -and $service.Status -eq $State
}

function YANAapply_stop {
  param ([string]$Name)
  YANAapply_ensure -Name $Name -State 'Stopped'
}

function YANAverify_stop {
  param ([string]$Name)
  YANAverify_ensure -Name $Name -State 'Stopped'
}

function YANAapply_start {
  param ([string]$Name)
  YANAapply_ensure -Name $Name -State 'Running'
}

function YANAverify_start {
  param ([string]$Name)
  YANAverify_ensure -Name $Name -State 'Running'
}
