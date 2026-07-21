#!/usr/bin/env bash
# Module: service management actions

YANAaction:service.start:verify() {
    local name="${1:-$name}"
    systemctl is-active --quiet "$name"
}

YANAaction:service.start:apply() {
    local name="${1:-$name}"
    systemctl start "$name"
}
