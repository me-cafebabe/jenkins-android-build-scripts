source $MY_PATH/utils/log.sh


func_abort_with_msg() {
	msg="$*"
	func_log_error "$*"
	func_log_error "Aborting."
	exit 1
}

func_abort_if_blank_param() {
	val="$1"
	param_name="$2"

	if [ -z "$val" ]; then
		func_abort_with_msg "Parameter $param_name must be specified!"
	fi
}

func_abort_if_blank_var() {
	var_name="$1"

	if [ $(eval 'printf 1$'$name) == "1" ] ; then
		func_abort_with_msg "Variable $var_name must be specified!"
	fi
}

func_abort_if_blank_param_or_var() {
	param_name="$1"
	var_name="$2"

	if [ $(eval 'printf 1$'$var_name) == "1" ] ; then
		func_abort_with_msg "Variable $var_name or parameter $param_name must be specified!"
	fi
}
