#!/usr/bin/env bash
# YANA (Yet Another Node Automator) Core Execution Engine
# Ultra-lean, zero-dependency shell runner

# Bash 4+ version check
if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]:-1}" -lt 4 ]; then
	echo 'Error: Bash 4.0 or higher is required.' >&2
	exit 1
fi

set -euo pipefail

YANA_QUIET="${YANA_QUIET:-false}"
YANA_MODULE_DIR="${YANA_MODULE_DIR:-.}"
YANA_MANIFEST="${YANA_MANIFEST:-.yana.json}"
YANA_VERIFY_ONLY="${YANA_VERIFY_ONLY:-false}"

# Uncomment for debugging
# YANA_MODULE_DIR="example"

_yana_usage() {
	echo "Usage: $0 [options]"
	echo "Options:"
	echo "  -d, --dir <path>      Path to module directory (default: .)"
	echo "  -m, --manifest <file> yanaspec file name within module directory (default: .yana.json)"
	echo "  -q, --quiet           Silent execution unless an error occurs"
	echo "  --verify-only         Compliance audit mode: execute read-only verification checks"
	echo "  -h, --help            Show help"
	exit 1
}

# YANA_parse_args() {
while [[ $# -gt 0 ]]; do
	case "$1" in
	-d | --dir)
		YANA_MODULE_DIR="$2"
		shift 2
		;;
	-m | --manifest)
		YANA_MANIFEST="$2"
		shift 2
		;;
	-q | --quiet)
		YANA_QUIET=true
		shift
		;;
	--verify-only)
		YANA_VERIFY_ONLY=true
		shift
		;;
	-h | --help) _yana_usage ;;
	*)
		echo "Unknown option: $1"
		_yana_usage
		;;
	esac
done
# }

yana_log() {
	if [[ $YANA_QUIET == false ]]; then echo -e "$@"; fi
}

# shellcheck disable=SC2034
ERR_GENERAL=1 ERR_MISUSE=64 ERR_DATA_FORMAT=65 ERR_NO_INPUT=66
yana_error() {
	local message="${1:-}"
	local exit_code="${2:-$ERR_GENERAL}"
	echo -e "[ERROR] $message" >&2
	return "$exit_code"
}
yana_throw() {
	local message="${1:-}"
	local exit_code="${2:-$ERR_GENERAL}"
	echo -e "[FATAL] $message" >&2
	exit "$exit_code"
}

YANA_MANIFEST_FILE="$YANA_MODULE_DIR/$YANA_MANIFEST"
MODULES_DIR="$YANA_MODULE_DIR/.yana"

_yana_check_prerequisites() {
	local cmd
	for cmd in "$@"; do
		command -v "$cmd" &>/dev/null || yana_throw "Prerequisite tool '$cmd' is missing on host node." $ERR_MISUSE
	done
}

_yana_preflight_check() {
	_yana_check_prerequisites jq base64 awk
}

_yana_resolve_vars() {
	local _input="${1:-}"
	local _resolve_iters=0
	local _max_iters=50
	local _str="$_input"
	while [[ $_str =~ \$\{(param|env|var|output):([a-zA-Z0-9_]+)\} ]]; do
		((_resolve_iters++))
		[[ $_resolve_iters -gt $_max_iters ]] && yana_throw "Variable resolution exceeded $_max_iters iterations (possible circular reference)." $ERR_DATA_FORMAT
		local _var="${BASH_REMATCH[0]}" _ctx="${BASH_REMATCH[1]}" _key="${BASH_REMATCH[2]}" _value=''
		case "$_ctx" in
		param) _value="${_yana_spec_params[$_key]:-}" ;;
		env) declare -px "$_key" &>/dev/null && _value="${!_key:-}" ;;
		output) _value="${_yana_outputs[$_key]:-}" ;;
		var) declare -F "yanavar_${_key}" &>/dev/null && _value="$(yanavar_"${_key}")" ;;
		*) yana_error "Unknown variable type '$_ctx' in variable reference '$_var'. This should never happen. Please report this as a bug." 0 ;;
		esac
		_str="${_str//$_var/$_value}"
	done

	echo "$_str"
}

_yana_execute_fn() {
	local YANA_COMMAND="$1"
	# shift
	# local YANA_ARGV=("$@")
	(
		for fn in $(declare -F | awk '$3 ~ /^_yana_/ {print $3}'); do unset -f "$fn"; done
		for v in $(declare -p | awk -F '[ =]' '$3 ~ /^_yana_/ {print $3}'); do unset -v "$v"; done
		unset -v fn v
		declare -F "$YANA_COMMAND" &>/dev/null || yana_throw "Function '$YANA_COMMAND' not found." $ERR_MISUSE
		"$YANA_COMMAND" # "${YANA_ARGV[@]}"
	)
}

