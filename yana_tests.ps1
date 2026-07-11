# ---------------------------------------------------------------------------
# YANA Simple Testing Framework (PowerShell)
# ---------------------------------------------------------------------------
# It contains functions and variables that can be used in other scripts to facilitate testing of YANA code and modules.
# This framework supports running YANA tests.
# ---------------------------------------------------------------------------
# USAGE:
# 1. Create a new test script suffixing it with ".yanatests.ps1" and dot-source the tested script.
# 2. Define your test functions named as "YANAtest:<function>@<scenario>".
# 3. Use the `pass` and `fail` functions to indicate test results.
# 4. Execute this script directly to run all tests.
#   - You can also specify a specific test file and/or test function to run.
# ---------------------------------------------------------------------------
param(
    [ValidatePattern('\.yanatests\.ps1$')]
    [ArgumentCompleter({
            [OutputType([System.Management.Automation.CompletionResult])]
            param(
                [string] $CommandName,
                [string] $ParameterName,
                [string] $WordToComplete,
                [System.Management.Automation.Language.CommandAst] $CommandAst,
                [System.Collections.IDictionary] $FakeBoundParameters
            )
            # add all files ending with yanatests.ps1
            $CompletionResults = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()
            $testFiles = Get-ChildItem -Path $PWD -Recurse -Filter '*.yanatests.ps1' -ErrorAction SilentlyContinue
            foreach ($file in $testFiles) {
                $CompletionResults.Add((New-Object System.Management.Automation.CompletionResult($file.FullName, $file.Name, 'ParameterValue', $file.FullName)))
            }
            return $CompletionResults
        })]
    [string[]]$TestFile = @('*'),
    [string[]]$TestName = @('*'),
    [switch]$Quiet,
    [switch]$NoColor
)

function Out-Colored {
    param(
        [string]$Color,
        [string]$Message,
        [string]$MessageDetail = '',
        [switch]$Bold,
        [switch]$Underline,
        [switch]$NoNewLine
    )
    if ($Message.Length -gt 0) { $Message = "$Message " }
    if ($NoColor) {
        $message = "${Message}$MessageDetail"
    }
    else {
        $colorCode = switch ($Color) {
            'Black' { 30 }
            'Red' { 31 }
            'Green' { 32 }
            'Yellow' { 33 }
            'Blue' { 34 }
            'Magenta' { 35 }
            'Cyan' { 36 }
            'White' { 37 }
            default { 0 } # Default to no color
        }
        $styleCode = ''
        if ($Bold) { $styleCode += ';1' }
        if ($Underline) { $styleCode += ';4' }

        $message = "`u{001b}[${colorCode}${styleCode}m${Message}`u{001b}[2m${MessageDetail}`u{001b}[0m"
    }
    if ($NoNewLine) { [Console]::Error.Write($message) } else { [Console]::Error.WriteLine($message) }
}

function Get-YanaTest([string[]]$TestName) {
    $Local:testPrefix = 'YANAtest:'
    $Local:tests = @{}
    foreach ($tn in $TestName) {
        if (-not $tn.StartsWith($Local:testPrefix)) { $tn = "${Local:testPrefix}$tn" }
        Get-ChildItem Function: | Where-Object { $_.Name -like $tn } | ForEach-Object {
            $Local:tests[$_.Name.Substring($Local:testPrefix.Length)] = $_.Name
        }
    }
    $Local:tests
}

function Get-YanaTestFile([string]$TestFile) {
    try { Get-ChildItem -Path $PWD -Recurse -Filter '*.yanatests.ps1' -Include $TestFile -ErrorAction SilentlyContinue } catch { $null }
}

