# YANA Testing Framework (Yanatests)

YANA includes a super-simple and lightweight built-in testing framework (called Yanatests) for PowerShell and Bash.
Yanatests are used to validate the functionality of YANA Engine and Toolkit, as well as any scripts and modules built on top of it.

## Overview

Yanatests are standard PowerShell/Bash functions prefixed as `yanatest_`, which verify the behavior of the tested functions by safely calling them and inspecting their results and outputs.

Every yanatest does:

- Prepare the environment
- Define mock functions and variables.
- Execute the tested functions and collect the results.
- Compare the results with the expected values.
- If the comparison fails, calls `fail` to record the unexpected behavior.

You implement and control what and how to test - no magic, no complex testing frameworks, no DSLs.

## Test File Conventions

- Test functions live in files named as `<script>.yanatests.ps1` or `<script>.yanatests.sh`.
- Tested script shall be dot-sourced at the top of your `yanatests` file:

=== "PowerShell (Windows)"

    ``` powershell
    . "$PSScriptRoot\myscript.ps1"
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    . "${BASH_SOURCE[0]%/*}/myscript.sh"
    ```

## Test Function Naming

Yanatest functions follow a naming convention `yanatest_<tested_function>[@<scenario>]`, where:

- `<function>` - the name of the function or feature being tested.
- `@<scenario>` - (optional) a short description of the specific case being tested.

``` bash
function yanatest_my_command { ... }
function yanatest_my_command@handles_empty_input { ... }
```

## Writing Tests

YANA Testing Framework provides a single function `fail` that can be used to describe the expected behavior and record results if the condition is not met.

Syntax:

``` text
fail <message> [<expected>] [<actual>]
```

You evaluate the condition yourself and call `fail` with a message if the condition is not met. Additionally, you can provide expected and actual values to make it easier to understand the expected behavior and failure.

Example:

=== "PowerShell (Windows)"

    Tested function:

    ``` powershell
    function MyCommand([string]$Arg) {
        $Arg.ToUpper()
    }
    ```

    Yanatest function:

    ``` powershell
    function yanatest_MyCommand {
        $expected = 'HELLO'
        $actual = MyCommand -Arg 'hello'
        if ($expected -ne $actual) { fail 'Should return upper case value' $expected $actual }
    }
    ```

=== "Bash (Linux/macOS)"

    Tested function:

    ``` bash
    function my_command {
        local arg="${1:-}"
        echo "$arg" | tr '[:lower:]' '[:upper:]'
    }
    ```

    Yanatest function:

    ``` bash
    function yanatest_my_command {
        expected='HELLO' # Define the expected value
        _rc=0 # We will use this variable to capture the return code of the command
        actual=$(my_command hello) || _rc=$? # Capture the return code of the command
        [[ $_rc -eq 0 ]] || fail 'Should return zero exit code'  0 "$_rc"
        [[ "$expected" != "$actual" ]] && fail 'Should return upper case value' "$expected" "$actual"
    }
    ```

This will output a failure message if the result is not as expected:

``` text
[FAIL]  Should return upper case value.
        Expected: 'HELLO'
        Got: 'hello'
```

### Testing Terminating Exceptions

YANA Engine and Toolkit provide a unified way to handle terminating exceptions using `throw`.

If a tested function throws an unhandled terminating exception, it is caught by the runner and recorded as a failure.

To test that a function throws an exception, below are examples of how to do it:

=== "PowerShell (Windows)"

    Tested function:

    ``` powershell
    function MyCommand([string]$Arg) {
        if ([String]::IsNullOrEmpty($Arg)) {
            throw 'Argument cannot be null or empty.'
        }
        $Arg.ToUpper()
    }
    ```

    You can test that an exception is thrown by wrapping code in `try/catch`.

    ```powershell
    function yanatest_my_command@throws_on_bad_input {
        try {
            MyCommand -Arg $null
            fail 'Should throw an exception on null input'
        }
        catch {
            $expectedMessage = 'Argument cannot be null or empty.'
            if ($expectedMessage -ne $_.Exception.Message) {
                fail 'Should throw an exception on null input' $expectedMessage $_.Exception.Message
            }
        }
    }
    ```

