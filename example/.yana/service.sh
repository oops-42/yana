if ! command -v service &>/dev/null; then
	yana_throw "service command not found. Please ensure sysvinit is installed." $ERR_GENERAL
fi

yanaapply_start() {
	local name="${YANA_ARGS[name]:-}"
	service "$name" start
}

yanaverify_start() {
	local name="${YANA_ARGS[name]:-}"
	[[ -z "$name" ]] && yana_throw "'name' argument is required for service.start action" $ERR_MISUSE
	service "$name" status &>/dev/null || return 1
}

yanaapply_stop() {
	local name="${YANA_ARGS[name]:-}"
	service "$name" stop
}

yanaverify_stop() {
	local name="${YANA_ARGS[name]:-}"
	[[ -z "$name" ]] && yana_throw "'name' argument is required for service.stop action" $ERR_MISUSE
	service "$name" status &>/dev/null || return 0
	return 1
}

yanaapply_restart() {
	local name="${YANA_ARGS[name]:-}"
	[[ -z "$name" ]] && yana_throw "'name' argument is required for service.restart action" $ERR_MISUSE
	service "$name" restart
}

yanaapply_reload() {
	local name="${YANA_ARGS[name]:-}"
	[[ -z "$name" ]] && yana_throw "'name' argument is required for service.reload action" $ERR_MISUSE
	service "$name" reload
}
