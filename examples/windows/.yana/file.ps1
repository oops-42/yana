function YANAapply_create {
  param ([string]$Path)
  New-Item -ItemType File -Path $Path -Force
}
function YANAverify_create {
  param ([string]$Path)
  if ([string]::IsNullOrEmpty($Path)) { throw 'Path cannot be null or empty.' }
  # Return true if file exists
  Test-Path -Path $Path -PathType Leaf
}

function YANAapply_write {
  param ([string]$Path, [string]$Content = '')
  YANAapply_create -Path $Path
  # if (YANAverify_write -Path $Path -Content $Content) { return }
  [System.IO.File]::WriteAllText($Path, $Content)
}
function YANAverify_write {
  param ([string]$Path, [string]$Content = '')
  if ([string]::IsNullOrEmpty($Path)) { throw 'Path cannot be null or empty.' }
  if (-not (YANAverify_create -Path $Path)) { return $false }
  $existingContent = Get-Content -Path $Path -Raw
  return ($Content -eq $existingContent)
}
