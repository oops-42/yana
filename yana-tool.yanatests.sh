# This script contains tests for YANA Testing Framework.
# Use the tests below as examples of how to write your own tests for YANA.

# The tested script shall be sourced.
# . "${BASH_SOURCE[0]%/*}/yana-tool.sh"

function yanatest__yanatool_test_discover {
	function _yanatest_non_discoverable_test_function { :; }
	function yanatest_a_sample_test_function { :; }
	function yanatest_a_sample_test_function@with_scenario { :; }
	test_result=$(_yanatool_test_discover) || fail 'Failed to discover test function' 0 "$?"
	expected_output='yanatest_a_sample_test_function'
	[[ $test_result == *"$expected_output"* ]] || fail 'Should discover the test function' "$expected_output" "$test_result"
	expected_output='yanatest_a_sample_test_function@with_scenario'
	[[ $test_result == *"$expected_output"* ]] || fail 'Should discover the test function with scenario' "$expected_output" "$test_result"
	unexpected_output='_yanatest_non_discoverable_test_function'
	[[ $test_result != *"$unexpected_output"* ]] || fail 'Should not discover the non-discoverable test function' "$unexpected_output" "$test_result"
}

function yanatest_test@throw {
	function aaa {
		throw 'This is a test exception'
	}
	out=$(aaa) && fail 'Should return non-zero exit code'
	[[ $out == *'THROW: This is a test exception' ]] || fail 'Should return the correct error message' 'This is a test exception' "$out"
}

function yanatest_my_command@throws_on_bad_input {
	# shellcheck disable=SC2120
	function my_command {
		local arg="${1:-}"
		[[ -z $arg ]] && throw 'Argument cannot be null or empty.'
		echo "$arg"
	}
	output=$(my_command) && fail 'Should exit with non-zero code on null or empty input'
	expected_message='Argument cannot be null or empty.'
	[[ $output == *"THROW: $expected_message" ]] || fail 'Should throw an exception on null or empty input' "$expected_message" "$output"
	# fail
}
