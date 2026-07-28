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

_yana_usage() {
	case "${YANA_MODE:-}" in
	apply)
		builtin echo "Usage: yana.sh apply -source <path|url> [-routine <name>]"
		builtin echo "  Applies the specified YANA Module."
		builtin echo "Options:"
		builtin echo "  -source <path|url>         Specifies the source of YANA Module to apply. Can be a local path or a URL. Uses YANA_LOGFILE environment variable."
		builtin echo "  -routine <name>            Specifies the routine to execute within the YANA Module."
		;;
	verify)
		builtin echo "Usage: yana.sh verify -source <path|url> [-routine <name>]"
		builtin echo "  Compares the state of the system with the state specified by the YANA Module without making any changes."
		builtin echo "Options:"
		builtin echo "  -source <path|url>         Specifies the source of YANA Module to verify. Can be a local path or a URL. Uses YANA_LOGFILE environment variable."
		builtin echo "  -routine <name>            Specifies the routine to execute within the YANA Module."
		;;
	fetch)
		builtin echo "Usage: yana.sh fetch -source <path|url>"
		builtin echo "  Fetches the specified YANA Module from the given source (path or URL)."
		builtin echo "Options:"
		builtin echo "  -source <path|url>         Specifies the source of YANA Module to fetch. Can be path or URL. Uses YANA_LOGFILE environment variable."
		;;
	version)
		builtin echo "Usage: yana.sh version"
		builtin echo "  Displays the version of YANA."
		;;
	*)
		builtin echo "Usage: yana.sh <general options> [mode] <mode options>"
		builtin echo "Modes:"
		builtin echo "  version									 	 Displays the version of YANA."
		builtin echo "  apply                      Applies the specified YANA Module."
		builtin echo "  verify                     Compares the state of the system with the state specified by the YANA Module without making any changes."
		builtin echo "  fetch                      Fetches the specified YANA Module."
		;;
	esac
	builtin echo "General Options:"
	builtin echo "  -help                      Displays this help message."
	builtin echo "  -help <mode>               Displays help for the specified mode."
	builtin echo "  -logfile <file>            Log file path. Uses YANA_LOGFILE environment variable. If not specified, logs are not written to a file."
}

# Logs a message to the stderr.
# Takes care of logging to a file if $YANA_LOGFILE is specified.
log() {
	builtin local _level="${1:-${level:-info}}"
	builtin local _message="${2:-${message:-}}"
	builtin local _logMessage
	_logMessage="$(date -u +'%Y-%m-%dT%H:%M:%SZ')\t${_level^^}\t${_message}"
	builtin echo -e "$_logMessage" >&2
	if [[ -n $YANA_LOGFILE ]]; then
		builtin echo -e "${_logMessage}" >>"$YANA_LOGFILE" || throw "Failed to write to log file '$YANA_LOGFILE'. Check permissions and available disk space."
	fi
}

# Throws an error message and exits the script with the specified return code.
builtin readonly ERR_GENERAL=1 ERR_MISUSE=64 ERR_DATA_FORMAT=65 ERR_NO_INPUT=66
throw() {
	builtin local _message="${1:-${message:-}}"
	builtin local _rc="${2:-${rc:-$ERR_GENERAL}}"
	log fatal "$_message"
	if [[ -n $YANA_TRACE ]]; then
		set +x
		log trace "Stack trace:"
		builtin local _frame=0 _trace
		while true; do
			_trace=$(builtin caller $_frame | awk '{print $3 ":" $1 " (" $2 ") "}')
			[[ -z $_trace ]] && break
			log trace "$_trace"
			((_frame += 1))
		done
	fi
	builtin exit "$_rc"
}

