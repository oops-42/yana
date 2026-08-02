# This file defines the common variables and functions for all actions in the module.

yanavar_uid() { id -u; }
yanavar_gid() { id -g; }
yanavar_user() { id -un; }
yanavar_group() {
	id -gn; }
yanavar_groups() { id -Gn; }
yanavar_hostname() { hostname; }
yanavar_os() { uname -s; }
yanavar_is_root() { if [[ $(id -u) -eq 0 ]]; then echo true; else echo false; fi; }
yanavar_uuid() { cat /proc/sys/kernel/random/uuid; }
yanavar_time() {
	local format="${YANA_ARGS[format]:-}" utc="${YANA_ARGS[utc]:-}"
	[[ -n $utc ]] && utc='-u'
	if [[ -n $format ]]; then
		date "$utc" +"$format"
	else
		date "$utc" +%s
	fi
}
yanavar_iso_time() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
