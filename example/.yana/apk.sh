# Module: apk package actions

YANAverify:apk.install() {
	local package="${YANAargs[package]}"
  apk info "$package" &>/dev/null
}

YANAapply:apk.install() {
	local package="${YANAargs[package]}"
  apk add --no-cache "$package"
}
