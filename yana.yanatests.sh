# This script contains tests for YANA.

. "${BASH_SOURCE[0]%/*}/yana.sh"

function YANAtest:invoke_yana@no_args {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana 2>&1) || _rc=$?
	if [[ $_rc -eq 1 ]]; then
		pass 'should return 1 when invoked with no mode'
	else
		fail "should return 1 when invoked with no mode, got: $_rc"
	fi
	if [[ $test_result == *'Error: No mode specified. Use -help to see available modes.'* ]]; then
		pass 'should print error message when invoked with no mode'
	else
		fail "should print error message when invoked with no mode, got: $test_result"
	fi
}

function YANAtest:invoke_yana@unknown_mode {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana invalid_mode 2>&1) || _rc=$?
	if [[ $_rc -eq 1 ]]; then
		pass 'should return 1 when invoked with unknown mode'
	else
		fail "should return 1 when invoked with unknown mode, got: $_rc"
	fi
	if [[ $test_result == *'Error: Unknown mode: invalid_mode. Use -help to see available modes.'* ]]; then
		pass 'should print error message when invoked with unknown mode'
	else
		fail "should print error message when invoked with unknown mode, got: $test_result"
	fi
}

function YANAtest:invoke_yana@unknown_option {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana -invalid_option 2>&1) || _rc=$?
	if [[ $_rc -eq 1 ]]; then
		pass 'should return 1 when invoked with unknown option'
	else
		fail "should return 1 when invoked with unknown option, got: $_rc"
	fi
	if [[ $test_result == *'Error: Unknown option: -invalid_option. Use -help to see available options.'* ]]; then
		pass 'should print error message when invoked with unknown option'
	else
		fail "should print error message when invoked with unknown option, got: $test_result"
	fi
}

function YANAtest:invoke_yana@help {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana -help 2>&1) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with -help'
	else
		fail "should return 0 when invoked with -help, got: $_rc"
	fi
	if [[ $test_result == *'Usage: yana.sh <general options> [mode] <mode options>'* ]]; then
		pass 'should print general usage information when invoked with -help'
	else
		fail "should print general usage information when invoked with -help, got: $test_result"
	fi
}

function YANAtest:invoke_yana@help_mode_apply {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana -help apply 2>&1) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with -help apply'
	else
		fail "should return 0 when invoked with -help apply, got: $_rc"
	fi
	if [[ $test_result == *'Usage: yana.sh apply '* ]]; then
		pass 'should print usage information for apply mode when invoked with -help apply'
	else
		fail "should print usage information for apply mode when invoked with -help apply, got: $test_result"
	fi
}

function YANAtest:invoke_yana@help_mode_verify {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana -help verify 2>&1) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with -help verify'
	else
		fail "should return 0 when invoked with -help verify, got: $_rc"
	fi
	if [[ $test_result == *'Usage: yana.sh verify '* ]]; then
		pass 'should print usage information for verify mode when invoked with -help verify'
	else
		fail "should print usage information for verify mode when invoked with -help verify, got: $test_result"
	fi
}

function YANAtest:invoke_yana@help_mode_fetch {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana -help fetch 2>&1) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with -help fetch'
	else
		fail "should return 0 when invoked with -help fetch, got: $_rc"
	fi
	if [[ $test_result == *'Usage: yana.sh fetch '* ]]; then
		pass 'should print usage information for fetch mode when invoked with -help fetch'
	else
		fail "should print usage information for fetch mode when invoked with -help fetch, got: $test_result"
	fi
}

function YANAtest:invoke_yana@mode_apply {
	local _rc test_result
	_rc=0
	test_result=$(
		function invoke_yana_apply() {
			builtin echo "apply: '$1'"
		}

		YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana apply -source 'qwerty' 2>/dev/null
	) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with apply'
	else
		fail "should return 0 when invoked with apply, got: $_rc"
	fi
	if [[ $test_result == "apply: 'qwerty'" ]]; then
		pass 'should print apply mode invocation message'
	else
		fail "should print apply mode invocation message, got: $test_result"
	fi
}

function YANAtest:invoke_yana@mode_apply_env {
	local _rc test_result
	_rc=0
	test_result=$(
		function invoke_yana_apply() {
			builtin echo "apply: '$1'"
		}

		YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' YANA_MODE=apply YANA_SOURCE='qwerty' invoke_yana 2>/dev/null
	) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with apply'
	else
		fail "should return 0 when invoked with apply, got: $_rc"
	fi
	if [[ $test_result == "apply: 'qwerty'" ]]; then
		pass 'should print apply mode invocation message'
	else
		fail "should print apply mode invocation message, got: $test_result"
	fi
}

function YANAtest:invoke_yana@mode_apply_no_source {
	local _rc test_result
	_rc=0
	test_result=$(
		function invoke_yana_apply() {
			builtin echo "apply: '$1'"
		}

		YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana apply 2>/dev/null
	) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with apply'
	else
		fail "should return 0 when invoked with apply, got: $_rc"
	fi
	if [[ $test_result == "apply: ''" ]]; then
		pass 'should print apply mode invocation message'
	else
		fail "should print apply mode invocation message, got: $test_result"
	fi
}

function YANAtest:invoke_yana@mode_fetch {
	local _rc test_result
	_rc=0
	test_result=$(
		function invoke_yana_fetch() {
			builtin echo "fetch: '$1'"
		}

		YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana fetch -source 'qwerty' 2>/dev/null
	) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with fetch'
	else
		fail "should return 0 when invoked with fetch, got: $_rc"
	fi
	if [[ $test_result == "fetch: 'qwerty'" ]]; then
		pass 'should print fetch mode invocation message'
	else
		fail "should print fetch mode invocation message, got: $test_result"
	fi
}

function YANAtest:invoke_yana@mode_verify {
	local _rc test_result
	_rc=0
	test_result=$(
		function invoke_yana_verify() {
			builtin echo "verify: '$1'"
		}

		YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' YANA_QUIET='' YANA_NOCOLOR='' invoke_yana verify -source 'qwerty' 2>/dev/null
	) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with verify'
	else
		fail "should return 0 when invoked with verify, got: $_rc"
	fi
	if [[ $test_result == "verify: 'qwerty'" ]]; then
		pass 'should print verify mode invocation message'
	else
		fail "should print verify mode invocation message, got: $test_result"
	fi
}
