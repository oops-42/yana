YANAverify_create() {
	local path="${YANAargs[path]}"
	[[ -z "$path" ]] && yana_throw "Error: 'path' argument is required for file.create action" $ERR_MISUSE

	# Return 1 if file not exists
	[[ -f $path ]] || return 1
}
YANAapply_create() {
	local path="${YANAargs[path]}"
	local content="${YANAargs[content]}"
	local owner="${YANAargs[owner]}"

	mkdir -p "$(dirname "$path")"
	echo -n "$content" >"$path"

	if [[ -n $owner ]]; then
		chown "$owner" "$path"
	fi
}

YANAapply_write() {
	local path="${YANAargs[path]}"
	local content="${YANAargs[content]}"
	local owner="${YANAargs[owner]}"

	mkdir -p "$(dirname "$path")"
	echo "$content" >"$path"

	if [[ -n $owner ]]; then
		chown "$owner" "$path"
	fi
}

YANAverify_write() {
	local path="${YANAargs[path]}"
	local content="${YANAargs[content]}"
	local owner="${YANAargs[owner]}"
	[[ -z "$path" ]] && yana_throw "Error: 'path' argument is required for file.write action"  $ERR_MISUSE

	# Return 0 if file exists and matches content
	[[ -f $path ]] && [[ "$(cat "$path")" == "$content" ]] && {
		if [[ -n $owner ]]; then
			local current_owner
			current_owner=$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path" 2>/dev/null)
			[[ $current_owner == "$owner" ]] && return 0
		else
			return 0
		fi
	}
}

YANAapply_read() {
	local path="${YANAargs[path]}"
	[[ -z "$path" ]] && yana_throw "Error: 'path' argument is required for file.read action"  $ERR_MISUSE
	[[ -d "$path" ]] && yana_throw "Error: '$path' is a directory, expected a file for file.read action" $ERR_DATA_FORMAT
	[[ -f "$path" ]] || yana_throw "Error: File '$path' does not exist for file.read action" $ERR_NO_INPUT
	cat "$path"
}
