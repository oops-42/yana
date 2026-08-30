#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# YANA - Yet Another Node Automator (Bash)
# ---------------------------------------------------------------------------

# Bash 4+ version check
if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]:-1}" -lt 4 ]; then
	echo 'Error: Bash 4.0 or higher is required.' >&2
	exit 1
fi

# YANA_SOURCE='examples/linux'
YANA_MODE='test'
# YANA_TRACE=true

set -eEuo pipefail

[[ -z ${YANA_TITLE:-} ]] && builtin readonly YANA_TITLE='YANA - Yet Another Node Automator - Toolkit (Bash)'
[[ -z ${YANA_VERSION:-} ]] && builtin readonly YANA_VERSION='YANAVERSIONPLACEHOLDER'

FUNCNEST=100
[[ -z ${ERR_GENERAL:-} ]] && builtin readonly ERR_GENERAL=1 ERR_MISUSE=64 ERR_DATA_FORMAT=65 ERR_NO_INPUT=66
# Prints out the usage information. Params: YANA_MODE.
function _yanatool_usage {
	case "${YANA_MODE:-}" in
	test)
		builtin echo 'Usage: yana-tool.sh test [-source <file|dir>]'
		builtin echo '  Runs tests from the specified file or directory.'
		builtin echo 'Options:'
		builtin echo '  -source <file|dir>         Specifies the path to YANA test files or directories. If not specified, defaults to the current directory.'
		;;
	version)
		builtin echo 'Usage: yana-tool.sh version'
		builtin echo '  Displays the version of YANA Toolkit.'
		;;
	*)
		builtin echo 'Usage: yana-tool.sh <general options> [mode] <mode options>'
		builtin echo 'Modes:'
		builtin echo '  version                    Displays the version of YANA Toolkit.'
		builtin echo '  test                       Runs tests from the specified files or directories.'
		;;
	esac
	builtin echo 'General Options:'
	builtin echo '  -help                      Displays this help message.'
	builtin echo '  -help <mode>               Displays help for the specified mode.'
	builtin echo '  -logfile <file>            Log file path. If not specified, logs are not written to a file.'
	builtin echo '  -json                      Outputs results in JSON format.'
	builtin echo 'Environment Variables:'
	builtin echo '  YANA_MODE=<mode>           Specifies the mode to run YANA Toolkit in.'
	# builtin echo '  YANA_SOURCE=<path|url>     Specifies the source of the YANA Module.'
	builtin echo '  YANA_LOGFILE=<file>        Specifies the log file path.'
	builtin echo '                             Example: YANA_PARAM_version=2.0 ./yana.sh apply -source ./module'
	builtin echo '  YANA_DEBUG=true            Enables debug logging.'
	builtin echo '  YANA_TRACE=true            Enables trace logging (implies debug logging).'
}

# Logs a colored message to the stderr.
# Takes care of logging to a file if $YANA_LOGFILE is specified.
# Param: 1 - level (trace, debug, info, ok, success, pass, skip, warn, fail, error, fatal)
# Param: 2 - message
# Var: YANA_TRACE - enable TRACE and DEBUG messages
# Var: YANA_DEBUG - enable DEBUG messages
# Var: YANA_LOGFILE - path to log file
function log {
	builtin local _level="${1^^}" _message="${2?Message argument is required}"
	[[ ${YANA_TRACE:-false} != true && $_level == TRACE ]] && return 0
	[[ ${YANA_DEBUG:-${YANA_TRACE:-false}} != true && $_level == DEBUG ]] && return 0
	builtin local _logMessage _color_code _reset_code
	if [[ -t 2 ]]; then
		case "$_level" in
		TRACE | DEBUG) _color_code='\033[0;90m' ;;       # Gray
		INFO) _color_code='\033[0;36m' ;;                # Cyan
		OK | SUCCESS | PASS) _color_code='\033[0;32m' ;; # Green
		SKIP) _color_code='\033[0;33m' ;;                # Yellow
		WARN) _color_code='\033[0;93m' ;;                # Bright Yellow
		FAIL | ERROR) _color_code='\033[0;91m' ;;        # Bright Red
		FATAL) _color_code='\033[0;31m' ;;               # Red
		*) _color_code='\033[0m' ;;                      # Default
		esac
		_reset_code='\033[0m'
	fi
	_logMessage="${_color_code}$(date -u +'%Y-%m-%dT%H:%M:%SZ')\t${_level}\t${_message}${_reset_code}"
	builtin echo -e "$_logMessage" >&2
	if [[ -n ${YANA_LOGFILE:-} ]]; then
		# shellcheck disable=SC2097,SC2098
		builtin echo -e "${_logMessage}" >>"$YANA_LOGFILE" || YANA_LOGFILE='' log error "Failed to write to log file '$YANA_LOGFILE'. Check permissions and available disk space."
	fi
}

