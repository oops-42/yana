if ! command -v apk &>/dev/null; then
  throw "apk command not found. Please install Alpine Linux package manager." $ERR_GENERAL
fi

yanaapply_install() {
	local package="${YANA_ARGS[package]:-}"
	apk add --no-cache "$package"
}

yanaverify_install() {
	local package="${YANA_ARGS[package]:-}"
	[[ -z "$package" ]] && throw "'package' argument is required for apk.install action" $ERR_MISUSE
  apk info "$package" &>/dev/null || return 1
}
