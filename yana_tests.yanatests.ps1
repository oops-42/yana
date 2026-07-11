# . "$PSScriptRoot/yana_tests.ps1"

$script:YANA_Mock_outBuffer = @()
function Out-Colored:Mock {
    param(
        [string]$Color,
        [string]$Message,
        [string]$MessageDetail,
        [switch]$Bold,
        [switch]$Underline,
        [switch]$NoNewLine
    )
    $script:YANA_Mock_outBuffer += $PSBoundParameters 
}

function YANAtest:Invoke-YanaTest@success {
    pass
}

function YANAtest:Invoke-YanaTest@failure {
    function YANAtest:Invoke-YanaTest@failure_subtest {
        fail 'This test should fail'
    }
    $test_result = Invoke-YanaTest -TestName 'Invoke-YanaTest@failure_subtest' -Quiet
    if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
    if ($test_result.Failed -eq 1) { pass 'Test fails as expected' } else { fail "Expected 1 failed subtest, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTest@exception {
    try {
        throw 'This is a test exception'
        fail 'This should not be reached'
    }
    catch {
        pass "Caught exception: $($_.Exception.Message)"
    }
}

function YANAtest:Invoke-YanaTest@exception_in_test {
    function YANAtest:Invoke-YanaTest@exception_in_test_subtest {
        throw 'This is a test exception'
    }
    $test_result = Invoke-YanaTest -TestName 'Invoke-YanaTest@exception_in_test_subtest' -Quiet
    if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
    if ($test_result.Failed -eq 1) { pass 'Test fails as expected' } else { fail "Expected 1 failed subtest, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTest@without_test_function {
    $test_result = Invoke-YanaTest -Quiet
    if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
    if ($test_result.Failed -eq 0) { pass 'Test does not fail' } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTest@missing_test_function {
    $YANA_Mock_outBuffer.Clear()
    $test_result = {
        Set-Alias -Name Out-Colored -Value Out-Colored:Mock -Scope Local
        Invoke-YanaTest -TestName 'NonExistentTestFunction'
    }.InvokeReturnAsIs()
    if ($YANA_Mock_outBuffer.Count -eq 0) { pass 'Nothing is displayed' } else { fail 'Should be nothing displayed but got:', $YANA_Mock_outBuffer }
    if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
    if ($test_result.Failed -eq 0) { pass 'Test does not fail' } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTest@with_test_function {
    $testFnName = 'Invoke-YanaTest@with_test_function_subtest'
    New-Item -Path Function: -Name "YANAtest:$testFnName" -value {
        pass 'This test should pass'
    } -Force | Out-Null

    $YANA_Mock_outBuffer.Clear()
    $test_result = {
        Set-Alias -Name Out-Colored -Value Out-Colored:Mock -Scope Local
        Invoke-YanaTest -TestName $testFnName
    }.InvokeReturnAsIs()
    if ($test_result.Passed -eq 1) { pass 'Test passes as expected' } else { fail "Expected 1 passed subtest, got: $($test_result.Passed)" }
    if ($test_result.Failed -eq 0) { pass 'Test does not fail' } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
    if ($YANA_Mock_outBuffer.Count -gt 0) { pass 'Output is generated' } else { fail 'Expected output to be generated but got nothing' }
    if ($YANA_Mock_outBuffer[0].Color -eq 'cyan') { pass 'Output color is cyan' } else { fail "Expected output color to be 'cyan' but got: $($YANA_Mock_outBuffer[0].Color)" }
    if ($YANA_Mock_outBuffer[0].Message -eq 'Running test') { pass 'Output contains expected test running message' } else { fail "Expected output to contain 'Running test' message but got: $($YANA_Mock_outBuffer[0].Message)" }
    if ($YANA_Mock_outBuffer[0].MessageDetail -eq $testFnName) { pass 'Output contains expected test function name' } else { fail "Expected output to contain test function name '$testFnName' but got: $($YANA_Mock_outBuffer[0].MessageDetail)" }
}

