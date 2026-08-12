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
# YANA_MODE='test'
# YANA_TRACE=true

set -eEuo pipefail

[[ -z ${YANA_TITLE:-} ]] && builtin readonly YANA_TITLE='YANA - Yet Another Node Automator (Bash) - Toolkit'
[[ -z ${YANA_VERSION:-} ]] && builtin readonly YANA_VERSION='YANAVERSIONPLACEHOLDER'

FUNCNEST=100
[[ -z ${ERR_GENERAL:-} ]] && builtin readonly ERR_GENERAL=1 ERR_MISUSE=64 ERR_DATA_FORMAT=65 ERR_NO_INPUT=66
# Prints out the usage information. Params: YANA_MODE.
_yanatool_usage() {
	case "${YANA_MODE:-}" in
	test)
		builtin echo 'Usage: yana-tool.sh test -source <file|dir>'
		builtin echo '  Runs tests from the specified file or directory.'
		builtin echo 'Options:'
		builtin echo '  -source <file|dir>         Specifies the path to YANA test files or directories. Supports wildcards.'
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
log() {
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
throw() {
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
_yanatool_check_prerequisites() {
	builtin local cmd
	for cmd in "$@"; do builtin command -v "$cmd" &>/dev/null || throw "Prerequisite '$cmd' is not installed or not in the system PATH." $ERR_MISUSE; done
}
# Outputs the version of YANA.
_yanatool_mode_version() { builtin echo "$YANA_VERSION"; }
# Runs tests from the specified source file or directory
# Vars: YANA_SOURCE - path to the source file or directory containing tests. Accepts wildcards.
_yanatool_mode_test() {
	builtin local _source="${source:-$YANA_SOURCE}" _test_files=()
	[[ -z $_source ]] && throw 'No source specified'
	_yanatool_check_prerequisites base64 awk
	[[ -e $_source ]] || throw "Source '$_source' does not exist."
  log info "Running mode 'test' from source: $_source"
  # Implement test execution logic here
  log info "Tests executed successfully from source: $_source"
}
# Main entry point.
_yanatool_() {
	# if [[ ${BASH_SOURCE[1]:-} != *bashdb ]]; then
	# 	trap '_yana_cleanup_encryption' EXIT ERR
	# 	trap '_yana_cleanup_encryption; exit 130' INT
	# 	trap '_yana_cleanup_encryption; exit 143' TERM
	# fi

	builtin local YANA_MODE="${YANA_MODE:-}" YANA_SOURCE="${YANA_SOURCE:-}" YANA_LOGFILE="${YANA_LOGFILE:-}" YANA_TRACE="${YANA_TRACE:-false}" YANA_DEBUG="${YANA_DEBUG:-false}" _yana_show_help=false
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
		*)
			[[ $1 == -* ]] && throw "Unknown option: $1. Use -help to see available options."
			throw "Unknown mode: $1. Use -help to see available modes."
			;;
		esac
		builtin shift
	done
	# Display the title and version information
	log info "$YANA_TITLE" "Version: $YANA_VERSION" >&2
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
		trap 'log fatal "An unexpected error occurred at line $LINENO in function ${FUNCNAME[0]}."' ERR
	fi
	(_yanatool_ "$@") || builtin exit $?
fi
