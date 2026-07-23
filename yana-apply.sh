#!/usr/bin/env bash
# YANA (Yet Another Node Automator) Core Execution Engine
# Ultra-lean, zero-dependency shell runner

set -euo pipefail

YANA_QUIET="${YANA_QUIET:-false}"
YANA_MODULE_DIR="${YANA_MODULE_DIR:-.}"
YANA_MANIFEST="${YANA_MANIFEST:-.yana.json}"
YANA_VERIFY_ONLY="${YANA_VERIFY_ONLY:-false}"

# Uncomment for debugging
# YANA_MODULE_DIR="example"

YANA_usage() {
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
	-h | --help) YANA_usage ;;
	*)
		echo "Unknown option: $1"
		YANA_usage
		;;
	esac
done
# }

YANA_log() {
	if [[ $YANA_QUIET == false ]]; then echo -e "$@"; fi
}

YANA_log_err() {
	echo -e "$@" >&2
}

YANA_MANIFEST_FILE="$YANA_MODULE_DIR/$YANA_MANIFEST"
MODULES_DIR="$YANA_MODULE_DIR/.yana"

declare YANAspec_json='{}'

YANA_preflight_check() {
	for cmd in jq base64 awk; do
		if ! command -v "$cmd" &>/dev/null; then
			YANA_log_err "[ERROR] Prerequisite tool '$cmd' is missing on host node."
			exit 1
		fi
	done
}

YANA_check_prerequisites() {
	for cmd in "$@"; do
		if ! command -v "$cmd" &>/dev/null; then
			YANA_log_err "[ERROR] Prerequisite tool '$cmd' is missing on host node."
			exit 1
		fi
	done
}

# --- Helper: Dynamic Variable Resolver ---
YANA_resolve_vars() {
	local val="${1:-}"

	while [[ $val =~ \$\{(param|env|var):([a-zA-Z0-9_]+)\} ]]; do
		local p_full="${BASH_REMATCH[0]}"
		local p_type="${BASH_REMATCH[1]}"
		local p_name="${BASH_REMATCH[2]}"
		local p_val=""
		case "$p_type" in
		param) p_val="${YANAspec_params[$p_name]:-}" ;;
		env) p_val="${!p_name:-}" ;;
		var)
			case "$p_name" in
			time) p_val=$(date +%s) ;;
			iso_time) p_val=$(date -u +"%Y-%m-%dT%H:%M:%SZ") ;;
			uid) p_val=$(id -u) ;;
			user) p_val=$(whoami) ;;
			hostname) p_val=$(hostname) ;;
			os) p_val=$(uname -s) ;;
			is_root) [[ $(id -u) -eq 0 ]] && p_val="true" || p_val="false" ;;
			*) p_val="" ;;
			esac
			;;
		esac
		val="${val//"$p_full"/"$p_val"}"
	done

	echo "$val"
}

