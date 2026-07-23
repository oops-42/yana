yanaverify_create() {
	local path="${YANA_ARGS[path]:-}"
	[[ -z $path ]] && yana_throw "Error: 'path' argument is required for file.create action" $ERR_MISUSE

	# Return 1 if file not exists
	[[ -f $path ]] || return 1
}
yanaapply_create() {
	local path="${YANA_ARGS[path]:-}"
	local content="${YANA_ARGS[content]:-}"
	local owner="${YANA_ARGS[owner]:-}"

	mkdir -p "$(dirname "$path")"
	echo -n "$content" >"$path"

	if [[ -n $owner ]]; then
		chown "$owner" "$path"
	fi
}

yanaapply_write() {
	local path="${YANA_ARGS[path]:-}"
	local content="${YANA_ARGS[content]:-}"
	local owner="${YANA_ARGS[owner]:-}"

	mkdir -p "$(dirname "$path")"
	echo "$content" >"$path"

	if [[ -n $owner ]]; then
		chown "$owner" "$path"
	fi
}

yanaverify_write() {
	local path="${YANA_ARGS[path]:-}"
	local content="${YANA_ARGS[content]:-}"
	local owner="${YANA_ARGS[owner]:-}"
	[[ -z $path ]] && yana_throw "Error: 'path' argument is required for file.write action" $ERR_MISUSE

	# Return 0 if file exists and matches content
	[[ -f $path ]] || return 1
	[[ "$(cat "$path")" == "$content" ]] || return 1
	if [[ -n $owner ]]; then
		local current_owner
		if [[ $owner == *:* ]]; then
			current_owner=$(stat -c '%U:%G' "$path" 2>/dev/null || stat -f '%Su:%Sg' "$path" 2>/dev/null)
		else
			current_owner=$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path" 2>/dev/null)
		fi
		[[ $current_owner == "$owner" ]] || return 1
	fi
}

yanaapply_read() {
	local path="${YANA_ARGS[path]:-}"
	[[ -z $path ]] && yana_throw "Error: 'path' argument is required for file.read action" $ERR_MISUSE
	[[ -d $path ]] && yana_throw "Error: '$path' is a directory, expected a file for file.read action" $ERR_DATA_FORMAT
	[[ -f $path ]] || yana_throw "Error: File '$path' does not exist for file.read action" $ERR_NO_INPUT
	cat "$path"
}
