. "$PSScriptRoot/yana.ps1"

function YANAtest:Invoke-Yana@no_arg {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function Out-Colored {}
    function Out-Help {
      param([string]$Mode)
      @{ Command = 'Out-Help'; Args = $PSBoundParameters }
    }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      Invoke-Yana
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -ne 0) {
    pass 'Exit code is correct'
  } else {
    fail "Expected exit code non-zero but got: $($result.exit_code)"
  }
  if ($null -ne $result.exception) {
    pass 'Exception is thrown'
    if ($result.exception.Message -eq 'No mode specified. Use -help to see available modes.') {
      pass 'Error message is correct'
    } else {
      fail "Expected error message to contain 'No mode specified. Use -help to see available modes.' but got: $($result.exception.Message)"
    }
  } else {
    fail 'Expected exception to be thrown but got none'
  }
}

function YANAtest:Invoke-Yana@help_no_mode {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function Out-Colored {}
    function Out-Help {
      param([string]$Mode)
      @{ Command = 'Out-Help'; Args = $PSBoundParameters }
    }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      Invoke-Yana -help
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq 'Out-Help') {
      pass 'Out-Help is called'
    } else {
      fail "Expected Out-Help to be called but got: $($result.output.Command)"
    }
    if ([string]::IsNullOrEmpty($result.output[0].Args['Mode'])) {
      pass 'Out-Help mode is empty'
    } else {
      fail "Expected Out-Help mode to be empty but got: $($result.output[0].Args['Mode'])"
    }
  } else {
    fail "Expected Out-Help to be called once but got: $($result.output.Length) times"
  }
  if ([string]::IsNullOrEmpty($result.output[0].Args['Mode'])) {
    pass 'Out-Help mode is empty'
  } else {
    fail "Expected Out-Help mode to be empty but got: $($result.output[0].Args['Mode'])"
  }
}

function YANAtest:Invoke-Yana@help_with_mode {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function Out-Colored {}
    function Out-Help {
      param([string]$Mode)
      @{ Command = 'Out-Help'; Args = $PSBoundParameters }
    }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      Invoke-Yana -help -Mode apply
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq 'Out-Help') {
      pass 'Out-Help is called'
    } else {
      fail "Expected Out-Help to be called but got: $($result.output.Command)"
    }
    if ($result.output[0].Args['Mode'] -eq 'apply') {
      pass 'Out-Help mode is apply'
    } else {
      fail "Expected Out-Help mode to be apply but got: $($result.output[0].Args['Mode'])"
    }
  } else {
    fail "Expected Out-Help to be called once but got: $($result.output.Length) times"
  }
}

function YANAtest:Invoke-Yana@version {
  function Out-Colored {}
  $test_result = Invoke-Yana -Version
  if ($test_result -eq $Script:YANA_VERSION) {
    pass 'Version output is correct'
  } else {
    fail "Expected version output to be '$Script:YANA_VERSION' but got: $test_result"
  }
}

function YANAtest:Invoke-Yana@mode_apply {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function Out-Colored {}
    function Invoke-YanaApply {
      param([string]$Source)
      @{ Command = 'Invoke-YanaApply'; Args = $PSBoundParameters }
    }
    function Invoke-YanaVerify {
      param([string]$Source)
      @{ Command = 'Invoke-YanaVerify'; Args = $PSBoundParameters }
    }
    function Invoke-YanaFetch {
      param([string]$Source)
      @{ Command = 'Invoke-YanaFetch'; Args = $PSBoundParameters }
    }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      Invoke-Yana -Mode 'apply' -Source some_source
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq 'Invoke-YanaApply') {
      pass 'Invoke-YanaApply is called'
      if ($result.output[0].Args['Source'] -eq 'some_source') {
        pass 'Invoke-YanaApply source is correct'
      } else {
        fail "Expected Invoke-YanaApply source to be 'some_source' but got: $($result.output[0].Args['Source'])"
      }
    } else {
      fail "Expected Invoke-YanaApply to be called but got: $($result.output.Command)"
    }
  } else {
    fail "Expected Invoke-YanaApply to be called once but got: $($result.output.Length) times"
  }
}

