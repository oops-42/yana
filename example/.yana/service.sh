if ! command -v service &>/dev/null; then
	echo "service command not found. Please ensure sysvinit is installed." >&2
	return 1
fi

YANAapply_start() {
	local name="${YANAargs[name]}"
	service "$name" start
}

YANAverify_start() {
	local name="${YANAargs[name]}"
	[[ -z "$name" ]] && yana_throw "'name' argument is required for service.start action" $ERR_MISUSE
	service "$name" status &>/dev/null || return 1
}

YANAapply_stop() {
	local name="${YANAargs[name]}"
	service "$name" stop
}

YANAverify_stop() {
	local name="${YANAargs[name]}"
	[[ -z "$name" ]] && yana_throw "'name' argument is required for service.stop action" $ERR_MISUSE
	service "$name" status &>/dev/null || return 0
	return 1
}

YANAapply_restart() {
	local name="${YANAargs[name]}"
	[[ -z "$name" ]] && yana_throw "'name' argument is required for service.restart action" $ERR_MISUSE
	service "$name" restart
}

YANAapply_reload() {
	local name="${YANAargs[name]}"
	[[ -z "$name" ]] && yana_throw "'name' argument is required for service.reload action" $ERR_MISUSE
	service "$name" reload
}
