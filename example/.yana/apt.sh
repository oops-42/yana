for cmd in apt-get dpkg; do
	if ! command -v "$cmd" &>/dev/null; then
		echo "$cmd command not found. Please ensure APT is installed." >&2
		return 1
	fi
done

export DEBIAN_FRONTEND=noninteractive

YANAapply_update() {
	apt-get update -qq
}

YANAapply_clean() {
	apt-get clean
}

YANAapply_upgrade() {
	apt-get upgrade -y -qq
}

YANAverify_upgrade() {
	# Check if there are any packages that can be upgraded
	apt list --upgradable 2>/dev/null | grep -q 'upgradable' || return 1
}

YANAapply_remove() {
	local package="${YANAargs[package]}"
	apt-get remove -y -qq "$package"
}

YANAverify_remove() {
	local package="${YANAargs[package]}"
	[[ -z "$package" ]] && yana_throw "'package' argument is required for apt.remove action" $ERR_MISUSE
	dpkg -s "$package" &>/dev/null || return 0
	return 1
}

YANAapply_install() {
	local package="${YANAargs[package]}"
	apt-get install -y -qq "$package"
}

YANAverify_install() {
	local package="${YANAargs[package]}"
	[[ -z "$package" ]] && yana_throw "'package' argument is required for apt.install action" $ERR_MISUSE
  dpkg -s "$package" &>/dev/null || return 1
}
