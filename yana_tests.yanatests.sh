# This script contains example tests for YANA Testing Framework.
# Many tests are included into the YANA Testing Framework.
# Below are some additional tests provided as a demonstration.

# The tested script shall be sourced.
# In this case we do not source it since we are running in yana_tests.sh context.
# . "${BASH_SOURCE[0]%/*}/yana_tests.sh"

YANAtest:invoke_yana_test_function@exception() {
	# Demonstrates catching command failures inside a test function.
	if ! (exit 1); then
		pass 'Caught expected failure'
	else
		fail 'This should not be reached'
	fi
}

YANAtest:invoke_yana_test_function@missing_test_function() {
	# Demonstrates how to use mock functions to capture output

	# Mock buffer to capture output from out_colored_stderr
	local -a mock_buffer=()
	# Save the original out_colored_stderr function so we can restore it later
	local _orig_out_colored_stderr
	_orig_out_colored_stderr=$(declare -f out_colored_stderr)
	# Override out_colored_stderr to capture its output into mock_buffer
	out_colored_stderr() {
		mock_buffer+=("$*")
	}
	# Call the test function and capture its exit code
	local _rc=0
	invoke_yana_test_function 'NonExistentTestFunction' || _rc=$?

	# Restore the original out_colored_stderr function
	eval "$_orig_out_colored_stderr"

	# Perform assertions on the captured output and exit code
	if [[ $_rc -ne 0 ]]; then pass 'Test fails as expected'; else fail "Expected non-zero exit for missing test function, got: $_rc"; fi
	if [[ ${#mock_buffer[@]} -eq 1 ]]; then pass 'Error is displayed'; else fail "Expected 1 error output, got: ${#mock_buffer[@]}"; fi
	if [[ ${mock_buffer[0]} == "red "* ]]; then pass 'Error color is red'; else fail "Expected red color, got: ${mock_buffer[0]}"; fi
	if grep -q 'NonExistentTestFunction' <<<"${mock_buffer[0]}"; then pass 'Error message contains function name'; else fail "Error message missing function name: ${mock_buffer[0]}"; fi
}

YANAtest:invoke_yana_test_function@with_test_function() {
	# Demonstrates how to invoke a test function and check its output and exit code.

	local test_fn='YANAtest:_with_test_function_subtest'
	YANAtest:_with_test_function_subtest() { pass 'This test should pass'; }

	# Mock buffer to capture output from out_colored_stderr
	local -a mock_buffer=()
	# Save the original out_colored_stderr function so we can restore it later
	local _orig_out_colored_stderr
	_orig_out_colored_stderr=$(declare -f out_colored_stderr)
	# Override out_colored_stderr to capture its output into mock_buffer
	out_colored_stderr() {
		mock_buffer+=("$*")
	}
	# Call the test function and capture its exit code
	local _rc=0
	invoke_yana_test_function "$test_fn" || _rc=$?

	# Restore the original out_colored_stderr function
	eval "$_orig_out_colored_stderr"
	# Clean up the test function to avoid polluting the namespace
	builtin unset -f "$test_fn" 2>/dev/null

	# Perform assertions on the captured output and exit code
	if [[ $_rc -eq 0 ]]; then pass 'Test passes as expected'; else fail "Expected zero exit for passing test, got: $_rc"; fi
	if [[ ${#mock_buffer[@]} -gt 0 ]]; then pass 'Output is generated'; else fail 'Expected output to be generated'; fi
	if [[ ${mock_buffer[0]} == "cyan "* ]]; then pass 'Output color is cyan'; else fail "Expected cyan color, got: ${mock_buffer[0]}"; fi
	if grep -q 'Running test function' <<<"${mock_buffer[0]}"; then pass 'Output contains running message'; else fail "Expected 'Running test function' in output, got: ${mock_buffer[0]}"; fi
	if grep -q "$test_fn" <<<"${mock_buffer[0]}"; then pass 'Output contains test function name'; else fail "Expected function name in output: ${mock_buffer[0]}"; fi
}

YANAtest:invoke_yana_test_file@with_valid_content() {
	# Demonstrates how to:
  # - create a temporary test file
  # - use mock functions
  # - override the behavior of tested function using variable overrides

	local tempFile
	tempFile=$(mktemp --suffix='.sh')
	cat >"$tempFile" <<'EOF'
YANAtest:TestFunction1@pass() {
	pass 'Test passed'
}
YANAtest:TestFunction2@fail() {
	fail 'Test failed'
}
EOF

	local result token passed failed
	result=$(
		# Mock the get_yana_test function to return predefined test results
		get_yana_test() {
			echo 'YANAtest:TestFunction1@pass'
			echo 'YANAtest:TestFunction2@fail'
		}
		# Override variables to suppress output and logging
		_YANA_QUIET=true
		_YANA_LOGFILE=''
		_YANA_TESTNAME='*'
		invoke_yana_test_file "$tempFile" 2>/dev/null
	)
	rm -f "$tempFile"

	token=$(grep "^${YANA_TEST_RESULT}:" <<<"$result")
	passed=${token#*:}
	failed=${passed#*_}
	passed=${passed%_*}
	if [[ $passed -eq 1 ]]; then pass 'Passing test in file counted correctly'; else fail "Expected 1 passed, got: $passed"; fi
	if [[ $failed -eq 1 ]]; then pass 'Failing test in file counted correctly'; else fail "Expected 1 failed, got: $failed"; fi
}
