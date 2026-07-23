for cmd in apt-get dpkg; do
	if ! command -v "$cmd" &>/dev/null; then
		echo "$cmd command not found. Please ensure APT is installed." >&2
		return 1
	fi
done

YANAapply_install() {
	local package="${YANAargs[package]}"
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq && apt-get install -y -qq "$package"
}

YANAverify_install() {
	local package="${YANAargs[package]}"
  dpkg -s "$package" &>/dev/null
}
