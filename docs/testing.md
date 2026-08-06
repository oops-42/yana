# YANA Testing Framework

YANA includes a lightweight built-in testing framework for PowerShell and Bash.
Tests live in `.yanatests.ps1` or `.yanatests.sh` files. They can be defined in the same script file with tested code or in separate `yanatests` files - up to your preference.

## Overview

YANA Testing Framework is assertion-based. Every test function prepares the environment and mocks, executes tests and collects the results, then calls `pass` or `fail` to record results.
The framework sources script files and discovers all test functions using the naming convention described below, executes them and outputs a summary.
Tests are standard PowerShell/Bash functions which safely call the tested functions and inspect their results and outputs.

You fully control what and how to test - no magic, no complex testing frameworks, no DSLs.

## Test File Conventions

- If you prefer or need to separate tests from code, put them into files named as `<script>.yanatests.ps1` or `<script>.yanatests.sh`.
- Dot-source the script under test at the top of your `yanatests` file:
=== "PowerShell (Windows)"
    ``` powershell
    . "$PSScriptRoot/myscript.ps1"
    ```
=== "Bash (Linux/macOS)"
    ``` bash
    . "${BASH_SOURCE[0]%/*}/myscript.sh"
    ```

## Test Function Naming

Test functions follow a strict naming convention `YANAtest:<function>[@<scenario>]`, where:

- `<function>` - the name of the function or feature being tested.
- `@<scenario>` - (optional) a short description of the specific case being tested.

=== "PowerShell (Windows)"

    ``` powershell
    function YANAtest:MyCommand { ... }
    function YANAtest:MyCommand@handles_empty_input { ... }
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    function YANAtest:my_command { ... }
    function YANAtest:my_command@handles_empty_input { ... }
    ```

## Writing Tests

Inside a test function, use `pass` and `fail` to record assertions.

=== "PowerShell (Windows)"

    ``` powershell
    function YANAtest:MyCommand@returns_expected_value {
        $result = MyCommand -Arg 'hello'
        if ($result -eq 'expected') {
            pass 'Returns expected value'
        } else {
            fail "Got unexpected value: $result"
        }
    }
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    function YANAtest:my_command@returns_expected_value {
        result=$(my_command hello)
        if [[ "$result" == "expected" ]]; then
            pass 'Returns expected value'
        else
            fail "Got unexpected value: $result"
        fi
    }
    ```

### `pass`

``` text
pass [<message>]
```

Records a successful assertion. If no message is provided, a default message is generated from the calling function name.
Prefer to provide a descriptive explanation of what is expected to have passed.

Each call to `pass` increments the sub-test passed count.

### `fail`

``` text
fail [<message>]
```

Records a failed assertion. If no message is provided, a default message is generated from the calling function name.
Prefer to provide a descriptive explanation of why the test failed, including expected and actual values.

Each call to `fail` increments the sub-test failed count. Execution of the test function continues after `fail` - it does not throw.

A test function is considered failed overall if it has at least one `fail` call. It is considered passed if it has zero `fail` calls (even if it has zero `pass` calls).

## Exceptions in Tests

If a test function throws an unhandled exception, it is caught by the runner and recorded as a failure.

=== "PowerShell (Windows)"

    You can test that an exception is thrown by wrapping code in `try/catch`.

    ``` powershell
    function YANAtest:MyCommand@throws_on_bad_input {
        try {
            MyCommand -Arg $null
            fail 'Expected exception but none was thrown'
        }
        catch {
            pass "Caught expected exception: $($_.Exception.Message)"
        }
    }
    ```

=== "Bash (Linux/macOS)"

    You can test that an exception is thrown by checking the command's exit status.

    ``` bash
    function YANAtest:my_command@throws_on_bad_input {
        if my_command "" 2>/dev/null; then
            fail 'Expected exception but none was thrown'
        else
            pass 'Caught expected exception'
        fi
    }
    ```

## Running Tests

Execute the `yana-test.ps1` or `yana-test.sh` script.

Every command-line argument uses a corresponding environment variable. If both are specified, the command-line argument takes precedence.

The process exits with code `1` if any tests fail, or `0` if all tests pass.

### Run all tests in the current directory tree

=== "PowerShell (Windows)"

    ``` powershell
    ./yana-test.ps1
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-test.sh
    ```

### Run all tests in a specified directory

Use `-testdir` or `YANA_TESTDIR` to specify the directory to search for test files. Wildcards are supported.

=== "PowerShell (Windows)"

    ``` powershell
    ./yana-test.ps1 -testdir './tests'
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-test.sh -testdir './tests'
    ```

### Run a specific test file

Use `-testfile` or `YANA_TESTFILE` to specify the test file to run. Wildcards are supported.

=== "PowerShell (Windows)"

    ``` powershell
    ./yana-test.ps1 -testfile './mymodule.yanatests.ps1'
    ./yana-test.ps1 -testfile './mymodule*'
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-test.sh -testfile './mymodule.yanatests.ps1'
    ./yana-test.sh -testfile './mymodule*'
    ```

### Run a specific test by name

Use `-testname` or `YANA_TESTNAME` to specify the test name to execute. Wildcards are supported.

=== "PowerShell (Windows)"

    ``` powershell
    ./yana-test.ps1 -testname 'MyCommand'
    ./yana-test.ps1 -testname 'MyCommand@*'
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-test.sh -testname 'MyCommand'
    ./yana-test.sh -testname 'MyCommand@*'
    ```

### Output test results to a log file

Use `-logfile` or `YANA_LOGFILE` to specify the log file for test results. If the file already exists, output is appended.

=== "PowerShell (Windows)"

    ``` powershell
    ./yana-test.ps1 -logfile './test_results.log'
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-test.sh -logfile './test_results.log'
    ```

### Suppress console output

Use `-quiet` or set `YANA_QUIET` environment variable to `true`. Only the final summary is printed. If `-logfile` is also specified, full output is written to the log file.

=== "PowerShell (Windows)"

    ``` powershell
    ./yana-test.ps1 -quiet
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-test.sh -quiet
    ```

### Suppress ANSI color codes

Use `-nocolor` or set `YANA_NOCOLOR` environment variable to `true`. This is useful when redirecting output to a log file or when running in environments that do not support ANSI color codes.

=== "PowerShell (Windows)"

    ``` powershell
    ./yana-test.ps1 -nocolor
    ```

=== "Bash (Linux/macOS)"

    ``` bash
    ./yana-test.sh -nocolor
    ```
