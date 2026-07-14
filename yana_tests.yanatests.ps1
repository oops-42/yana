# This script contains example tests for YANA Testing Framework itself.
# Many tests are included into the YANA Testing Framework.
# Below are some additional tests provided as a demonstration.

# The tested script shall be sourced.
# In this case we do not source it since we are running in yana_tests.ps1 context.
# . "$PSScriptRoot/yana_tests.ps1"

function YANAtest:Invoke-YanaTestFunction@exception {
  # Demonstrates catching command failures inside a test function

  try {
    throw 'This is a test exception'
    fail 'This should not be reached'
  } catch {
    pass "Caught exception: $($_.Exception.Message)"
  }
}

function YANAtest:Invoke-YanaTestFunction@missing_test_function {
  # Demonstrates how to use mock functions to capture output

  $test_result = & {
    $Script:mock_buffer = @()
    function Out-Colored {
      # Declare the parameters which make sense for testing purposes.
      param(
        [string]$Color,
        [string]$Message,
        [string]$MessageDetail
      )
      $Script:mock_buffer += $PSBoundParameters
    }
    Invoke-YanaTestFunction -TestFunctionName 'NonExistentTestFunction'
  }

  if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) { pass 'Test does not fail' } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
  if ($Script:mock_buffer.Count -eq 1) {
    pass 'Error is displayed'
  } else { fail 'Should display error but got:', $Script:mock_buffer.Message }
  if ($Script:mock_buffer[0].Color -eq 'red') {
    pass 'Error color is red'
  } else { fail "Expected error color to be 'red' but got: $($Script:mock_buffer[0].Color)" }
  if ($Script:mock_buffer[0].Message -eq "Error: Test function 'NonExistentTestFunction' does not exist") {
    pass 'Error message is correct'
  } else { fail "Expected error message to be 'Error: Test function 'NonExistentTestFunction' does not exist' but got: $($Script:mock_buffer[0].Message)" }
}

function YANAtest:Invoke-YanaTestFunction@with_test_function {
  # Demonstrates how to invoke a test function and check its output and exit code.

  $testFnName = 'YANAtest:Invoke-YanaTestFunction@with_test_function_subtest'
  # This allows defining the test function dynamically
  New-Item -Path Function: -Name $testFnName -value {
    pass 'This test should pass'
  } -Force | Out-Null

  $test_result = & {
    # Mock the Out-Colored function to capture its output for inspection
    $Script:mock_buffer = @()
    function Out-Colored {
      # Declare the parameters which make sense for testing purposes.
      param(
        [string]$Color,
        [string]$Message,
        [string]$MessageDetail
      )
      $Script:mock_buffer += $PSBoundParameters
    }
    Invoke-YanaTestFunction -TestFunctionName $testFnName
  }

  if ($test_result.Passed -eq 1) {
    pass 'Test passes as expected'
  } else { fail "Expected 1 passed subtest, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) {
    pass 'Test does not fail'
  } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
  if ($Script:mock_buffer.Count -gt 0) {
    pass 'Output is generated'
  } else { fail 'Expected output to be generated but got nothing' }
  if ($Script:mock_buffer[0].Color -eq 'cyan') {
    pass 'Output color is cyan'
  } else { fail "Expected output color to be 'cyan' but got: $($Script:mock_buffer[0].Color)" }
  if ($Script:mock_buffer[0].Message -eq 'Running test function') {
    pass 'Output contains expected test running message'
  } else { fail "Expected output to contain 'Running test function' message but got: $($Script:mock_buffer[0].Message)" }
  if ($Script:mock_buffer[0].MessageDetail -eq $testFnName) {
    pass 'Output contains expected test function name'
  } else { fail "Expected output to contain test function name '$testFnName' but got: $($Script:mock_buffer[0].MessageDetail)" }
}

function YANAtest:Invoke-YanaTestFile@with_valid_content {
	# Demonstrates how to:
  # - create a temporary test file
  # - use mock functions
  # - override the behavior of tested function using variable overrides

  $testScript = {
    function YANAtest:TestFunction1@pass {
      pass 'Test passed'
    }
    function YANAtest:TestFunction2@fail {
      fail 'Test failed'
    }
  }
  $tempFile = [System.IO.Path]::GetTempFileName() + '.ps1'
  $testScript | Set-Content -Path $tempFile

  try {
    $result = & {
      # Mock the Get-YanaTest function to return predefined test results
      function Get-YanaTest {
        @(
          'YANAtest:TestFunction1@pass'
          'YANAtest:TestFunction2@fail'
        )
      }
      $Quiet = $true
      $LogFile = $null
      Invoke-YanaTestFile -TestFile $tempFile -TestName '*'
    }
    if ($result.Passed -eq 1) { pass 'Test file executed with passed tests' } else { fail 'No tests passed' }
    if ($result.Failed -eq 1) { pass 'Test file executed with failed tests' } else { fail 'No tests failed' }
  } finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
  }
}
