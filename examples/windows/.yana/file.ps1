function YANAapply_create {
  param ([string]$Path, [string]$Content)
  New-Item -ItemType File -Path $Path -Force
  if ($Content) {
    [System.IO.File]::WriteAllText($Path, $Content)
  }
}
function YANAverify_create {
  param ([string]$Path, [string]$Content)
  if ([string]::IsNullOrEmpty($Path)) { throw 'Path cannot be null or empty.' }
  if (-not (Test-Path $Path -PathType Leaf)) { return $false }
  # Return true if file exists
  if ($Content) {
    $existingContent = [System.IO.File]::ReadAllText($Path)
    return ($Content -eq $existingContent)
  }
  return $true
}

function YANAapply_write {
  param ([string]$Path, [string]$Content = '')
  YANAapply_create -Path $Path | Out-Null
  [System.IO.File]::WriteAllText($Path, $Content)
}
function YANAverify_write {
  param ([string]$Path, [string]$Content = '')
  if ([string]::IsNullOrEmpty($Path)) { throw 'Path cannot be null or empty.' }
  if (-not (Test-Path $Path -PathType Leaf)) { return $false }
  $existingContent = [System.IO.File]::ReadAllText($Path)
  return ($Content -eq $existingContent)
}

function YANAvar_read([string]$path) {
  if (-not $path) { throw "'path' argument is required" }
  if (Test-Path $path -PathType Container) { throw "'$path' is a directory, expected a file" }
  if (-not (Test-Path $path -PathType Leaf)) { throw "File '$path' does not exist" }
  Get-Content "$path" -Raw
}
