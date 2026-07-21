# Module: apt package actions

YANAaction:apt.install:verify() {
    local package="${1:-$package}"
    dpkg -s "$package" &>/dev/null
}

YANAaction:apt.install:apply() {
    local package="${1:-$package}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq "$package"
}
