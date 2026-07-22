#!/usr/bin/env bash
# YANA (Yet Another Node Automator) Core Execution Engine
# Ultra-lean, zero-dependency shell runner

set -euo pipefail

QUIET="${QUIET:-false}"
MODULE_DIR="${MODULE_DIR:-.}"
MANIFEST="${MANIFEST:-.yana.json}"
VERIFY_ONLY="${VERIFY_ONLY:-false}"

MODULE_DIR="example"

# --- CLI Options Parser ---
usage() {
	echo "Usage: $0 [options]"
	echo "Options:"
	echo "  -d, --dir <path>      Path to module directory (default: .)"
	echo "  -m, --manifest <file> yanaspec file name within module directory (default: .yana.json)"
	echo "  -q, --quiet           Silent execution unless an error occurs"
	echo "  --verify-only         Compliance audit mode: execute read-only verification checks"
	echo "  -h, --help            Show help"
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-d | --dir)
		MODULE_DIR="$2"
		shift 2
		;;
	-m | --manifest)
		MANIFEST="$2"
		shift 2
		;;
	-q | --quiet)
		QUIET=true
		shift
		;;
	--verify-only)
		VERIFY_ONLY=true
		shift
		;;
	-h | --help) usage ;;
	*)
		echo "Unknown option: $1"
		usage
		;;
	esac
done

log() {
	if [[ $QUIET == false ]]; then echo -e "$@"; fi
}

log_err() {
	echo -e "$@" >&2
}

# --- 1. Load & Validate Manifest File ---
MANIFEST_FILE="$MODULE_DIR/$MANIFEST"
if [[ ! -f $MANIFEST_FILE ]]; then
	log_err "[ERROR] Manifest file '$MANIFEST_FILE' not found."
	exit 1
fi

for cmd in jq base64 awk; do
	if ! command -v "$cmd" &>/dev/null; then
		log_err "[ERROR] Prerequisite tool '$cmd' is missing on host node."
		exit 1
	fi
done

YANAspec_json=$(jq -c '.' "$MANIFEST_FILE" 2>/dev/null) || {
	log_err "[ERROR] Failed to parse manifest file '$MANIFEST_FILE'. Ensure it is valid JSON."
	exit 1
}

# --- 2. Pre-flight Check Phase ---
requires_count=$(jq -r '(.requires // []) | length' <<<"$YANAspec_json")
for ((i = 0; i < requires_count; i++)); do
	req=$(jq -r ".requires[$i]" <<<"$YANAspec_json")
	if ! command -v "$req" &>/dev/null; then
		log_err "[PRE-FLIGHT FAILED] Missing target dependency: $req"
		exit 1
	fi
done

# --- 3. Load Resource Modules ---
MODULES_DIR="$MODULE_DIR/.yana"
if [[ -d $MODULES_DIR ]]; then
	for module_script in "$MODULES_DIR"/*.sh; do
		if [[ -f $module_script ]]; then
			# shellcheck source=/dev/null
			source "$module_script"
		fi
	done
fi

# --- Helper: Dynamic Variable Resolver ---
resolve_vars() {
	local val="${1:-}"

	# Resolve ${param:param_name}
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

declare -A YANAspec_params

yanaspec_params=$(jq -r '.params // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]' <<<"$YANAspec_json")

for p in $yanaspec_params; do
	key="${p%%=*}"
	val_base64="${p#*=}"
	val=$(echo "$val_base64" | base64 -d)
	YANAspec_params["$key"]="$val"
done

# --- 4. Core Execution Loop ---
steps_count=$(jq -r '(.steps // []) | length' <<<"$YANAspec_json")

log "=== YANA Engine Execution Target: $MANIFEST_FILE ==="
if [[ $VERIFY_ONLY == true ]]; then
	log "Mode: Compliance Audit (--verify-only)"
fi

for ((i = 0; i < steps_count; i++)); do
	step_json=$(jq -c ".steps[$i]" <<<"$YANAspec_json")
	step_name=$(echo "$step_json" | jq -r '.name // "step_'$i'"')
	action=$(echo "$step_json" | jq -r '.action')

	declare -A YANAargs
	raw_args=$(echo "$step_json" | jq -r '.args // {} | to_entries | map("\(.key)=\(.value|@text|@base64)") | .[]')
	for raw_arg in $raw_args; do
		key="${raw_arg%%=*}"
		val_base64="${raw_arg#*=}"
		val=$(echo "$val_base64" | base64 -d)
		#shellcheck disable=SC2034
		YANAargs["$key"]=$(resolve_vars "$val")
	done

	apply_func="YANAapply:${action}"
	verify_func="YANAverify:${action}"

	start_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
	# Idempotency Safeguard: Pre-execution state verification
	already_satisfied=false
	if declare -f "$verify_func" >/dev/null; then
		if ("$verify_func"); then
			already_satisfied=true
		fi
	fi

	if [[ $already_satisfied == true ]]; then
		log "  - [SKIPPED] $step_name (state already satisfied)"
		continue
	fi

	# Read-Only Compliance Mode
	if [[ $VERIFY_ONLY == true ]]; then
		if declare -f "$verify_func" >/dev/null; then
			log_err "  - [NON-COMPLIANT] $step_name (state verification failed in audit mode)"
			exit 1
		else
			log "  - [SKIPPED] $step_name (no verification function provided)"
			continue
		fi
	fi

	# Check function presence
	if ! declare -f "$apply_func" >/dev/null; then
		log_err "  - [FAILED] $step_name (action '$action' not found in modules)"
		exit 1
	fi

	# Mutating State Change
	exec_output=""
	exec_output=$("$apply_func")
	exit_code=$?

	if [[ $exit_code -ne 0 ]]; then
		log_err "  - [FAILED] $step_name (exit code: $exit_code)"
		if [[ -n $exec_output ]]; then
			log_err "    Details: $exec_output"
		fi
		exit $exit_code
	fi

	# Post-execution Validation
	if declare -f "$verify_func" >/dev/null; then
		if ! ("$verify_func"); then
			log_err "  - [FAILED] $step_name (post-action state verification failed)"
			exit 1
		fi
	fi

	end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
	elapsed=$((end_time - start_time))

	log "  - [OK] $step_name (elapsed: ${elapsed}ms)"
done

log "=== YANA Execution Completed Successfully ==="
