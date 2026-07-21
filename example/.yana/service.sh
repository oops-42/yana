#!/usr/bin/env bash
# Module: service management actions

YANAverify:service.start() {
	local name="${1:-$name}"
	systemctl is-active --quiet "$name"
}

YANAapply:service.start() {
	local name="${1:-$name}"
	systemctl start "$name"
}
