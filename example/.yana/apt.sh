# Module: apt package actions

YANAverify:apt.install() {
	local package="${1:-$package}"
	dpkg -s "$package" &>/dev/null
}

YANAapply:apt.install() {
	local package="${1:-$package}"
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq && apt-get install -y -qq "$package"
}
