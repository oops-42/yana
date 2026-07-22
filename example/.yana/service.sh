#!/usr/bin/env bash
# Module: service management actions

YANAverify:service.start() {
	local name="${YANAargs[name]}"
	systemctl is-active --quiet "$name"
}

YANAapply:service.start() {
	local name="${YANAargs[name]}"
	systemctl start "$name"
}