_yana_check_prerequisites() {
	builtin local cmd
	for cmd in "$@"; do builtin command -v "$cmd" &>/dev/null || throw "Prerequisite tool '$cmd' is missing on host node." $ERR_MISUSE; done
}
# Resolves variable placeholders in the input string using the provided context (param, env, var, output).
_yana_resolve_vars() {
	builtin local _input="${1:-}"
	builtin local _resolve_iters=0 _max_iters=${max_iterations:-50}
	while [[ $_input =~ \$\{(param|env|var|output):([a-zA-Z0-9_]+)\} ]]; do
		((_resolve_iters++))
		[[ $_resolve_iters -gt $_max_iters ]] && throw "Variable resolution exceeded $_max_iters iterations (possible circular reference)." $ERR_DATA_FORMAT
		builtin local _var="${BASH_REMATCH[0]}" _ctx="${BASH_REMATCH[1]}" _key="${BASH_REMATCH[2]}" _value=''
		case "$_ctx" in
		param) _value="${YANA_PARAMS[$_key]:-}" ;;
		output) _value="${YANA_OUTPUTS[$_key]:-}" ;;
		env) builtin declare -px "$_key" &>/dev/null && _value="${!_key:-}" ;;
		var) builtin declare -F "yanavar_${_key}" &>/dev/null && _value="$(yanavar_"${_key}")" ;;
		*) throw "Unknown variable type '$_ctx' in variable reference '$_var'. This should never happen. Please report this as a bug." $ERR_GENERAL ;;
		esac
		[[ -z $_value ]] && log warning "Variable '$_var' resolved to an empty value. Ensure that the variable is defined and has a non-empty value."
		_input="${_input//$_var/$_value}"
	done
	builtin echo "$_input"
}
_yana_exec_fn() {
	builtin local YANA_COMMAND="$1"
	# shift
	# local YANA_ARGV=("$@")
	log debug "Executing function '$YANA_COMMAND' with arguments: $(declare -p YANA_ARGS)"
	builtin local _rc=0
	(
		for fn in $(builtin declare -F | awk '$3 ~ /^_yana_/ {print $3}'); do unset -f "$fn"; done
		for v in $(builtin declare -p | awk -F '[ =]' '$3 ~ /^_yana_/ {print $3}'); do builtin unset -v "$v"; done
		builtin unset -v fn v
		builtin declare -F "$YANA_COMMAND" &>/dev/null || throw "Function '$YANA_COMMAND' not found." $ERR_MISUSE
		"$YANA_COMMAND" # "${YANA_ARGV[@]}"
	) || _rc=$?
	[[ $_rc -gt 1 ]] && throw "Function '$YANA_COMMAND' failed with return code: $_rc" $_rc
	builtin return $_rc
}

