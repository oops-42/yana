if ! command -v apk &>/dev/null; then
  echo "apk command not found. Please install Alpine Linux package manager."
  return 1
fi

YANAapply_install() {
	local package="${YANAargs[package]}"
  apk add --no-cache "$package"
}

YANAverify_install() {
	local package="${YANAargs[package]}"
  apk info "$package" &>/dev/null
}
