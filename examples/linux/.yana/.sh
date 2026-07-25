# This file defines the common variables and functions for all actions in the module.

hello='world'

yanavar_uid() { id -u; }
yanavar_gid() { id -g; }
yanavar_user() { id -un; }
yanavar_group() { id -gn; }
yanavar_groups() { id -Gn; }
yanavar_hostname() { hostname; }
yanavar_os() { uname -s; }
yanavar_is_root() { if [[ $(id -u) -eq 0 ]]; then
	echo true
	true
else
	echo false
	false
fi; }
yanavar_uuid() { cat /proc/sys/kernel/random/uuid; }
yanavar_time() { date +%s; }
yanavar_iso_time() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
