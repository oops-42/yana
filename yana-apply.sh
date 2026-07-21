#!/usr/bin/env bash
# YANA (Yet Another Node Automator) Core Execution Engine
# Ultra-lean, zero-dependency shell runner

set -euo pipefail

MODULE_DIR="."
MODULE_DIR="example"
QUIET=false
VERIFY_ONLY=false

# --- CLI Options Parser ---
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
		echo "  -d, --dir <path>      Path to module directory (default: .)"
    echo "  -q, --quiet           Silent execution unless an error occurs"
    echo "  --verify-only         Compliance audit mode: execute read-only verification checks"
    echo "  -h, --help            Show help"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
				-d|--dir) MODULE_DIR="$2"; shift 2 ;;
        -q|--quiet) QUIET=true; shift ;;
        --verify-only) VERIFY_ONLY=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

log() {
    if [[ "$QUIET" == false ]]; then
        echo -e "$@"
    fi
}

log_err() {
    echo -e "$@" >&2
}

# --- 1. Load & Validate Manifest File ---
MANIFEST="$MODULE_DIR/.yana.json"
if [[ ! -f "$MANIFEST" ]]; then
    log_err "[ERROR] Manifest file '$MANIFEST' not found."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    log_err "[ERROR] Prerequisite tool 'jq' is missing on host node."
    exit 1
fi

# --- 2. Pre-flight Check Phase ---
requires_count=$(jq -r '(.requires // []) | length' "$MANIFEST")
missing_deps=()

for (( i=0; i<requires_count; i++ )); do
    req=$(jq -r ".requires[$i]" "$MANIFEST")
    if ! command -v "$req" &>/dev/null; then
        missing_deps+=("$req")
    fi
done

if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_err "[PRE-FLIGHT FAILED] Missing target dependencies: ${missing_deps[*]}"
    exit 1
fi

MODULES_DIR="$MODULE_DIR/.yana"
# --- 3. Load Resource Modules ---
if [[ -d "$MODULES_DIR" ]]; then
    for module_script in "$MODULES_DIR"/*.sh; do
        if [[ -f "$module_script" ]]; then
            # shellcheck source=/dev/null
            source "$module_script"
        fi
    done
fi

# --- Helper: Dynamic Variable Resolver ---
resolve_vars() {
    local val="$1"

    # Resolve ${param:param_name}
    while [[ "$val" =~ \$\{param:([a-zA-Z0-9_]+)\} ]]; do
        local p_name="${BASH_REMATCH[1]}"
        local p_val
        p_val=$(jq -r ".params[\"$p_name\"] // \"\"" "$MANIFEST")
        val="${val//\$\{param:$p_name\}/$p_val}"
    done

    # Resolve ${env:ENV_VAR}
    while [[ "$val" =~ \$\{env:([a-zA-Z0-9_]+)\} ]]; do
        local e_name="${BASH_REMATCH[1]}"
        local e_val="${!e_name:-}"
        val="${val//\$\{env:$e_name\}/$e_val}"
    done

    # Resolve ${var:key}
    while [[ "$val" =~ \$\{var:([a-zA-Z0-9_]+)\} ]]; do
        local sys_key="${BASH_REMATCH[1]}"
        local sys_val=""
        case "$sys_key" in
            time) sys_val=$(date +%s) ;;
            iso_time) sys_val=$(date -u +"%Y-%m-%dT%H:%M:%SZ") ;;
            uid) sys_val=$(id -u) ;;
            user) sys_val=$(whoami) ;;
            hostname) sys_val=$(hostname) ;;
            is_root) [[ $(id -u) -eq 0 ]] && sys_val="true" || sys_val="false" ;;
            *) sys_val="" ;;
        esac
        val="${val//\$\{var:$sys_key\}/$sys_val}"
    done

    echo "$val"
}

# --- 4. Core Execution Loop ---
steps_count=$(jq -r '(.steps // []) | length' "$MANIFEST")

log "=== YANA Engine Execution Target: $MANIFEST ==="
if [[ "$VERIFY_ONLY" == true ]]; then
    log "Mode: Compliance Audit (--verify-only)"
fi

for (( i=0; i<steps_count; i++ )); do
    step_json=$(jq -c ".steps[$i]" "$MANIFEST")
    step_name=$(echo "$step_json" | jq -r '.name // "step_'$i'"')
    action=$(echo "$step_json" | jq -r '.action')

    raw_args=$(echo "$step_json" | jq -r '.args // {} | to_entries | map("\(.key)=\(.value|@text | @sh)") | join(" ") ')

    resolved_args=$(resolve_vars "$raw_args")

		main_func="YANAaction:${action}"
		apply_func="${main_func}:apply"
    verify_func="${main_func}:verify"

    start_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))

    # Idempotency Safeguard: Pre-execution state verification
    already_satisfied=false
    if declare -f "$verify_func" > /dev/null; then
        # if "$verify_func" "${resolved_args[@]}" &>/dev/null; then
        if ( eval "$resolved_args"; "$verify_func" &>/dev/null ); then
            already_satisfied=true
        fi
    fi

    if [[ "$already_satisfied" == true ]]; then
        log "  - [SKIPPED] $step_name (state already satisfied)"
        continue
    fi

    # Read-Only Compliance Mode
    if [[ "$VERIFY_ONLY" == true ]]; then
        if declare -f "$verify_func" > /dev/null; then
            log_err "  - [NON-COMPLIANT] $step_name (state verification failed in audit mode)"
            exit 1
        else
            log "  - [SKIPPED] $step_name (no verification function provided)"
            continue
        fi
    fi

    # Check function presence
    if ! declare -f "$apply_func" > /dev/null; then
        log_err "  - [FAILED] $step_name (action '$action' not found in modules)"
        exit 1
    fi

    # Mutating State Change
    exec_output=""
    set +e
    exec_output=$( eval "$resolved_args"; "$apply_func" 2>&1)
    exit_code=$?
    set -e

    if [[ $exit_code -ne 0 ]]; then
        log_err "  - [FAILED] $step_name (exit code: $exit_code)"
        if [[ -n "$exec_output" ]]; then
            log_err "    Details: $exec_output"
        fi
        exit $exit_code
    fi

    # Post-execution Validation
    if declare -f "$verify_func" > /dev/null; then
        post_verify_code=0

        ( set +e; eval "$resolved_args"; "$verify_func" &>/dev/null ) || post_verify_code=$?
        if [[ $post_verify_code -ne 0 ]]; then
            log_err "  - [FAILED] $step_name (post-action state verification failed)"
            exit 1
        fi
    fi

    end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
    elapsed=$((end_time - start_time))

    log "  - [OK] $step_name (elapsed: ${elapsed}ms)"
done

log "=== YANA Execution Completed Successfully ==="
