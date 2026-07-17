#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# YANA - Yet Another Node Automator (Bash)
# ---------------------------------------------------------------------------

# Bash 4+ version check
if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]:-1}" -lt 4 ]; then
	echo 'Error: Bash 4.0 or higher is required.' >&2
	exit 1
fi

[[ -z ${YANA_TITLE:-} ]] && builtin readonly YANA_TITLE='YANA - Yet Another Node Automator (Bash)'
[[ -z ${YANA_VERSION:-} ]] && builtin readonly YANA_VERSION='YANAVERSIONPLACEHOLDER'

# Prepares colored text for output to the console.
# Takes care of logging to a file if $YANA_LOGFILE is specified.
# If $YANA_QUIET is specified, suppresses output.
# If $YANA_NOCOLOR is specified, disables colored output.
function out_colored() {
	builtin local Color="${1:-${Color:-}}"
	builtin local Message="${2:-${Message:-}}"
	builtin local MessageDetail="${3:-${MessageDetail:-}}"

	[[ -n $Message ]] && Message="$Message "
	if [[ -n $YANA_LOGFILE ]]; then
		builtin local logMessage
		logMessage="[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] ${Message}${MessageDetail}"
		builtin echo -e "${logMessage}" >>"$YANA_LOGFILE" || {
			builtin local _logfile="$YANA_LOGFILE"
			YANA_LOGFILE=""
			out_colored red 'Error: Failed to write to log file' "$_logfile" >&2
		}
	fi

	[[ -n $YANA_QUIET ]] && builtin return
	if [[ -n $YANA_NOCOLOR ]]; then
		Message="${Message}${MessageDetail}"
	else
		builtin local ColorCode
		case "$Color" in
		black) ColorCode=30 ;;
		red) ColorCode=31 ;;
		green) ColorCode=32 ;;
		yellow) ColorCode=33 ;;
		blue) ColorCode=34 ;;
		magenta) ColorCode=35 ;;
		cyan) ColorCode=36 ;;
		white) ColorCode=37 ;;
		*) ColorCode=0 ;;
		esac
		Message="\e[${ColorCode}m${Message}\e[2m${MessageDetail}\e[0m"
	fi
	builtin echo "$Message"
}
# Outputs colored text to the standard output.
function out_colored_stdout() {
	output="$(out_colored "$@")"
	[[ -n $output ]] && builtin echo -e "$output" >&1
}
# Outputs colored text to the standard error.
function out_colored_stderr() {
	output="$(out_colored "$@")"
	[[ -n $output ]] && builtin echo -e "$output" >&2
}
# Throws an error message and exits the script with exit code 1.
function throw() {
	builtin local Message="${1:-${Message:-}}"
	builtin local MessageDetail="${2:-${MessageDetail:-}}"
	out_colored_stderr red "Error: $Message" "$MessageDetail"
	builtin exit 1
}

function invoke_yana_fetch() {
	builtin local source="${1:-}"
	[[ -n $source ]] || throw 'Missing source for fetch'
	out_colored_stderr cyan "Fetching YANA Module" "$source"
	# Implement the fetch logic here
}

function invoke_yana_apply() {
	builtin local source="${1:-}"
	[[ -n $source ]] || throw 'Missing source for apply'
	out_colored_stderr cyan "Applying YANA Module" "$source"
	# Implement the apply logic here
}

function invoke_yana_verify() {
	builtin local source="${1:-}"
	[[ -n $source ]] || throw 'Missing source for verify'
	out_colored_stderr cyan "Verifying YANA Module" "$source"
	# Implement the verify logic here
}

function out_help() {
	builtin local mode="${1:-}"
	case "$mode" in
	apply)
		builtin echo "Usage: yana.sh apply <mode options>"
		builtin echo "  Applies the specified YANA Module."

		builtin echo "Options:"
		builtin echo "  -source <path|url>         Specifies the source of YANA Module to apply."
		;;
	verify)
		builtin echo "Usage: yana.sh verify <mode options>"
		builtin echo "  Compares the state of the system with the state specified by the YANA Module without making any changes."

		builtin echo "Options:"
		builtin echo "  -source <path|url>         Specifies the source of YANA Module to verify."
		;;
	fetch)
		builtin echo "Usage: yana.sh fetch <mode options>"
		builtin echo "  Fetches the specified YANA Module."

		builtin echo "Options:"
		builtin echo "  -source <path|url>         Specifies the source of YANA Module to fetch."
		;;
	*)
		builtin echo "Usage: yana.sh <general options> [mode] <mode options>"
		builtin echo
		builtin echo "Modes:"
		builtin echo "  apply                      Applies the specified YANA Module."
		builtin echo "  verify                     Compares the state of the system with the state specified by the YANA Module without making any changes."
		builtin echo "  fetch                      Fetches the specified YANA Module."
		;;
	esac
	builtin echo
	builtin echo "General Options:"
	builtin echo "  -version                   Displays the version of YANA."
	builtin echo "  -help                      Displays this help message."
	builtin echo "  -help <mode>               Displays help for the specified mode."
	builtin echo "  -logfile <file>            Log file path. Uses YANA_LOGFILE environment variable. If not specified, logs are not written to a file."
	builtin echo "  -quiet                     Suppress output to the console. Uses YANA_QUIET environment variable."
	builtin echo "  -nocolor                   Disable colored output. Uses YANA_NOCOLOR environment variable."
}

# Parse command-line arguments and set global variables accordingly.
function parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		apply | verify | fetch | -version)
			YANA_MODE="$1"
			;;
		-source)
			builtin shift
			[[ $# -ge 1 && $1 != -* ]] || throw 'Missing value for -source'
			YANA_SOURCE="$1"
			;;
		-logfile)
			builtin shift
			[[ $# -ge 1 && $1 != -* ]] || throw 'Missing value for -logfile'
			YANA_LOGFILE="$1"
			;;
		-quiet)
			YANA_QUIET=true
			;;
		-nocolor)
			YANA_NOCOLOR=true
			;;
		-help)
			YANA_SHOW_HELP=true
			;;
		*)
			if [[ "$1" == -* ]]; then
				throw "Unknown option: $1. Use -help to see available options."
			fi
			throw "Unknown mode: $1. Use -help to see available modes."
			;;
		esac
		builtin shift
	done
}

# Main entry point.
function invoke_yana() {
	YANA_MODE="${YANA_MODE:-}"
	YANA_SOURCE="${YANA_SOURCE:-}"
	YANA_LOGFILE="${YANA_LOGFILE:-}"
	YANA_QUIET="${YANA_QUIET:-}"
	YANA_NOCOLOR="${YANA_NOCOLOR:-}"
	YANA_SHOW_HELP=false
	parse_args "$@"

	out_colored_stderr '' "$YANA_TITLE" "Version: $YANA_VERSION"

	if [[ $YANA_MODE == '-version' ]]; then
		builtin echo "$YANA_VERSION"
		builtin return 0
	fi
	if [[ $YANA_SHOW_HELP == true ]]; then
		out_help "$YANA_MODE"
		builtin return 0
	fi
	if [[ -z $YANA_MODE ]]; then
		throw 'No mode specified. Use -help to see available modes.'
	fi
	invoke_yana_"$YANA_MODE" "$YANA_SOURCE"
}

if [[ -z ${BASH_SOURCE[1]:-} ]] || [[ ${BASH_SOURCE[1]:-bashdb} == *bashdb ]]; then
	# Proceed with the script execution only if it is executed directly or under bashdb.
	invoke_yana "$@" || return $?
fi
