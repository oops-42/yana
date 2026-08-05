function YANAapply_create {
  param ([string]$Path)
  # if (-not (Test-Path -Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force
  # }
}
function YANAverify_create {
  param ([string]$Path)
  if ([string]::IsNullOrEmpty($Path)) { throw 'Path cannot be null or empty.' }
  # Return true if directory exists
  Test-Path -Path $Path -PathType Container
}