YANA_exec_step() {
	local YANAstep_b64="${1:-}"
	if [[ -z $YANAstep_b64 ]]; then
		YANA_log_err "[ERROR] No step data provided to YANA_exec_step."
		exit 1
	fi
	local YANAstep_json
	YANAstep_json=$(echo "$YANAstep_b64" | base64 -d) || {
		YANA_log_err "[ERROR] Failed to decode step data. Ensure it is valid base64."
		exit 1
	}
	YANAstep_name=$(echo "$YANAstep_json" | jq -r '.name // empty')
	if [[ -z $YANAstep_name ]]; then
		YANA_log_err "[ERROR] Step name is missing in step data."
		exit 1
	fi
	YANAstep_action=$(echo "$YANAstep_json" | jq -r '.action // empty')
	if [[ -z $YANAstep_action ]]; then
		YANA_log_err "[ERROR] Action is missing in step '$YANAstep_name'."
		exit 1
	fi
	YANA_execute() {
		local cmd="$1"
		shift
		local args=("$@")
		(
			for fn in $(declare -F | awk '{print $3}' | grep '^YANA_' || true); do unset -f "$fn"; done
			# for v in $(declare -p | awk '{print $3}' | grep '^YANA_' || true); do unset -v "$v"; done
			if declare -F "$cmd" &>/dev/null; then
				"$cmd" "${args[@]}"
			else
				YANA_log_err "[ERROR] Function '$cmd' not found for step '$YANAstep_name'."
				return 1
			fi
		)
	}
	declare -A YANAargs=()
	YANAstep_args=$(echo "$YANAstep_json" | jq -r '.args // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]')
	for YANAstep_arg in $YANAstep_args; do
		YANAstep_arg_key="${YANAstep_arg%%=*}"
		YANAstep_arg_val_base64="${YANAstep_arg#*=}"
		YANAstep_arg_val=$(echo "$YANAstep_arg_val_base64" | base64 -d)
		#shellcheck disable=SC2034
		YANAargs["$YANAstep_arg_key"]=$(YANA_resolve_vars "$YANAstep_arg_val")
	done

	# Action format: `[module/]script.function`
	YANAstep_action_module="${YANAstep_action%%/*}"
	[[ $YANAstep_action_module == "$YANAstep_action" ]] && YANAstep_action_module='' # Default module if no module specified
	YANAstep_action_script_fn="${YANAstep_action#*/}"
	YANAstep_action_script="${YANAstep_action_script_fn%%.*}"
	YANAstep_action_fn="${YANAstep_action_script_fn#*.}"
	if [[ -z $YANAstep_action_script || -z $YANAstep_action_fn ]]; then
		YANA_log_err "[ERROR] Invalid action format '$YANAstep_action' in step '$YANAstep_name'. Expected format: [module/]script.function"
		exit 1
	fi

	YANAstep_script_path="$MODULES_DIR/$YANAstep_action_module/$YANAstep_action_script.sh"
	if [[ ! -f $YANAstep_script_path ]]; then
		YANA_log_err "[ERROR] Script '$YANAstep_script_path' not found for step '$YANAstep_name'."
		exit 1
	fi
	# shellcheck source=/dev/null
	source "$YANAstep_script_path" || {
		YANA_log_err "[ERROR] Failed to source script '$YANAstep_script_path' for step '$YANAstep_name'."
		exit 1
	}

	local YANAstep_action_apply_fn="YANAapply_${YANAstep_action_fn}" YANAstep_action_verify_fn="YANAverify_${YANAstep_action_fn}"
	if ! declare -F "$YANAstep_action_apply_fn" &>/dev/null; then
		YANA_log_err "[ERROR] Function '$YANAstep_action_apply_fn' not found for step '$YANAstep_name'."
		exit 1
	fi
	declare -F "$YANAstep_action_verify_fn" &>/dev/null || YANAstep_action_verify_fn=''

	start_time=$(date +%s)
	# Idempotency Safeguard: Pre-execution state verification
	if [[ -n $YANAstep_action_verify_fn ]]; then
		if (YANA_execute "$YANAstep_action_verify_fn"); then
			if [[ $YANA_VERIFY_ONLY == true ]]; then
				YANA_log "  - [COMPLIANT] $YANAstep_name (state already satisfied)"
			else
				YANA_log "  - [SKIPPED] $YANAstep_name (state already satisfied)"
			fi
			return 0
		else
			if [[ $YANA_VERIFY_ONLY == true ]]; then
				YANA_log_err "  - [NON-COMPLIANT] $YANAstep_name (state verification failed in audit mode)"
				exit 1
			fi
		fi
	fi

	# Mutating State Change
	local yana_step_apply_output="" rc=0
	yana_step_apply_output=$(YANA_execute "$YANAstep_action_apply_fn") || rc=$?

	if [[ $rc -ne 0 ]]; then
		YANA_log_err "  - [FAILED] $YANAstep_name (exit code: $rc)"
		if [[ -n $yana_step_apply_output ]]; then
			YANA_log_err "    Details: $yana_step_apply_output"
		fi
		exit $rc
	fi

	# Post-execution Validation
	if [[ -n $YANAstep_action_verify_fn ]]; then
		if ! (YANA_execute "$YANAstep_action_verify_fn"); then
			YANA_log_err "  - [FAILED] $YANAstep_name (post-action state verification failed)"
			exit 1
		fi
	fi

	end_time=$(date +%s)
	elapsed=$((end_time - start_time))

	YANA_log "  - [OK] $YANAstep_name (elapsed: ${elapsed}s)"

}

YANA_read_spec_file() {
	local spec_file="$1"
	if [[ -z $spec_file ]]; then
		YANA_log_err "[ERROR] No spec file provided to YANA_read_spec_file."
		exit 1
	fi
	if [[ ! -f $spec_file ]]; then
		YANA_log_err "[ERROR] YANA spec file '$spec_file' not found."
		exit 1
	fi

	local spec_json
	spec_json=$(jq -c '.' "$spec_file" 2>/dev/null) || {
		YANA_log_err "[ERROR] Failed to parse YANA spec file '$spec_file'. Ensure it is valid JSON."
		exit 1
	}

	echo "$spec_json"
}

YANA_apply_spec() {
	local YANAspec_file="$1"
	local YANAspec_json
	YANAspec_json=$(YANA_read_spec_file "$YANAspec_file")

	#shellcheck disable=SC2046
	YANA_check_prerequisites $(jq -r '(.requires // []) | .[]' <<<"$YANAspec_json")

	# Extract parameters into associative array
	local -A YANAspec_params=()
	local YANAspec_params_raw

	YANAspec_params_raw=$(jq -r '.params // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]' <<<"$YANAspec_json")

	for p in $YANAspec_params_raw; do
		key="${p%%=*}"
		val_base64="${p#*=}"
		val=$(echo "$val_base64" | base64 -d)
		YANAspec_params["$key"]="$val"
	done

	YANA_log "=== YANA Engine Execution Target: $YANAspec_file ==="
	if [[ $YANA_VERIFY_ONLY == true ]]; then
		YANA_log "Mode: Compliance Audit (--verify-only)"
	fi

	YANAspec_steps=$(jq -r -c '.steps // [] | .[] | @base64' <<<"$YANAspec_json")
	# Execute steps
	for step in $YANAspec_steps; do
		(YANA_exec_step "$step") || {
			YANA_log_err "[ERROR] Step execution failed."
			exit 1
		}
	done

	YANA_log "=== YANA Execution Completed Successfully ==="
}

YANA_preflight_check
# YANA_parse_args "$@"
YANA_apply_spec "$YANA_MANIFEST_FILE" || {
	YANA_log_err "[ERROR] YANA execution failed."
	exit 1
}
