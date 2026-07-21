# Module: apt package actions

YANAaction:apk.install:verify() {
    local package="${1:-$package}"
    apk info "$package" &>/dev/null
}

YANAaction:apk.install:apply() {
    local package="${1:-$package}"
    apk add --no-cache "$package"
}
