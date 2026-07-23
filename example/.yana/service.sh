if ! command -v systemctl &>/dev/null; then
	echo "systemctl command not found. Please ensure systemd is installed."
	return 1
fi

YANAapply_start() {
	local name="${YANAargs[name]}"
	systemctl start "$name"
}

YANAverify_start() {
	local name="${YANAargs[name]}"
	systemctl is-active --quiet "$name"
}
