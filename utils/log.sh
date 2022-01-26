func_log_info() {
	echo "[INFO] $*"
}

func_log_warn() {
	echo "[WARN] $*"
}

func_log_error() {
	echo "[ERROR] $*"
}

func_log_debug() {
	if [ "$DEBUG" == "true" ]; then
		echo "[DEBUG] $*"
	fi
}

func_log_border() {
	echo "##################################################"
}

func_log_vars() {
	func_log_border
	for var in $*; do
		echo "[${var}]=[$(eval echo '$'${var})]"
	done | sort
	func_log_border
}
