# This script contains tests for YANA.

. "${BASH_SOURCE[0]%/*}/yana.sh"

function YANAtest:_yana_@no_args {
	local _rc test_result
	_rc=0
	test_result=$(
		throw() {
			builtin echo "Thrown: $1"
			builtin exit 1
		}
		YANA_MODE='' YANA_LOGFILE='' _yana_ 2>/dev/null) || _rc=$?
	if [[ $_rc -eq 1 ]]; then
		pass 'should return 1 when invoked with no mode'
	else
		fail "should return 1 when invoked with no mode, got: $_rc"
	fi
	if [[ $test_result == 'Thrown: No mode specified. Use -help to see available modes.' ]]; then
		pass 'should print error message when invoked with no mode'
	else
		fail "should print error message when invoked with no mode, got: $test_result"
	fi
}

function YANAtest:_yana_@unknown_mode {
	local _rc test_result
	_rc=0
	test_result=$(
				throw() {
			builtin echo "Thrown: $1"
			builtin exit 1
		}
		YANA_MODE='' YANA_LOGFILE='' _yana_ invalid_mode 2>&1) || _rc=$?
	if [[ $_rc -eq 1 ]]; then
		pass 'should return 1 when invoked with unknown mode'
	else
		fail "should return 1 when invoked with unknown mode, got: $_rc"
	fi
	if [[ $test_result == 'Thrown: Unknown mode: invalid_mode. Use -help to see available modes.' ]]; then
		pass 'should throw error message when invoked with unknown mode'
	else
		fail "should throw error message when invoked with unknown mode, got: $test_result"
	fi
}

function YANAtest:_yana_@unknown_option {
	local _rc test_result
	_rc=0
	test_result=$(
		throw() {
			builtin echo "Thrown: $1"
			builtin exit 1
		}
		YANA_LOGFILE='' _yana_ -invalid_option) || _rc=$?
	if [[ $_rc -eq 1 ]]; then
		pass 'should return 1 when invoked with unknown option'
	else
		fail "should return 1 when invoked with unknown option, got: $_rc"
	fi
	if [[ $test_result == 'Thrown: Unknown option: -invalid_option. Use -help to see available options.' ]]; then
		pass 'should throw error message when invoked with unknown option'
	else
		fail "should throw error message when invoked with unknown option, got: $test_result"
	fi
}

function YANAtest:_yana_@help {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' _yana_ -help 2>&1) || _rc=$?
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

function YANAtest:_yana_@help_mode_apply {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' _yana_ -help apply 2>&1) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with -help apply'
	else
		fail "should return 0 when invoked with -help apply, got: $_rc"
	fi
	if [[ $test_result == *'Usage: yana.sh apply -source <path|url> [-routine <name>]'* ]]; then
		pass 'should print usage information for apply mode when invoked with -help apply'
	else
		fail "should print usage information for apply mode when invoked with -help apply, got: $test_result"
	fi
}

function YANAtest:_yana_@help_mode_verify {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' _yana_ -help verify 2>&1) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with -help verify'
	else
		fail "should return 0 when invoked with -help verify, got: $_rc"
	fi
	if [[ $test_result == *'Usage: yana.sh verify -source <path|url> [-routine <name>]'* ]]; then
		pass 'should print usage information for verify mode when invoked with -help verify'
	else
		fail "should print usage information for verify mode when invoked with -help verify, got: $test_result"
	fi
}

function YANAtest:_yana_@help_mode_fetch {
	local _rc test_result
	_rc=0
	test_result=$(YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' _yana_ -help fetch 2>&1) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with -help fetch'
	else
		fail "should return 0 when invoked with -help fetch, got: $_rc"
	fi
	if [[ $test_result == *'Usage: yana.sh fetch -source <path|url>'* ]]; then
		pass 'should print usage information for fetch mode when invoked with -help fetch'
	else
		fail "should print usage information for fetch mode when invoked with -help fetch, got: $test_result"
	fi
}

function YANAtest:_yana_@mode_apply {
	local _rc test_result
	_rc=0
	test_result=$(
		function _yana_mode_apply() {
			builtin echo "apply: '$YANA_SOURCE' '$YANA_ROUTINE'"
		}

		YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' _yana_ apply -source 'qwerty' -routine 'hello' 2>/dev/null
	) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with apply'
	else
		fail "should return 0 when invoked with apply, got: $_rc"
	fi
	if [[ $test_result == "apply: 'qwerty' 'hello'" ]]; then
		pass 'should print apply mode invocation message'
	else
		fail "should print apply mode invocation message, got: $test_result"
	fi
}

function YANAtest:_yana_@mode_apply_env {
	local _rc test_result
	_rc=0
	test_result=$(
		function _yana_mode_apply() {
			builtin echo "apply: '$YANA_SOURCE' '$YANA_ROUTINE'"
		}

		YANA_LOGFILE='' YANA_MODE=apply YANA_SOURCE='qwerty' YANA_ROUTINE='hello' _yana_ 2>/dev/null
	) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with apply'
	else
		fail "should return 0 when invoked with apply, got: $_rc"
	fi
	if [[ $test_result == "apply: 'qwerty' 'hello'" ]]; then
		pass 'should print apply mode invocation message'
	else
		fail "should print apply mode invocation message, got: $test_result"
	fi
}

function YANAtest:_yana_@mode_apply_no_source {
	local _rc test_result
	_rc=0
	test_result=$(
		# function _yana_mode_apply() {
		# 	builtin echo "apply: '$YANA_SOURCE' '$YANA_ROUTINE'"
		# }
		throw() {
			builtin echo "Thrown: $1"
			builtin exit 1
		}

		YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' _yana_ apply 2>/dev/null
	) || _rc=$?
	if [[ $_rc -eq 1 ]]; then
		pass 'should return 1 when invoked with apply and no source'
	else
		fail "should return 1 when invoked with apply and no source, got: $_rc"
	fi
	if [[ $test_result == 'Thrown: No source specified' ]]; then
		pass 'should throw an error when invoked with apply and no source'
	else
		fail "should throw an error when invoked with apply and no source, got: $test_result"
	fi
}

function YANAtest:_yana_@mode_fetch {
	local _rc test_result
	_rc=0
	test_result=$(
		function _yana_mode_fetch() {
			builtin echo "fetch: '$YANA_SOURCE'"
		}
		# log() {
		# 	builtin echo "log: $1"
		# }

		YANA_MODE='' YANA_SOURCE='' YANA_LOGFILE='' _yana_ fetch -source 'qwerty' 2>/dev/null
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

function YANAtest:_yana_@mode_verify {
	local _rc test_result
	_rc=0
	test_result=$(
		function _yana_mode_verify() {
			builtin echo "verify: '$YANA_SOURCE' '$YANA_ROUTINE'"
		}

		YANA_LOGFILE='' YANA_MODE='' YANA_SOURCE='' YANA_ROUTINE='' _yana_ verify -source qwerty -routine hello 2>/dev/null
	) || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		pass 'should return 0 when invoked with verify'
	else
		fail "should return 0 when invoked with verify, got: $_rc"
	fi
	if [[ $test_result == "verify: 'qwerty' 'hello'" ]]; then
		pass 'should print verify mode invocation message'
	else
		fail "should print verify mode invocation message, got: $test_result"
	fi
}