function Invoke-YanaTest([string[]]$TestName, [switch]$Quiet) {

    function pass {
        param([string]$Message = '')
        $caller = (Get-PSCallStack)[1]
        $location = "$($caller.ScriptName):$($caller.ScriptLineNumber)"
        if (-not $Message) { $Message = "$($caller.FunctionName) passed" }
        if (-not $Quiet) { Out-Colored 'green' "`t[√] ${Message}" $location }
        $YANA_subtests_ref.Value.Passed++
    }

    function fail {
        param([string]$Message = '')
        $caller = (Get-PSCallStack)[1]
        $location = "$($caller.ScriptName):$($caller.ScriptLineNumber)"
        if (-not $Message) { $Message = "$($caller.FunctionName) failed" }
        if (-not $Quiet) { Out-Colored 'red' "`t[x] ${Message}" $location }
        # $YANA_subtests[$YANA_testHash].Failed++
        $YANA_subtests_ref.Value.Failed++
        # throw "$($caller.FunctionName) failed"
    }
    $Local:YANA_testsPassed = 0
    $Local:YANA_testsFailed = 0
    $Local:YANA_tests = Get-YanaTest $TestName 
    $Local:YANA_subtests = @{}
    foreach ($YANA_test in $Local:YANA_tests.Keys) {
        $Local:YANA_testFunc = $Local:YANA_tests[$YANA_test]
        if (-not $Quiet) { Out-Colored 'cyan' 'Running test' $YANA_test }
        $Local:YANA_subtests[$Local:YANA_testFunc] = @{Passed = 0; Failed = 0 }
        $Local:YANA_subtests_ref = [ref]$Local:YANA_subtests[$Local:YANA_testFunc]
        try { $null = & $Local:YANA_testFunc } catch { fail "Exception $($_.Exception.Message)", $_.ScriptStackTrace.Split("`n")[0] }
        if ($Local:YANA_subtests_ref.Value.Failed -eq 0) { $Local:YANA_testsPassed++ } else { $Local:YANA_testsFailed++ }
        if (-not $Quiet) { Out-Colored 'yellow' "`t`tSub-tests: [√]Passed: $($Local:YANA_subtests_ref.Value.Passed)`t[x]Failed: $($Local:YANA_subtests_ref.Value.Failed)" }
    }
    @{
        Passed = $Local:YANA_testsPassed
        Failed = $Local:YANA_testsFailed
    }
}
function Invoke-YanaTestFile([string]$TestFile, [string[]]$TestName = '*', [switch]$Quiet) {

    $Local:YANA_testResult = @{ Passed = 0; Failed = 0 }

    if ([string]::IsNullOrEmpty($TestFile)) {
        if (-not $Quiet) { Out-Colored 'red' 'Error: Test file parameter is required' }
        return $Local:YANA_testResult
    }

    if ([System.IO.File]::Exists($TestFile)) {
        if (-not $Quiet) { Out-Colored 'magenta' 'Importing tests from file' $TestFile }
        . $TestFile
        $Local:YANA_testResult = Invoke-YanaTest -TestName $TestName -Quiet:$Quiet
    }
    else {
        if (-not $Quiet) { Out-Colored 'red' "Error: Test file '$TestFile' does not exist" }
    }

    $Local:YANA_testResult
}

function Invoke-YanaTesting ([string[]]$TestFile, [string[]]$TestName, [switch]$Quiet) {
    # Prevent running when dot-sourced
    if ($MyInvocation.InvocationName -eq '.') { return }

    $Local:YANA_testingResult = [pscustomobject]@{ Passed = 0; Failed = 0 }
    foreach ($file in (Get-YanaTestFile $TestFile)) {
        $test_result = Invoke-YanaTestFile -TestFile $file.FullName -TestName $TestName -Quiet:$Quiet
        $Local:YANA_testingResult.Passed += $test_result.Passed
        $Local:YANA_testingResult.Failed += $test_result.Failed
    }
    $Local:YANA_testingResult
    if ($Local:YANA_testingResult.Failed -gt 0) { exit 1 }
}

Invoke-YanaTesting -TestFile $TestFile -TestName $TestName -Quiet:$Quiet
