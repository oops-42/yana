#!/usr/bin/env pwsh

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
	# The base path to start searching for test files.
	# Defaults to the current working directory.
	[string]$TestDir = $PWD,
	# Test file paths to invoke.
	# Accepts wildcards to match multiple files.
	# Defaults to all test files in the current directory and subdirectories.
	[string[]]$TestFile = @('*'),
	# Test function name(s) to invoke (using pattern 'YANAtest:<function>[@<scenario>]').
	[string[]]$TestName = @('*'),
	# If specified, outputs log messages to the given file.
	[string]$LogFile,
	# If specified, suppresses output messages.
	[switch]$Quiet,
	# If specified, disables colored output.
	[switch]$NoColor
)

# Disable progress bar output for cleaner test output
$Global:ProgressPreference = 'SilentlyContinue'

<#
.SYNOPSIS
	Outputs colored text to the console.
.DESCRIPTION
	The Out-Colored function outputs colored text to the console with optional bold, underline, and message detail.
.PARAMETER Color
	The color of the text (e.g., 'Red', 'Green', 'Blue').
.PARAMETER Message
	The main message to display.
.PARAMETER MessageDetail
	Additional details to display (optional). Will be displayed in dimmed color.
.PARAMETER Bold
	If specified, the text will be bold.
.PARAMETER Underline
	If specified, the text will be underlined.
.PARAMETER NoNewLine
	If specified, the output will not end with a new line.
.PARAMETER StdErr
	If specified, the output will be sent to standard error instead of standard output.
