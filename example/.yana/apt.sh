for cmd in apt-get dpkg; do
	if ! command -v "$cmd" &>/dev/null; then
		yana_throw "Error: '$cmd' command not found. Please ensure APT is installed." $ERR_GENERAL
	fi
done

export DEBIAN_FRONTEND=noninteractive

yanaapply_update() {
	apt-get update -qq
}

yanaapply_clean() {
	apt-get clean
}

yanaapply_upgrade() {
	apt-get upgrade -y -qq
}

yanaverify_upgrade() {
	# Check if there are any packages that can be upgraded
	apt list --upgradable 2>/dev/null | grep -q 'upgradable' && return 1
}

yanaapply_remove() {
	local package="${YANA_ARGS[package]:-}"
	apt-get remove -y -qq "$package"
}

yanaverify_remove() {
	local package="${YANA_ARGS[package]:-}"
	[[ -z $package ]] && yana_throw "'package' argument is required for apt.remove action" $ERR_MISUSE
	dpkg -s "$package" &>/dev/null && return 1

}

yanaapply_install() {
	local package="${YANA_ARGS[package]:-}"
	apt-get install -y -qq "$package"
}

yanaverify_install() {
	local package="${YANA_ARGS[package]:-}"
	[[ -z $package ]] && yana_throw "'package' argument is required for apt.install action" $ERR_MISUSE
	dpkg -s "$package" &>/dev/null || return 1
}
