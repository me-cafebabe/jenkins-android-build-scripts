func_validate_codename() {
	str="$1"
#	if [ "$str" =~ '^[a-zA-Z0-9|_|-]+$' ]; then
	if echo "$str"|grep -E "^[a-zA-Z0-9|_|-]+$" > /dev/null; then
		return 0
	else
		return 1
	fi
}

func_validate_modulename() {
	str="$1"
	if echo "$str"|grep -E "^[a-zA-Z0-9|_|-|@|\.]+$" > /dev/null; then
		return 0
	else
		return 1
	fi
}

func_validate_parameter_value() {
	case "${2}" in
		-*)
			func_abort_with_msg "Invalid value for parameter ${1}: ${2}"
			;;
	esac
}
