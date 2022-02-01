source $MY_PATH/utils/log.sh

func_sanitize_var_default() {
	var_name="$1"
	default_value="$2"

	if [ $(eval 'printf 1$'$var_name) == "1" ] ; then
		func_log_info "Variable $var_name is blank! Setting default value $default_value"
		eval $var_name"='${default_value}'"
	fi
}

func_sanitize_var_path() {
	var_name="$1"

	orig_path=$(eval 'echo $'${var_name})
	if ! [ -z "$orig_path" ]; then
		new_path="$(realpath "$orig_path")"
		eval $var_name"='${new_path}'"
	fi
}

func_sanitize_var_command() {
	var_name="$1"

	orig_cmd=$(eval 'echo $'${var_name})
	new_cmd=$(echo $orig_cmd|sed 's|\;|\\\;|g;s|(|\\(|g;s|)|\\)|g;s|\||\\\||g;s|&|\\&|g;s|\$|\\\$|g;s|`|\\`|g;s|#|\\#|g;s|\\|\\\\|g')
	if ! [ -z "$orig_cmd" ]; then
		eval $var_name"='${new_cmd}'"
	fi
}