=== "Bash (Linux/macOS)"

    Tested function:

    ``` bash
    function my_command {
        local arg="${1:-}"
        [[ -z "$arg" ]] && throw 'Argument cannot be null or empty.'
        echo "$arg"
    }
    ```

    You can test that an exception is thrown by mocking the `throw` function and checking the command's exit status.

    ``` bash
    function yanatest_my_command@throws_on_bad_input {
        function throw {
            echo "throw: ${1:-}"
            exit "${2:-1}"
        }
        _rc=0
        output="$(my_command)" || _rc=$?
        [[ $_rc -eq 0 ]] && fail 'Should throw an exception on null input'
        expected_message='Argument cannot be null or empty.'
        [[ "$output" == *"throw: $expected_message" ]] || fail 'Should throw an exception on null input' "$expected_message" "$output"
    }
    ```

## Running Tests

Execute the `yana-tool` with `test` mode. You can also define the `YANA_MODE` environment variable to `test` and run the tool without arguments.

Every command-line argument has a corresponding environment variable. If both are specified, the command-line argument takes precedence.

The process exits with code `1` if any tests fail, or `0` if all tests pass.

### Run all tests in the current directory tree

=== "PowerShell (Windows)"

    ``` powershell
    .\yana-tool.ps1 test
    ```

    ``` powershell
    $env:YANA_MODE = 'test'
    .\yana-tool.ps1
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-tool.sh test
    ```

    ``` bash
    YANA_MODE='test' ./yana-tool.sh
    ```

### Run all tests in a specified directory OR a specific test file

Use `-source` argument or `YANA_SOURCE` environment variable to specify the directory to search for test files or a specific test file.

=== "PowerShell (Windows)"

    ``` powershell
    .\yana-tool.ps1 test -source './tests/mymodule.yanatests.ps1'
    .\yana-tool.ps1 test -source './tests'
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-tool.sh test -source './tests/mymodule.yanatests.sh'
    ./yana-tool.sh test -source './tests'
    ```

### Run a specific test file

Use `-source` argument or `YANA_SOURCE` environment variable to specify the directory to search for test files.
If a directory is specified, all test files in that directory

=== "PowerShell (Windows)"

    ``` powershell
    .\yana-tool.ps1 test -testfile '.\tests\mymodule.yanatests.ps1' # Run a specific test file
    .\yana-tool.ps1 test -testfile '.\tests\' # Run all test files in a specific directory
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-tool.sh test -source './tests/mymodule.yanatests.ps1' # Run a specific test file
    ./yana-tool.sh test -source './tests/' # Run all test files in a specific directory
    ```

### Output test results to a log file

Use `-logfile` argument or `YANA_LOGFILE` environment variable to specify the log file for test results. If the file already exists, output is appended.

=== "PowerShell (Windows)"

    ``` powershell
    .\yana-tool.ps1 test -logfile '.\test_results.log'
    ```

    OR

    ``` powershell
    $env:YANA_MODE = 'test'
    $env:YANA_LOGFILE = '.\test_results.log'
    .\yana-tool.ps1
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-tool.sh test -logfile './test_results.log'
    ```

    OR

    ``` bash
    export YANA_MODE='test'
    export YANA_LOGFILE='./test_results.log'
    ./yana-tool.sh
    ```

### Fail on first test failure

Use `-failfast` argument or `YANA_FAILFAST` environment variable to stop execution on the first test failure.

=== "PowerShell (Windows)"

    ``` powershell
    .\yana-tool.ps1 test -failfast
    ```

    OR

    ``` powershell
    $env:YANA_MODE = 'test'
    $env:YANA_FAILFAST = 'true'
    .\yana-tool.ps1
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-tool.sh test -failfast
    ```

    OR

    ``` bash
    export YANA_MODE='test'
    export YANA_FAILFAST='true'
    ./yana-tool.sh
    ```
