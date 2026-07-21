#!/usr/bin/env bash
# Module: file actions

YANAapply:file.write() {
	local path="${1:-$path}"
	local content="${2:-$content}"
	local owner="${3:-$owner}"

	mkdir -p "$(dirname "$path")"
	echo "$content" >"$path"

	if [[ -n $owner ]]; then
		chown "$owner" "$path" 2>/dev/null || true
	fi
}
YANAverify:file.write() {
	local path="${1:-$path}"
	local content="${2:-$content}"

	# Return 0 if file exists and matches content
	[[ -f $path ]] && [[ "$(cat "$path")" == "$content" ]]
}
