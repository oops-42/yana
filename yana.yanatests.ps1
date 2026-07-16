. "$PSScriptRoot/yana.ps1"

function YANAtest:Invoke-Yana@help_no_mode {
  $null = & {
    function Out-Colored {}
    $Script:mock_buffer = @()
    function Out-Help {
      param([string]$Mode)
      $Script:mock_buffer += $PSBoundParameters
    }
    try {
      Invoke-Yana -help
      $Script:exit_code = 0
    } catch {
      # Catch the exit to prevent the script from terminating during testing
      $Script:exit_code = $_.Exception.HResult
    }
  }
  if ($Script:exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail 'Expected exit code 0 but got:', $Script:exit_code
  }
  if ($Script:mock_buffer.Count -eq 1) {
    pass 'Out-Help is called'
  } else {
    fail "Expected Out-Help to be called but got: $($Script:mock_buffer.Count) calls"
  }
  if ([string]::IsNullOrEmpty($Script:mock_buffer[0].Mode)) {
    pass 'Out-Help mode is empty'
  } else {
    fail "Expected Out-Help mode to be empty but got: $($Script:mock_buffer[0].Mode)"
  }
}

function YANAtest:Invoke-Yana@help_with_mode {
  $mode = 'apply'
  $null = & {
    function Out-Colored {}
    $Script:mock_buffer = @()
    function Out-Help {
      param([string]$Mode)
      $Script:mock_buffer += $PSBoundParameters
    }
    try {
      Invoke-Yana -help -Mode $mode
      $Script:exit_code = 0
    } catch {
      # Catch the exit to prevent the script from terminating during testing
      $Script:exit_code = $_.Exception.HResult
    }
  }
  if ($Script:exit_code -eq 0) { pass 'Exit code is correct' } else { fail "Expected exit code 0 but got: $($Script:exit_code)" }
  if ($Script:mock_buffer.Count -eq 1) { pass 'Out-Help is called' } else { fail "Expected Out-Help to be called but got: $($Script:mock_buffer.Count) calls" }
  if ($Script:mock_buffer[0].Mode -eq $mode) { pass 'Out-Help mode is correct' } else { fail "Expected Out-Help mode to be '$mode' but got: $($Script:mock_buffer[0].Mode)" }
}

function YANAtest:Invoke-Yana@version {
  function Out-Colored {}
  $test_result = Invoke-Yana -Version
  if ($test_result -eq $YANA_VERSION) { pass 'Version output is correct' } else { fail "Expected version output to be '$YANA_VERSION' but got: $test_result" }
}

function YANAtest:Invoke-Yana@mode_apply {
  $source = 'test_source'
  $null = & {
    function Out-Colored {}
    $Script:mock_buffer = @()
    function Invoke-YanaApply {
      param([string]$Source)
      $Script:mock_buffer += $PSBoundParameters
    }
    try {
      Invoke-Yana -Mode 'apply' -Source $source
    } catch {
      fail 'Caught exception:', $_.Exception.Message
    }
  }
  if ($Script:mock_buffer.Count -eq 1) { pass 'Invoke-YanaApply is called' } else { fail "Expected Invoke-YanaApply to be called but got: $($Script:mock_buffer.Count) calls" }
  if ($Script:mock_buffer[0].Source -eq $source) { pass 'Invoke-YanaApply source is correct' } else { fail "Expected Invoke-YanaApply source to be '$source' but got: $($Script:mock_buffer[0].Source)" }
}
function YANAtest:Invoke-Yana@mode_verify {
  $source = 'test_source'
  $null = & {
    function Out-Colored {}
    $Script:mock_buffer = @()
    function Invoke-YanaVerify {
      param([string]$Source)
      $Script:mock_buffer += $PSBoundParameters
    }
    try {
      Invoke-Yana -Mode 'verify' -Source $source
    } catch {
      fail 'Caught exception:', $_.Exception.Message
    }
  }
  if ($Script:mock_buffer.Count -eq 1) { pass 'Invoke-YanaVerify is called' } else { fail "Expected Invoke-YanaVerify to be called but got: $($Script:mock_buffer.Count) calls" }
  if ($Script:mock_buffer[0].Source -eq $source) { pass 'Invoke-YanaVerify source is correct' } else { fail "Expected Invoke-YanaVerify source to be '$source' but got: $($Script:mock_buffer[0].Source)" }
}
function YANAtest:Invoke-Yana@mode_fetch {
  $source = 'test_source'
  $null = & {
    function Out-Colored {}
    $Script:mock_buffer = @()
    function Invoke-YanaFetch {
      param([string]$Source)
      $Script:mock_buffer += $PSBoundParameters
    }
    try {
      Invoke-Yana -Mode 'fetch' -Source $source
    } catch {
      fail 'Caught exception:', $_.Exception.Message
    }
  }
  if ($Script:mock_buffer.Count -eq 1) { pass 'Invoke-YanaFetch is called' } else { fail "Expected Invoke-YanaFetch to be called but got: $($Script:mock_buffer.Count) calls" }
  if ($Script:mock_buffer[0].Source -eq $source) { pass 'Invoke-YanaFetch source is correct' } else { fail "Expected Invoke-YanaFetch source to be '$source' but got: $($Script:mock_buffer[0].Source)" }
}
function YANAtest:Invoke-Yana@invalid_mode {
  $mode = 'invalid_mode'
  $null = & {
    function Out-Colored {}
    $Script:mock_buffer = @()
    function Out-Help {
      param(
        [string]$Mode
      )
      $Script:mock_buffer += $PSBoundParameters
    }
    try {
      Invoke-Yana -Mode $mode
      $Script:exit_code = 0
    } catch {
      # Catch the exit to prevent the script from terminating during testing
      $Script:exit_code = $_.Exception.HResult
    }
  }
  if ($Script:exit_code -ne 0) {
    pass 'Exit code is correct'
  } else {
    fail "Expected exit code non-zero but got: $($Script:exit_code)"
  }
  if ($Script:mock_buffer.Count -eq 1) {
    pass 'Out-Help is called'
  } else {
    fail 'Should call Out-Help 1 time but got:', $Script:mock_buffer.Count
  }
  if ([string]::IsNullOrEmpty($Script:mock_buffer[0].Mode)) {
    pass 'Out-Help mode is empty'
  } else {
    fail 'Expected Out-Help mode to be empty but got:', $Script:mock_buffer[0].Mode
  }

}