_yana_load_step() {
	builtin local _yana_step_b64="${1:-}"
	[[ -n $_yana_step_b64 ]] || throw "No step data provided to _yana_load_step." $ERR_NO_INPUT
	_yana_step_json=$(builtin echo "$_yana_step_b64" | base64 -d) || throw "Failed to decode step data. Ensure it is valid base64." $ERR_NO_INPUT

	YANA_STEP=()
	YANA_STEP[id]=$(builtin echo "$_yana_step_json" | jq -r '.id // empty')
	[[ -n ${YANA_STEP[id]} && ! ${YANA_STEP[id]} =~ ^[a-zA-Z0-9_]+$ ]] && throw "Step ID shall be empty or alphanumeric. Got: '${YANA_STEP[id]}'" $ERR_NO_INPUT
	YANA_STEP[name]=$(builtin echo "$_yana_step_json" | jq -r '.name // error') || throw "Step name is missing in step data." $ERR_NO_INPUT
	YANA_STEP[action]=$(builtin echo "$_yana_step_json" | jq -r '.action // error' 2>/dev/null) || throw "Step action is missing in step data." $ERR_NO_INPUT
	# Action format: `[module/]script:function`
	YANA_STEP[action.module]="${YANA_STEP[action]%%/*}"
	[[ ${YANA_STEP[action.module]} == "${YANA_STEP[action]}" ]] && YANA_STEP[action.module]='' # Default module if no module specified
	[[ ${YANA_STEP[action.module]} =~ ^[a-zA-Z0-9_\.-]*$ ]] || throw "Step action module shall be empty or alphanumeric. Got: '${YANA_STEP[action.module]}'" $ERR_NO_INPUT
	builtin local _yana_step_action_script_fn="${YANA_STEP[action]#*/}"
	YANA_STEP[action.script]="${_yana_step_action_script_fn%%:*}"
	[[ ${YANA_STEP[action.script]} =~ ^[a-zA-Z0-9_\.-]+$ ]] || throw "Step action script shall be alphanumeric. Got: '${YANA_STEP[action.script]}'" $ERR_NO_INPUT
	YANA_STEP[action.func]="${_yana_step_action_script_fn#*:}"
	[[ ${YANA_STEP[action.func]} =~ ^[a-zA-Z0-9_\.-]+$ ]] || throw "Step action function shall be alphanumeric. Got: '${YANA_STEP[action.func]}'" $ERR_NO_INPUT

	# Load the common scripts for the module if they exist
	builtin local _yana_step_common_scripts _yana_step_script_path
	_yana_step_common_scripts=$(ls -1 "$YANA_SOURCE/.yana"/*/.sh "$YANA_SOURCE/.yana/.sh" 2>/dev/null || true)
	builtin local _ifs="$IFS"
	IFS=$'\n'
	for _yana_step_script_path in $_yana_step_common_scripts; do
		IFS="$_ifs"
		# shellcheck source=/dev/null
		builtin source "$_yana_step_script_path" || throw "Failed to source script '$_yana_step_script_path'." $?
	done
	IFS="$_ifs"
	# Load the specific script for the step
	_yana_step_script_path="$YANA_SOURCE/.yana/${YANA_STEP[action]%%:*}.sh"
	[[ -f $_yana_step_script_path ]] || throw "Script '$_yana_step_script_path' not found." $ERR_NO_INPUT
	# shellcheck source=/dev/null
	builtin source "$_yana_step_script_path" || throw "Failed to source script '$_yana_step_script_path'." $?

	# Load and evaluate the step arguments into the associative array YANA_ARGS
	builtin local _yana_step_arg _yana_step_arg_key _yana_step_arg_val
	YANA_ARGS=()
	while IFS= builtin read -r _yana_step_arg; do
		[[ -n $_yana_step_arg ]] || continue
		_yana_step_arg_key="${_yana_step_arg%%=*}"
		_yana_step_arg_val=$(builtin echo "${_yana_step_arg#*=}" | base64 -d)
		#shellcheck disable=SC2034
		YANA_ARGS["$_yana_step_arg_key"]="$_yana_step_arg_val"
	done < <(builtin echo "$_yana_step_json" | jq -r '(.args | objects) // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]')

	# _yana_step_args=$(builtin echo "$_yana_step_json" | jq -r '(.args | objects) // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]')
	# for _yana_step_arg in $_yana_step_args; do
	# 	_yana_step_arg_key="${_yana_step_arg%%=*}"
	# 	builtin local _yana_step_arg_val_b64="${_yana_step_arg#*=}"
	# 	_yana_step_arg_val=$(builtin echo "$_yana_step_arg_val_b64" | base64 -d)
	# 	#shellcheck disable=SC2034
	# 	YANA_ARGS["$_yana_step_arg_key"]=$(_yana_resolve_vars "$_yana_step_arg_val")
	# done

}
_yana_apply_step() {
	# shellcheck disable=SC2034
	builtin local -A YANA_STEP YANA_ARGS
	_yana_load_step "$@"
	_yana_load_scripts "${YANA_STEP[action.script]}"
	builtin local _yana_step_apply_fn="yanaapply_${YANA_STEP[action.func]}"
	builtin local _yana_step_verify_fn="yanaverify_${YANA_STEP[action.func]}"
	builtin declare -F "$_yana_step_apply_fn" &>/dev/null || throw "Function '$_yana_step_apply_fn' not found." $ERR_NO_INPUT
	builtin declare -F "$_yana_step_verify_fn" &>/dev/null || {
		log warning "Function '$_yana_step_verify_fn' not found. Verification will be skipped for this step."
		_yana_step_verify_fn=''
	}
	builtin local _rc=0 _yana_step_output
	if [[ -n $_yana_step_verify_fn ]]; then
		log info "  - [VERIFYING] ${YANA_STEP[name]} (checking if changes are needed)"
		_yana_step_output=$(_yana_exec_fn "$_yana_step_verify_fn") || _rc=$?
		if [[ $_rc -eq 0 ]]; then # compliant, no changes needed
			log info "  - [COMPLIANT] ${YANA_STEP[name]} (no changes needed)"
			return 0
		elif [[ $_rc -eq 1 ]]; then # non-compliant, changes needed
			log info "  - [NON-COMPLIANT] ${YANA_STEP[name]} (changes needed)"
		else # argument/syntax/other errors
			log error "  - [FAILED] ${YANA_STEP[name]} (failed to verify compliance, return code: $_rc)"
			return $_rc
		fi
	fi
	log info "  - [APPLYING] ${YANA_STEP[name]} (making changes)"
	_rc=0
	_yana_step_output=$(_yana_exec_fn "$_yana_step_apply_fn") || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		log info "  - [APPLIED] ${YANA_STEP[name]} (changes applied)"
		[[ -n "${YANA_STEP[id]}" ]] && YANA_OUTPUTS["${YANA_STEP[id]}"]="${_yana_step_output:-}"
	else
		log error "  - [FAILED] ${YANA_STEP[name]} (failed to apply changes, return code: $_rc)"
		return $_rc
	fi
	if [[ -n $_yana_step_verify_fn ]]; then
		log info "  - [POST-VERIFYING] ${YANA_STEP[name]} (checking if changes stuck)"
		if _yana_exec_fn "$_yana_step_verify_fn"; then
			log info "  - [POST-COMPLIANT] ${YANA_STEP[name]} (changes verified)"
		else
			log error "  - [POST-NON-COMPLIANT] ${YANA_STEP[name]} (changes did not stick)"
			return 1
		fi
	fi
}

_yana_verify_step() {
	# shellcheck disable=SC2034
	builtin local -A YANA_STEP YANA_ARGS
	_yana_load_step "$@"
	builtin local _yana_step_verify_fn="yanaverify_${YANA_STEP[action.func]}"
	builtin declare -F "$_yana_step_verify_fn" &>/dev/null || {
		log info "  - [SKIPPED] ${YANA_STEP[name]} (verification function not found)"
		return 0
	}
	log info "  - [VERIFYING] ${YANA_STEP[name]} (checking if state is compliant)"
	if _yana_exec_fn "$_yana_step_verify_fn"; then
		log info "  - [COMPLIANT] ${YANA_STEP[name]} (state is compliant)"
	else
		log info "  - [NON-COMPLIANT] ${YANA_STEP[name]} (state is not compliant)"
		return 1
	fi
}
# Reads and parses the YANA spec file for the specified routine.
_yana_read_spec_file() {
	builtin local _yana_spec_path="${YANA_SOURCE}/${YANA_ROUTINE}.yana.json" _yana_spec_file
	_yana_spec_file=$(realpath "$_yana_spec_path" 2>/dev/null) || throw "'$_yana_spec_path': No such file or directory" $ERR_NO_INPUT
	jq -e -r '.' "$_yana_spec_file" >/dev/null 2>&1 || throw "Failed to parse YANA spec file '$_yana_spec_file'. Ensure it is valid JSON." $ERR_DATA_FORMAT

	YANA_SPEC=()
	YANA_SPEC[name]=$(jq -r '.name // empty' "$_yana_spec_file")
	YANA_SPEC[description]=$(jq -r '.description // empty' "$_yana_spec_file")
	YANA_SPEC[version]=$(jq -r '.version // empty' "$_yana_spec_file")
	YANA_SPEC[author]=$(jq -r '.author // empty' "$_yana_spec_file")
	YANA_SPEC[license]=$(jq -r '.license // empty' "$_yana_spec_file")
	YANA_SPEC[requires]=$(jq -r '(.requires // []) | .[]' "$_yana_spec_file")
	YANA_SPEC[steps]=$(jq -r -c '.steps // [] | .[] | @base64' "$_yana_spec_file")
	YANA_PARAMS=()
	# Extract parameters into associative array
	builtin local _yana_spec_params_raw _yana_spec_param _yana_spec_param_key _yana_spec_param_value _yana_spec_param_value_b64
	while IFS= builtin read -r _yana_spec_param; do
		[[ -n $_yana_spec_param ]] || continue
		_yana_spec_param_key="${_yana_spec_param%%=*}"
		_yana_spec_param_value=$(builtin echo "${_yana_spec_param#*=}" | base64 -d)
		#shellcheck disable=SC2034
		YANA_PARAMS["$_yana_spec_param_key"]="$_yana_spec_param_value"
	done < <(jq -r '(.params | objects) // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]' "$_yana_spec_file")


	# _yana_spec_params_raw=$(jq -r '.params // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]' "$_yana_spec_file")
	# for _yana_spec_param in $_yana_spec_params_raw; do
	# 	_yana_spec_param_key="${_yana_spec_param%%=*}"
	# 	_yana_spec_param_value_b64="${_yana_spec_param#*=}"
	# 	_yana_spec_param_value=$(echo "$_yana_spec_param_value_b64" | base64 -d)
	# 	YANA_PARAMS["$_yana_spec_param_key"]="$_yana_spec_param_value"
	# done
}
# Outputs the version of YANA.
_yana_mode_version() { builtin echo "$YANA_VERSION"; }
# Fetches and unpacks the YANA Module from the specified source (local path or URL).
_yana_mode_fetch() {
	[[ -z $YANA_SOURCE ]] && throw 'No source specified'
	log info "Fetching YANA Module: $YANA_SOURCE"
	# Implement the fetch logic here
}
# Verifies the YANA Module from the specified source (local path or URL) without making any changes.
_yana_mode_verify() {
	[[ -z $YANA_SOURCE ]] && throw 'No source specified'
	log info "Verifying YANA Module: $YANA_SOURCE"
	# Implement the verify logic here
}
# Applies the YANA Module from the specified source (local path or URL).
_yana_mode_apply() {
	[[ -z $YANA_SOURCE ]] && throw 'No source specified'
	_yana_mode_fetch
	log info "Applying YANA Module: $YANA_SOURCE:$YANA_ROUTINE"

	# Assume YANA_SOURCE is a local path for now. _yana_mode_fetch will handle fetching from URL later.
	builtin local -A YANA_SPEC YANA_STEPS YANA_PARAMS YANA_OUTPUTS
	_yana_read_spec_file

	#shellcheck disable=SC2086
	_yana_check_prerequisites ${YANA_SPEC[requires]}

	YANA_OUTPUTS=()
	builtin local _yana_step
	# Execute steps
	for _yana_step in ${YANA_SPEC[steps]}; do
		_yana_apply_step "$_yana_step" || throw "Step execution failed." $?
	done
	log info "YANA Module applied successfully: $YANA_SOURCE:$YANA_ROUTINE"
}
# Parse command-line arguments and set global variables accordingly.
_yana_parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		apply | verify | fetch | version)
			YANA_MODE="$1"
			;;
		-source | --source)
			builtin shift
			[[ $# -ge 1 && $1 != -* ]] || throw 'Missing value for -source'
			YANA_SOURCE="$1"
			;;
		-routine | --routine)
			builtin shift
			[[ $# -ge 1 && $1 != -* ]] || throw 'Missing value for -routine'
			YANA_ROUTINE="$1"
			;;
		-logfile | --logfile)
			builtin shift
			[[ $# -ge 1 && $1 != -* ]] || throw 'Missing value for -logfile'
			YANA_LOGFILE="$1"
			;;
		-help | --help)
			_yana_show_help=true
			;;
		-trace | --trace)
			YANA_TRACE=true
			set -x
			;;
		*)
			if [[ $1 == -* ]]; then
				throw "Unknown option: $1. Use -help to see available options."
			fi
			throw "Unknown mode: $1. Use -help to see available modes."
			;;
		esac
		builtin shift
	done
}
# Main entry point.
_yana_() {
	builtin local YANA_MODE="${YANA_MODE:-}" YANA_SOURCE="${YANA_SOURCE:-}" YANA_ROUTINE="${YANA_ROUTINE:-}" YANA_LOGFILE="${YANA_LOGFILE:-}" _yana_show_help=false
	_yana_parse_args "$@"

	# Display the title and version information
	log info "$YANA_TITLE" "Version: $YANA_VERSION" >&2
	_yana_check_prerequisites jq base64 awk

	if [[ $_yana_show_help == true ]]; then
		_yana_usage
		builtin return 0
	fi
	[[ -z $YANA_MODE ]] && throw 'No mode specified. Use -help to see available modes.'
	builtin local YANA_CACHE_DIR="${YANA_CACHE_DIR:-$HOME/.yana/cache}" YANA_TEMP_DIR="${YANA_TEMP_DIR:-$HOME/.yana/temp}"
	[[ -d $YANA_CACHE_DIR ]] || mkdir -p "$YANA_CACHE_DIR" || throw "Failed to create cache directory '$YANA_CACHE_DIR'." $ERR_GENERAL
	[[ -d $YANA_TEMP_DIR ]] || mkdir -p "$YANA_TEMP_DIR" || throw "Failed to create temp directory '$YANA_TEMP_DIR'." $ERR_GENERAL
	_yana_mode_"$YANA_MODE"
}
if [[ -z ${BASH_SOURCE[1]:-} ]] || [[ ${BASH_SOURCE[1]:-bashdb} == *bashdb ]]; then
	# Proceed with the script execution only if it is executed directly or under bashdb.
	_yana_ "$@" || builtin exit $?
fi
