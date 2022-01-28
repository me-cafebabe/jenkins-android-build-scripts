source $MY_PATH/utils/log.sh
source $MY_PATH/utils/exec.sh

func_git_cleanup() {
	repo="$1"
	func_log_debug "Cleanup git repo: $repo"
	func_exec_bash "cd $repo && git clean -f && git reset --hard"
	return $?
}
