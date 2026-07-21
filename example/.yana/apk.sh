# Module: apk package actions

YANAverify:apk.install() {
  local package="${1:-$package}"
  apk info "$package" &>/dev/null
}

YANAapply:apk.install() {
  local package="${1:-$package}"
  apk add --no-cache "$package"
}
