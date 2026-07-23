if ! command -v apk &>/dev/null; then
  echo "apk command not found. Please install Alpine Linux package manager." >&2
  return 1
fi

YANAapply_install() {
	local package="${YANAargs[package]}"
	apk add --no-cache "$package"
}

YANAverify_install() {
	local package="${YANAargs[package]}"
	[[ -z "$package" ]] && yana_throw "'package' argument is required for apk.install action" $ERR_MISUSE
  apk info "$package" &>/dev/null || return 1
}
