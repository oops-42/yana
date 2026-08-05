function yanavar_user() { $Env:USERNAME; }
function yanavar_group() { whoami }
function yanavar_hostname() { hostname; }
function yanavar_os() { uname -s; }
function yanavar_is_admin() {
  $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
  $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function yanavar_uuid() { [guid]::NewGuid().ToString() }
function yanavar_time([string]$format = '', [bool]$utc = $false) {
  $time = if ($utc) { [datetime]::UtcNow } else { [datetime]::Now }
  if ($format) { $time.ToString($format) } else { $time.ToString('o') }
}
function yanavar_iso_time() { [datetime]::UtcNow.ToString('o') }