# Throws an error message and exits the script with# the specified return code.
# Params: 1 - message, 2 - return code (optional, default: $ERR_GENERAL)
# Vars: message, rc
function throw {
	set +x
	builtin local _message="${1:-${message:-Halted}}"
	builtin local _rc="${2:-${rc:-$ERR_GENERAL}}"
	log fatal "$_message"
	builtin local _frame=0 _trace
	while true; do
		_trace=$(builtin caller $_frame | awk '{print $3 ":" $1 " (" $2 ") "}')
		[[ -z $_trace ]] && break
		log stack "$_trace"
		((_frame += 1))
	done
	builtin exit "$_rc"
}
# Tests if the required commands are available in the system PATH.
# Params: List of command names to check.
function _yanatool_check_prerequisites {
	builtin local cmd
	for cmd in "$@"; do builtin command -v "$cmd" &>/dev/null || throw "Prerequisite '$cmd' is not installed or not in the system PATH." $ERR_MISUSE; done
}

# Invokes a specific test function and captures results.
# Params:
#  $1 <test_function> - A test function name to invoke.
# Outputs: [YanaTestResult] with Passed and Failed tests.
function _yanatool_test_invoke_test_function {
	builtin local _test_fn="$1"
	[[ -z $_test_fn ]] && throw 'No test function specified to invoke.'
	log info "Invoking test function: $_test_fn"
	builtin local _rc=0
	(

		# Used by throw() and fail() to output the caller function name and line number.
		#shellcheck disable=SC2317
		function _caller_info {
			builtin caller 1 | awk '{print $3 ":" $1}'
		}

		# Marks the current test as failed.
		# Prints a message indicating that the current test has failed.
		# Increments the failed test count.
		# shellcheck disable=SC2317
		function fail {
			builtin local _message="${1:-}"
			builtin local _expected="${2:-}"
			builtin local _actual="${3:-}"
			log fail "Test failed: $_test_fn"
			log fail "\tCaller: $(_caller_info)"
			[[ "$#" -ge 1 ]] && log fail "\tMessage: $_message"
			[[ "$#" -ge 2 ]] && log fail "\tExpected: '${_expected}'"
			[[ "$#" -ge 3 ]] && log fail "\tGot: '${_actual}'"
			builtin exit 1
		}
		# Mocks a `throw` function for testing purposes.
		# shellcheck disable=SC2317,SC2034
		function throw {
			echo "THROW: ${1:-${message:-Halted}}"
			builtin exit "${2:-$ERR_GENERAL}"
		}
		# shellcheck disable=SC2086
		"$_test_fn"
	) || _rc=$?
	return "$_rc"
}
# Discovers test functions based prefixed with "yanatest_"
# Outputs: List of yanatest function names
function _yanatool_test_discover {
	# builtin declare -F | awk '{print $3}' | grep '^yanatest_' >&2
	builtin declare -F | awk '{print $3}' | grep '^yanatest_' || true
}
# Runs the tests from the specified test file.
# Params: 1 - test file to execute.
# Outputs: YanaTestResult object for each test executed.
function _yanatool_test_run_file {
	builtin local _test_file="$1"
	[[ -f $_test_file ]] || throw "Test file '$_test_file' does not exist."
	log debug 'Cleaning up previously defined test functions before executing the new test file.'
	for _test_func in $(_yanatool_test_discover); do
		unset -f "$_test_func"
	done
	log info "Executing tests from file: $_test_file"
	log info 'Importing tests from file' "$_test_file"
	builtin source "$_test_file" || {
		log error 'Failed to import test file' "$_test_file"
		# YanaTestResult
		builtin return 1
	}
	builtin local _test_func YANA_tests_passed=0 YANA_tests_failed=0
	for _test_func in $(_yanatool_test_discover); do
		builtin local _rc=0
		(_yanatool_test_invoke_test_function "$_test_func") || _rc=$?
		if [[ $_rc -eq 0 ]]; then
			log pass "Test passed: $_test_func"
			((YANA_tests_passed++))
			((YANA_test_total_passed++))
		else
			((YANA_tests_failed++))
			((YANA_test_total_failed++))
			if [[ -n "${YANA_FAILFAST:-}" ]]; then
				log fail 'Fail-fast is enabled. Stopping further test execution.'
				builtin exit "$_rc"
			fi
		fi
	done
	log info "$YANA_tests_passed test(s) passed from file: $_test_file"
	if [[ $YANA_tests_failed -gt 0 ]]; then
		log error "$YANA_tests_failed test(s) failed from file: $_test_file"
		if [[ -n "${YANA_FAILFAST:-}" ]]; then
			log error 'Fail-fast is enabled. Stopping further test execution.'
			builtin exit 1
		fi
		return 1
	fi
}
# Fetches the list of test files from the specified source.
# Vars: YANA_SOURCE - path to the test file or directory containing tests. If not specified, defaults to the current directory.
# Params: Ref to an array variable to store the test files.
# Outputs: Populates the specified array variable with the list of test files.
function _yanatool_get_test_files {
	builtin local _test_files_ref="$1"
	[[ -z $_test_files_ref ]] && throw 'No reference variable specified for test files.'
	_yanatool_check_prerequisites find
	builtin local -n _test_files="$_test_files_ref"
	_test_files=()
	if [[ -f $YANA_SOURCE ]]; then
		_test_files+=("$(realpath "$YANA_SOURCE")")
	elif [[ -d $YANA_SOURCE ]]; then
		# Searches for test files (*.yanatests.sh) in the specified directory and its subdirectories recursively.
		builtin readarray -t _test_files < <(find "$YANA_SOURCE" -type f -name '*.yanatests.sh' -exec realpath {} \; 2>/dev/null)
	fi
}
# Outputs the version of YANA.
function _yanatool_mode_version { builtin echo "$YANA_VERSION"; }
# Runs tests from the specified source file or directory
# Vars: YANA_SOURCE - path to the test file or directory containing tests.
function _yanatool_mode_test {
	_yanatool_check_prerequisites base64 awk
	log info "Running mode 'test' from source: $YANA_SOURCE"
	builtin local -a _yana_test_files
	_yanatool_get_test_files _yana_test_files

	builtin local _test_func YANA_test_total_passed=0 YANA_test_total_failed=0
	for _test_file in "${_yana_test_files[@]}"; do
		_yanatool_test_run_file "$_test_file"
	done
	log info "TOTAL PASSED: $YANA_test_total_passed"
	if [[ $YANA_test_total_failed -gt 0 ]]; then
		log fail "TOTAL FAILED: $YANA_test_total_failed"
		return 1
	fi
}
# Main entry point.
function _yanatool_main {
	# if [[ ${BASH_SOURCE[1]:-} != *bashdb ]]; then
	# 	trap '_yana_cleanup_encryption' EXIT ERR
	# 	trap '_yana_cleanup_encryption; exit 130' INT
	# 	trap '_yana_cleanup_encryption; exit 143' TERM
	# fi

	builtin local YANA_MODE="${YANA_MODE:-}"
	builtin local YANA_SOURCE="${YANA_SOURCE:-.}"
	builtin local YANA_LOGFILE="${YANA_LOGFILE:-}"
	builtin local YANA_TRACE="${YANA_TRACE:-false}"
	builtin local YANA_DEBUG="${YANA_DEBUG:-false}"
	builtin local YANA_FAILFAST="${YANA_FAILFAST:-}"
	builtin local _yana_show_help=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
		test | version) YANA_MODE="$1" ;;
		-source | --source)
			builtin shift
			[[ $# -ge 1 && $1 != -* ]] || throw 'Missing value for -source'
			YANA_SOURCE="$1"
			;;
		-logfile | --logfile)
			builtin shift
			[[ $# -ge 1 && $1 != -* ]] || throw 'Missing value for -logfile'
			YANA_LOGFILE="$1"
			;;
		-help | --help) _yana_show_help=true ;;
		-failfast | --failfast) YANA_FAILFAST=true ;;
		*)
			if [[ $1 == -* ]]; then
				log error "Unknown option: $1. Use -help to see available options."
			else
				log error "Unknown mode: $1. Use -help to see available modes."
			fi
			builtin exit "$ERR_MISUSE"
			;;
		esac
		builtin shift
	done
	# Display the title and version information
	log info "$YANA_TITLE | Version: $YANA_VERSION" >&2
	if [[ $_yana_show_help == true ]]; then
		_yanatool_usage
		builtin return 0
	fi
	[[ -z $YANA_MODE ]] && throw 'No mode specified. Use -help to see available modes.'
	_yanatool_mode_"$YANA_MODE"
}
if [[ -z ${BASH_SOURCE[1]:-} ]] || [[ ${BASH_SOURCE[1]:-} == *bashdb ]]; then
	# Proceed with the script execution only if it is executed directly or under bashdb.
	if [[ ${BASH_SOURCE[1]:-} != *bashdb ]]; then
		trap 'throw "An unexpected error occurred at line $LINENO in function ${FUNCNAME[0]}."' ERR
	fi
	(_yanatool_main "$@") || builtin exit $?
fi