function YANAtest:Invoke-Yana@mode_verify {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function Out-Colored {}
    function Invoke-YanaApply {
      param([string]$Source)
      @{ Command = 'Invoke-YanaApply'; Args = $PSBoundParameters }
    }
    function Invoke-YanaVerify {
      param([string]$Source)
      @{ Command = 'Invoke-YanaVerify'; Args = $PSBoundParameters }
    }
    function Invoke-YanaFetch {
      param([string]$Source)
      @{ Command = 'Invoke-YanaFetch'; Args = $PSBoundParameters }
    }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      Invoke-Yana -Mode 'verify' -Source some_source
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq 'Invoke-YanaVerify') {
      pass 'Invoke-YanaVerify is called'
      if ($result.output[0].Args['Source'] -eq 'some_source') {
        pass 'Invoke-YanaVerify source is correct'
      } else {
        fail "Expected Invoke-YanaVerify source to be 'some_source' but got: $($result.output[0].Args['Source'])"
      }
    } else {
      fail "Expected Invoke-YanaVerify to be called but got: $($result.output.Command)"
    }
  } else {
    fail "Expected Invoke-YanaVerify to be called once but got: $($result.output.Length) times"
  }
}

function YANAtest:Invoke-Yana@mode_fetch {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function Out-Colored {}
    function Invoke-YanaApply {
      param([string]$Source)
      @{ Command = 'Invoke-YanaApply'; Args = $PSBoundParameters }
    }
    function Invoke-YanaVerify {
      param([string]$Source)
      @{ Command = 'Invoke-YanaVerify'; Args = $PSBoundParameters }
    }
    function Invoke-YanaFetch {
      param([string]$Source)
      @{ Command = 'Invoke-YanaFetch'; Args = $PSBoundParameters }
    }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      Invoke-Yana -Mode 'fetch' -Source some_source
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq 'Invoke-YanaFetch') {
      pass 'Invoke-YanaFetch is called'
      if ($result.output[0].Args['Source'] -eq 'some_source') {
        pass 'Invoke-YanaFetch source is correct'
      } else {
        fail "Expected Invoke-YanaFetch source to be 'some_source' but got: $($result.output[0].Args['Source'])"
      }
    } else {
      fail "Expected Invoke-YanaFetch to be called but got: $($result.output.Command)"
    }
  } else {
    fail "Expected Invoke-YanaFetch to be called once but got: $($result.output.Length) times"
  }
}

function YANAtest:Invoke-Yana@invalid_mode {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function Out-Colored {}
    function Invoke-YanaApply {
      param([string]$Source)
      @{ Command = 'Invoke-YanaApply'; Args = $PSBoundParameters }
    }
    function Invoke-YanaVerify {
      param([string]$Source)
      @{ Command = 'Invoke-YanaVerify'; Args = $PSBoundParameters }
    }
    function Invoke-YanaFetch {
      param([string]$Source)
      @{ Command = 'Invoke-YanaFetch'; Args = $PSBoundParameters }
    }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      Invoke-Yana -Mode 'unknown' -Source some_source
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -ne 0) {
    pass 'Exit code is non-zero'
  } else {
    fail "Expected exit code non-zero but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 0) {
    pass 'No mode functions are called'
  } else {
    fail "Expected no mode functions to be called but got: $($result.output.Command)"
  }
  if ($null -ne $result.exception) {
    pass 'Exception is thrown'
    if ($result.exception.Message -eq "Unknown mode: unknown. Use -help to see available modes.") {
      pass 'Error message is correct'
    } else {
      fail "Expected error message to contain 'Unknown mode: unknown. Use -help to see available modes.' but got: $($result.exception.Message)"
    }
  } else {
    fail 'Expected exception to be thrown but got none'
  }
}

function YANAtest:Invoke-Yana@env_vars {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function Out-Colored {}
    function Invoke-YanaApply {
      param([string]$Source)
      "apply: '$Source'"
    }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = 'apply', 'some_source'
    try {
      Invoke-Yana
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array


  if ($result.exit_code -eq 0) {
    pass 'Exit code is correct'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($null -eq $result.exception) {
    pass 'No exception is thrown'
  } else {
    fail "Expected no exception to be thrown but got: $($result.exception.Message)"
  }
  if ($result.output.Length -eq 1) {
    $expect = "apply: 'some_source'"
    if ($result.output[0] -eq $expect) {
      pass 'Output is correct'
    } else {
      fail "Expected output to be '$expect' but got: $($result.output)"
    }
  } else {
    fail "Expected output length to be 1 but got: $($result.output.Length)"
  }
}