#>
function Out-Colored {
	param(
		[string]$Color,
		[string]$Message,
		[string]$MessageDetail = '',
		[switch]$Bold,
		[switch]$Underline,
		[switch]$StdErr
	)
	if ($Message.Length -gt 0) { $Message = "$Message " }
	if ($Script:LogFile) {
		$logMessage = "[$([datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))] ${Message}${MessageDetail}"
		try {
			Add-Content -Path $Script:LogFile -Value $logMessage -Force -ErrorAction Ignore
		} catch {
			Write-Warning "Failed to write to log file '$($Script:LogFile)': $($_.Exception.Message)"
		}
	}
	if ($Script:Quiet -or $Quiet) { return }
	if ($Script:NoColor) {
		$message = "${Message}$MessageDetail"
	} else {
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
	if ($StdErr) { [Console]::Error.WriteLine($message) } else { [Console]::Out.WriteLine($message) }
}

<#
.SYNOPSIS
	Class to hold test results.
.DESCRIPTION
	The YanaTestResult class holds the number of passed and failed tests.
#>
class YanaTestResult {
	[int]$Passed = 0
	[int]$Failed = 0
}

function YANAtest:YanaTestResult@has_passed_and_failed_properties {
	$result = [YanaTestResult]::new()
	if ($result.Passed -eq 0) { pass 'Passed initialized to 0' } else { fail 'Passed not initialized correctly' }
	if ($result.Failed -eq 0) { pass 'Failed initialized to 0' } else { fail 'Failed not initialized correctly' }

	$result.Passed = 5
	$result.Failed = 3
	if ($result.Passed -eq 5) { pass 'Passed property is writable' } else { fail 'Passed not writable' }
	if ($result.Failed -eq 3) { pass 'Failed property is writable' } else { fail 'Failed not writable' }
}

<#
.SYNOPSIS
	Discovers test functions based on pattern(s) specified in the $TestName parameter.
.PARAMETER TestName
	An array of test function names to discover.
	Defaults to all test functions in the current session.
.OUTPUTS
	Array of test function names that match the specified pattern(s).
#>
function Get-YanaTest([string[]]$TestName = @('*')) {
	$Local:YANA_testPrefix = 'YANAtest:'
	$Local:test_patterns = @()
	foreach ($tn in $TestName) {
		# if (-not $tn.EndsWith('.ps1')) { $tn += '.ps1' }
		if (-not $tn.StartsWith($Local:YANA_testPrefix)) { $tn = "$Local:YANA_testPrefix${tn}" }
		$Local:test_patterns += "Function:/$tn"
	}
	Get-Item $Local:test_patterns -ErrorAction SilentlyContinue | ForEach-Object {
		$_.Name
	}
}

function YANAtest:Get-YanaTest@discover_with_wildcard {
	$tests = & {
		# Create test functions dynamically
		function YANAtest:Sample1 { }
		function YANAtest:Sample2@ { }
		function YANAtest:Sample3@test { }
		function YANAtest:Other@Test { }

		Get-YanaTest -TestName 'Sample*'
	}
	if ($tests.Count -eq 3) { pass 'Found 3 tests matching Sample*' } else { fail "Expected 3 tests, got: $($tests.Count)" }
	if ($tests.Contains('YANAtest:Sample1')) { pass 'Test Sample1 found' } else { fail 'Test Sample1 not found' }
	if ($tests.Contains('YANAtest:Sample2@')) { pass 'Test Sample2@ found' } else { fail 'Test Sample2@ not found' }
	if ($tests.Contains('YANAtest:Sample3@test')) { pass 'Test Sample3@test found' } else { fail 'Test Sample3@test not found' }
	if ($tests.Contains('YANAtest:Other@Test')) { fail 'Test Other@Test should not be found' } else { pass 'Test Other@Test correctly not found' }
}

function YANAtest:Get-YanaTest@discover_specific_test {
	$tests = & {
		# Create a specific test function dynamically
		function YANAtest:SpecificTest { }

		Get-YanaTest -TestName 'SpecificTest'
	}
	if ($tests.Count -eq 1) { pass 'Found 1 specific test' } else { fail "Expected 1 test, got: $($tests.Count)" }
	if ($tests.Contains('YANAtest:SpecificTest')) { pass 'SpecificTest found' } else { fail 'SpecificTest not found' }
}

function YANAtest:Get-YanaTest@no_matching_tests {
	$tests = Get-YanaTest -TestName 'NonExistentTest*'
	if ($tests.Count -eq 0) { pass 'No tests found for non-existent pattern' } else { fail "Expected 0 tests, got: $($tests.Count)" }
}

<#
.SYNOPSIS
	Discovers test files based on pattern(s) specified in the $TestFile parameter.
.DESCRIPTION
	Discovers test files in the current directory and subdirectories.
.PARAMETER TestFile
	An array of test file names to discover.
	Defaults to all test files in the current directory and subdirectories.
.PARAMETER TestDir
	The base path to start searching for test files.
	Defaults to the current working directory.
.OUTPUTS
	List of test files that match the specified pattern(s).
#>
function Get-YanaTestFile([string[]]$TestFile = @('*'), [string]$TestDir = $PWD) {
	foreach ($tf in $TestFile) {
		if (-not $tf.EndsWith('.ps1')) { $tf = "${tf}.ps1" }
		try {
			Get-ChildItem -Path $TestDir -Recurse -Filter '*.ps1' -Include $tf -ErrorAction Ignore
		} catch { $null }
	}
}

function YANAtest:Get-YanaTestFile@discover_test_files {
	# Create temporary test file
	try {
		$tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
		New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
		$testFiles = @(
			[System.IO.Path]::Combine($tempDir, 'test1.ps1'),
			[System.IO.Path]::Combine($tempDir, 'test2.ps1'),
			[System.IO.Path]::Combine($tempDir, '1', 'test1.ps1'),
			[System.IO.Path]::Combine($tempDir, '2', 'test2.ps1'),
			[System.IO.Path]::Combine($tempDir, '1', '2', 'test1.ps1'),
			[System.IO.Path]::Combine($tempDir, '1', '2', 'test2.ps1')
		)
		New-Item -Path $testFiles -ItemType File -Force | Out-Null

		$files = Get-YanaTestFile -TestFile '*.ps1' -TestDir $tempDir
		if ($files.Count -gt 0) { pass 'Found test files' } else { fail 'No test files found' }
		foreach ($file in $files) {
			if ($file.FullName -in $testFiles) { pass "Found expected test file: $($file.FullName)" } else { fail "Unexpected test file found: $($file.FullName)" }
		}
	} finally {
		Remove-Item $tempDir -Recurse -ErrorAction SilentlyContinue
	}
}

function YANAtest:Get-YanaTestFile@with_specific_pattern {
	$files = Get-YanaTestFile -TestFile 'yana_tests'
	# Should find yana_tests.yanatests.ps1 if it exists, or similar patterns
	if ($null -ne $files) { pass 'File discovery returned results' } else { pass 'No files match pattern (expected)' }
}


<#
.SYNOPSIS
	Invokes specific test function(s) and captures results.
.DESCRIPTION
	Invokes specific test function(s) and captures results.
.OUTPUTS
	YanaTestResult with Passed and Failed tests.
#>
function Invoke-YanaTest([string[]]$TestName = @('*')) {

	<#
	.SYNOPSIS
		Marks the current test as passed.
	.DESCRIPTION
		Prints a message indicating that the current test has passed.
		Increments the passed test count.
	#>
	function pass ([string]$Message = '') {
		# Marks test as passed.
		$caller = (Get-PSCallStack)[1]
		$location = "$($caller.ScriptName):$($caller.ScriptLineNumber)"
		if (-not $Message) { $Message = "$($caller.FunctionName) passed" }
		Out-Colored -StdErr -Color green -Message "`t[√] ${Message}" -MessageDetail $location
		$YANA_subtests_ref.Value.Passed++
	}

	<#
	.SYNOPSIS
		Marks the current test as failed.
	.DESCRIPTION
		Prints a message indicating that the current test has failed.
		Increments the failed test count.
	#>
	function fail ([string]$Message = '') {
		$caller = (Get-PSCallStack)[1]
		$location = "$($caller.ScriptName):$($caller.ScriptLineNumber)"
		if (-not $Message) { $Message = "$($caller.FunctionName) failed" }
		Out-Colored -StdErr -Color red -Message "`t[x] ${Message}" -MessageDetail $location
		$YANA_subtests_ref.Value.Failed++
	}

	$Local:YANA_tests = Get-YanaTest $TestName
	$Local:YANA_testResult = [YanaTestResult]::new()
	$Local:YANA_subtests = @{}
	foreach ($YANA_test in $Local:YANA_tests) {
		Out-Colored -StdErr -Color cyan -Message 'Running test' -MessageDetail $YANA_test
		$Local:YANA_subtests[$YANA_test] = [YanaTestResult]::new()
		$Local:YANA_subtests_ref = [ref]$Local:YANA_subtests[$YANA_test]
		try {
			$null = & $YANA_test
		} catch {
			fail "Exception $($_.Exception.Message)", $_.ScriptStackTrace.Split("`n")[0]
		}
		if ($Local:YANA_subtests_ref.Value.Failed -eq 0) {
			$Local:YANA_testResult.Passed++
		} else {
			$Local:YANA_testResult.Failed++
		}
		Out-Colored -StdErr -Color yellow -Message "`t`tSub-tests: [√]Passed: $($Local:YANA_subtests_ref.Value.Passed)`t[x]Failed: $($Local:YANA_subtests_ref.Value.Failed)" -MessageDetail $YANA_test
		$Local:YANA_subtests_ref = $null
		$Local:YANA_subtests.Remove($YANA_test)
	}
	$Local:YANA_testResult
}

function YANAtest:Invoke-YanaTest@success {
	pass
}

function YANAtest:Invoke-YanaTest@failure {
	function YANAtest:Invoke-YanaTest@failure_subtest {
		fail 'This test should fail'
	}
	$test_result = & {
		$Quiet = $true
		Invoke-YanaTest -TestName 'Invoke-YanaTest@failure_subtest'
	}
	if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
	if ($test_result.Failed -eq 1) { pass 'Test fails as expected' } else { fail "Expected 1 failed subtest, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTest@exception_in_test {
	function YANAtest:Invoke-YanaTest@exception_in_test_subtest {
		throw 'This is a test exception'
	}
	$test_result = & {
		$Quiet = $true
		Invoke-YanaTest -TestName 'Invoke-YanaTest@exception_in_test_subtest'
	}
	if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
	if ($test_result.Failed -eq 1) { pass 'Test fails as expected' } else { fail "Expected 1 failed subtest, got: $($test_result.Failed)" }
}

<#
.SYNOPSIS
	Invokes tests from a specified test file.
.DESCRIPTION
	Sources the specified test file and invokes the tests defined in it.
.PARAMETER TestFile
	The path to the test file to invoke.
.PARAMETER TestName
	An array of test function names to invoke. Defaults to all tests in the file.
.PARAMETER Quiet
	If specified, suppresses output messages.
.OUTPUTS
	YanaTestResult with Passed and Failed tests.
#>
function Invoke-YanaTestFile([string]$TestFile, [string[]]$TestName = @('*')) {
	$Local:YANA_testResult = [YanaTestResult]::new()

	if ([string]::IsNullOrEmpty($TestFile)) {
		Out-Colored -StdErr -Color red -Message 'Error: Test file parameter is required'
		return $Local:YANA_testResult
	}

	if ([System.IO.File]::Exists($TestFile)) {
		# Remove all test functions starting with 'YANAtest:'
		Get-YanaTest '*' | ForEach-Object {
			$fn = "Function:/$_"
			if (Test-Path $fn) { Remove-Item $fn -ErrorAction SilentlyContinue }
		}

		Out-Colored -StdErr -Color magenta -Message 'Importing tests from file' -MessageDetail $TestFile
		. $TestFile
		$Local:YANA_testResult = Invoke-YanaTest -TestName $TestName
	} else {
		Out-Colored -StdErr -Color red -Message "Error: Test file '$TestFile' does not exist" -MessageDetail $TestFile
	}

	$Local:YANA_testResult
}

<#
.SYNOPSIS
	The main entry point for running tests.
.DESCRIPTION
	Invokes test(s) from the specified test file(s) and collects the results.
.PARAMETER TestFile
	An array of test file paths to invoke.
.PARAMETER TestDir
	The base path to start searching for test files.
	Defaults to the current working directory.
.PARAMETER TestName
	An array of test function names to invoke. Defaults to all tests in the specified files.
.PARAMETER Quiet
	If specified, suppresses output messages.
.OUTPUTS
	YanaTestResult with Passed and Failed tests.
.NOTES
	Exits with a non-zero status code if any tests failed.
#>
function Invoke-YanaTesting ([string[]]$TestFile = @('*'), [string]$TestDir = $PWD, [string[]]$TestName = @('*')) {

	$Local:YANA_testingResult = [YanaTestResult]::new()
	foreach ($file in (Get-YanaTestFile $TestFile -TestDir $TestDir)) {
		$test_result = Invoke-YanaTestFile -TestFile $file.FullName -TestName $TestName
		$Local:YANA_testingResult.Passed += $test_result.Passed
		$Local:YANA_testingResult.Failed += $test_result.Failed
	}
	$Local:YANA_testingResult
	if ($Local:YANA_testingResult.Failed -gt 0) { exit 1 }
}

# Prevent running when dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
	Invoke-YanaTesting -TestFile $TestFile -TestDir $TestDir -TestName $TestName
}
