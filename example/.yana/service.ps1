function YANAapply:service.ensure {
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

function YANAverify:service.ensure {
  param ([string]$Name, [string]$State)
  # Return true if service matches the desired state
  $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
  $null -ne $service -and $service.Status -eq $State
}

function YANAapply:service.stop {
  param ([string]$Name)
  YANAapply:service.ensure -Name $Name -State 'Stopped'
}

function YANAverify:service.stop {
  param ([string]$Name)
  YANAverify:service.ensure -Name $Name -State 'Stopped'
}

function YANAapply:service.start {
  param ([string]$Name)
  YANAapply:service.ensure -Name $Name -State 'Running'
}

function YANAverify:service.start {
  param ([string]$Name)
  YANAverify:service.ensure -Name $Name -State 'Running'
}
