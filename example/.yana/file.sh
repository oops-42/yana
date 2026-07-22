#!/usr/bin/env bash
# Module: file actions

YANAapply:file.write() {
	local path="${YANAargs[path]}"
	local content="${YANAargs[content]}"
	local owner="${YANAargs[owner]}"
	[ -z "$path" ] && {
		echo "Error: 'path' argument is required for file.write action" >&2
		return 1
	}

	mkdir -p "$(dirname "$path")"
	echo "$content" >"$path"

	if [[ -n $owner ]]; then
		chown "$owner" "$path" 2>/dev/null || true
	fi
}
YANAverify:file.write() {
	local path="${YANAargs[path]}"
	local content="${YANAargs[content]}"
	local owner="${YANAargs[owner]}"
	[ -z "$path" ] && return 1

	# Return 0 if file exists and matches content
	[[ -f $path ]] && [[ "$(cat "$path")" == "$content" ]] && {
		if [[ -n $owner ]]; then
			local current_owner
			current_owner=$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path" 2>/dev/null)
			[[ "$current_owner" == "$owner" ]] && return 0
		else
			return 0
		fi
	}
}
