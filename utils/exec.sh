source $MY_PATH/utils/log.sh

func_exec_bash() {
	func_log_debug "Executing bash: \"$*\""
	bash -c "$*"
	ret=$?
	func_log_debug "Return code: $ret"
	return $ret
}

func_exec_cmd_indir() {
	cmd="$1"
	dir="$2"
	func_log_debug "Executing command \"$1\" in directory \"$2\""
	OLD_PWD="$PWD"
	if [ -d "$2" ]; then
		cd "$2"
		eval "$cmd"
		ret=$?
		cd "$OLD_PWD"
	else
		func_log_error "Directory $2 does not exist!"
	fi
	func_log_debug "Return code: $ret"
	return $?
}