_yana_exec_step() {
	local _yana_step_b64="${1:-}"
	[[ -n $_yana_step_b64 ]] || yana_throw "No step data provided to _yana_exec_step." $ERR_NO_INPUT
	local _yana_step_json _yana_step_id _yana_step_name _yana_step_action
	_yana_step_json=$(echo "$_yana_step_b64" | base64 -d) || yana_throw "Failed to decode step data. Ensure it is valid base64." $ERR_NO_INPUT
	_yana_step_name=$(echo "$_yana_step_json" | jq -r '.name // empty')
	[[ -n $_yana_step_name ]] || yana_throw "Step name is missing in step data." $ERR_NO_INPUT
	_yana_step_action=$(echo "$_yana_step_json" | jq -r '.action // empty')
	[[ -n $_yana_step_action ]] || yana_throw "Action is missing in step '$_yana_step_name'." $ERR_NO_INPUT
	_yana_step_id=$(echo "$_yana_step_json" | jq -r '.id // empty')
	if [[ -n $_yana_step_id ]] && ! [[ $_yana_step_id =~ ^[a-zA-Z0-9_]+$ ]]; then
		yana_error "Step ID is missing or invalid in step data. Shall be empty or alphanumeric." 0
		_yana_step_id=''
	fi

	local _yana_step_args _yana_step_arg _yana_step_arg_key _yana_step_arg_val_b64 _yana_step_arg_val
	local -A YANA_ARGS=()
	_yana_step_args=$(echo "$_yana_step_json" | jq -r '(.args | objects) // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]')
	for _yana_step_arg in $_yana_step_args; do
		_yana_step_arg_key="${_yana_step_arg%%=*}"
		_yana_step_arg_val_b64="${_yana_step_arg#*=}"
		_yana_step_arg_val=$(echo "$_yana_step_arg_val_b64" | base64 -d)
		#shellcheck disable=SC2034
		YANA_ARGS["$_yana_step_arg_key"]=$(_yana_resolve_vars "$_yana_step_arg_val")
	done

	# Action format: `[module/]script.function`
	local _yana_step_action_module="${_yana_step_action%%/*}"
	[[ $_yana_step_action_module == "$_yana_step_action" ]] && _yana_step_action_module='' # Default module if no module specified
	local _yana_step_action_script_fn="${_yana_step_action#*/}"
	local _yana_step_action_script="${_yana_step_action_script_fn%%.*}"
	local _yana_step_action_fn="${_yana_step_action_script_fn#*.}"
	[[ -n $_yana_step_action_script && -n $_yana_step_action_fn ]] ||
		yana_throw "Invalid action format '$_yana_step_action' in step '$_yana_step_name'. Expected format: [module/]script.function" $ERR_DATA_FORMAT

	# Load the common functions for the module if it exists
	_yana_step_common_scripts=$(ls -1 "$MODULES_DIR"/*/.sh "$MODULES_DIR/.sh" 2>/dev/null || true)
	_ifs="$IFS"
	IFS=$'\n'
	for _yana_step_common_script_path in $_yana_step_common_scripts; do
		IFS="$_ifs"
		# shellcheck source=/dev/null
		source "$_yana_step_common_script_path" || yana_throw "Failed to source script '$_yana_step_common_script_path' for step '$_yana_step_name'." $?
	done
	IFS="$_ifs"

	_yana_step_script_path="$MODULES_DIR/$_yana_step_action_module/$_yana_step_action_script.sh"
	[[ -f $_yana_step_script_path ]] || yana_throw "Script '$_yana_step_script_path' not found for step '$_yana_step_name'." $ERR_NO_INPUT
	# shellcheck source=/dev/null
	source "$_yana_step_script_path" || yana_throw "Failed to source script '$_yana_step_script_path' for step '$_yana_step_name'." $?

	local _yana_step_action_apply_fn="yanaapply_${_yana_step_action_fn}" _yana_step_action_verify_fn="yanaverify_${_yana_step_action_fn}"
	declare -F "$_yana_step_action_apply_fn" &>/dev/null ||
		yana_throw "Function '$_yana_step_action_apply_fn' not found for step '$_yana_step_name'." $ERR_NO_INPUT
	declare -F "$_yana_step_action_verify_fn" &>/dev/null || _yana_step_action_verify_fn='' # Verification function is optional

	local _yana_step_start_time _yana_step_end_time _yana_step_elapsed
	_yana_step_start_time=$(date +%s)
	# Idempotency Safeguard: Pre-execution state verification
	if [[ -z $_yana_step_action_verify_fn ]] && [[ $YANA_VERIFY_ONLY == true ]]; then
		yana_log "  - [SKIPPED] $_yana_step_name (verification function does not exist for this action)"
		return 0
	fi
	local _yana_step_in_desired_state=false _yana_step_rc=0
	if [[ -n $_yana_step_action_verify_fn ]]; then
		_yana_execute_fn "$_yana_step_action_verify_fn" || _yana_step_rc=$?
		[[ $_yana_step_rc -gt 1 ]] &&
			yana_throw "Function '$_yana_step_action_verify_fn' failed for step '$_yana_step_name' with exit code $_yana_step_rc." $_yana_step_rc
		if [[ $_yana_step_rc -eq 0 ]]; then _yana_step_in_desired_state=true; fi
	fi
	if [[ $YANA_VERIFY_ONLY != true ]] && [[ $_yana_step_in_desired_state == true ]]; then
		yana_log "  - [SKIPPED] $_yana_step_name (state already satisfied)"
		return 0
	fi
	if [[ $YANA_VERIFY_ONLY == true ]]; then
		if [[ $_yana_step_in_desired_state == true ]]; then
			yana_log "  - [COMPLIANT] $_yana_step_name (state already satisfied)"
			return 0
		fi
		yana_error "  - [NON-COMPLIANT] $_yana_step_name (state verification failed in audit mode)"
		return 1
	fi

	# Mutating State Change
	local yana_step_apply_output="" _yana_step_rc=0
	yana_step_apply_output=$(_yana_execute_fn "$_yana_step_action_apply_fn") || _yana_step_rc=$?

	[[ $_yana_step_rc -eq 0 ]] || yana_throw "$_yana_step_name (exit code: $_yana_step_rc)\n$yana_step_apply_output"
	if [[ -n $yana_step_apply_output ]] && [[ -n $_yana_step_id ]]; then
		_yana_outputs["$_yana_step_id"]="$yana_step_apply_output"
	fi

	# Post-execution Validation
	if [[ -n $_yana_step_action_verify_fn ]]; then
		(_yana_execute_fn "$_yana_step_action_verify_fn") || yana_throw "Post-action state verification failed for step '$_yana_step_name'." $ERR_GENERAL
	fi

	_yana_step_end_time=$(date +%s)
	_yana_step_elapsed=$((_yana_step_end_time - _yana_step_start_time))
	yana_log "  - [OK] $_yana_step_name (elapsed: ${_yana_step_elapsed}s)"
}

_yana_read_spec_file() {
	local _yana_spec_file="${1:-}"
	[[ -n $_yana_spec_file ]] || yana_throw "No spec file provided." $ERR_MISUSE
	[[ -f $_yana_spec_file ]] || yana_throw "Spec file '$_yana_spec_file' not found." $ERR_NO_INPUT
	jq -c -r '.' "$_yana_spec_file" 2>/dev/null || yana_throw "Failed to parse YANA spec file '$_yana_spec_file'. Ensure it is valid JSON." $ERR_DATA_FORMAT
}

_yana_apply_spec() {
	local _yana_spec_file="${1:-}"
	local _yana_spec_json
	_yana_spec_json=$(_yana_read_spec_file "$_yana_spec_file")

	#shellcheck disable=SC2046
	_yana_check_prerequisites $(jq -r '(.requires // []) | .[]' <<<"$_yana_spec_json")

	# Extract parameters into associative array
	local -A _yana_spec_params=()
	local _yana_spec_params_raw _yana_spec_param _yana_spec_param_value
	_yana_spec_params_raw=$(jq -r '.params // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]' <<<"$_yana_spec_json")
	for _yana_spec_param in $_yana_spec_params_raw; do
		local _yana_spec_param_key="${_yana_spec_param%%=*}"
		local _yana_spec_param_value_b64="${_yana_spec_param#*=}"
		_yana_spec_param_value=$(echo "$_yana_spec_param_value_b64" | base64 -d)
		_yana_spec_params["$_yana_spec_param_key"]="$_yana_spec_param_value"
	done

	yana_log "=== YANA Engine Execution Target: $_yana_spec_file ==="
	if [[ $YANA_VERIFY_ONLY == true ]]; then
		yana_log "Mode: Compliance Audit (--verify-only)"
	fi

	local -A _yana_outputs=()
	_yana_spec_steps=$(jq -r -c '.steps // [] | .[] | @base64' <<<"$_yana_spec_json")
	# Execute steps
	for _yana_step in $_yana_spec_steps; do
		_yana_exec_step "$_yana_step" || yana_throw "Step execution failed." $?
	done

	yana_log "=== YANA Execution Completed Successfully ==="
}

_yana_preflight_check
# YANA_parse_args "$@"
(_yana_apply_spec "$YANA_MANIFEST_FILE") || yana_throw "YANA execution failed for manifest '$YANA_MANIFEST_FILE'." $?
