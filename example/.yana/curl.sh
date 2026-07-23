if ! command -v curl >/dev/null 2>&1; then
	yana_throw "Error: 'curl' command not found. Please install curl to use the curl.request action." $ERR_GENERAL
fi

yanaapply_request() {
	local url="${YANA_ARGS[url]:-}"
	local method="${YANA_ARGS[method]:-GET}"
	local headers="${YANA_ARGS[headers]:-}"
	local data="${YANA_ARGS[data]:-}"
	local output_file="${YANA_ARGS[output_file]:-}"

	[[ -z $url ]] && yana_throw "Error: 'url' argument is required for curl.request action" $ERR_MISUSE

	# Prepare curl command
	local curl_cmd=("curl" "-sS" "-X" "$method")

	# Add headers if provided
	if [[ -n $headers ]]; then
		while IFS= read -r header; do
			curl_cmd+=("-H" "$header")
		done <<< "$headers"
	fi

	# Add data if provided
	if [[ -n $data ]]; then
		curl_cmd+=("-d" "$data")
	fi

	# Add URL
	curl_cmd+=("$url")

	# Execute curl command and handle output
	if [[ -n $output_file ]]; then
		mkdir -p "$(dirname "$output_file")"
		"${curl_cmd[@]}" >"$output_file"
	else
		"${curl_cmd[@]}"
	fi
}
