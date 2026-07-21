function YANAapply:dir.create {
  param ([string]$Path)
  if (-not (Test-Path -Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force
  }
}
function YANAverify:dir.create {
  param ([string]$Path)
  # Return true if directory exists
  Test-Path -Path $Path -PathType Container
}

function YANAapply:file.create {
  param ([string]$Path)
  New-Item -ItemType File -Path $Path -Force
}
function YANAverify:file.create {
  param ([string]$Path)
  # Return true if file exists
  Test-Path -Path $Path -PathType Leaf
}

function YANAapply:file.write {
  param ([string]$Path, [string]$Content = '')
  YANAapply:file.create -Path $Path
  if (YANAverify:file.write -Path $Path -Content $Content) { return }
  [System.IO.File]::WriteAllText($Path, $Content)
}
function YANAverify:file.write {
  param ([string]$Path, [string]$Content = '')
  if (-not (YANAverify:file.create -Path $Path)) { return $false }
  $existingContent = Get-Content -Path $Path -Raw
  return ($Content -eq $existingContent)
}
