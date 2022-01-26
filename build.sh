#!/bin/bash

MY_PATH=$(dirname $(realpath "$0"))

source $MY_PATH/utils/init.sh
source $MY_PATH/utils/log.sh
source $MY_PATH/utils/exec.sh
source $MY_PATH/utils/abort.sh
source $MY_PATH/utils/sanitize.sh
source $MY_PATH/utils/validate.sh

# Print help text
func_help() {
    echo "Required parameters or variables:"
    echo "  --target | TARGET: Build Target"
    echo "  --tree-path | TREE_PATH: Path to the ROM tree"
    echo
    echo "Ccache options:"
    echo "  --ccache-dir | CCACHE_DIR: ccache Directory"
    echo "  --ccache-size | CCACHE_SIZE: ccache Size"
    echo
    echo "Optional:"
    echo "  --build-method | BUILD_METHOD: mka_bacon or brunch_target"
    echo "  --out-dir | OUT_DIR: Output Directory"
    echo "  --out-soong-dir | OUT_SOONG_DIR: Out soong Directory"
    echo "  --out-soong-is-symlink | OUT_SOONG_IS_SYMLINK: Indicating if out/soong is symlink"
    echo "  --allow-vendorsetup-sh | ALLOW_VENDORSETUP_SH: Allow vendorsetup.sh"
    echo "  --cleanup-out-target | CLEANUP_OUT_TARGET: Allow vendorsetup.sh"
    echo
    echo "Misc:"
    echo "  --env-script | ENV_SCRIPT: Script to load environment variables"
    echo "  --dry-run | DRY_RUN: Skip starting the build"
    echo "  --help: Print this help text."
}

if [ -z "$@" ]; then
    func_help
    exit 0
fi

# Parameters
while [ "${#}" -gt 0 ]; do
    case "${1}" in
        # Required
        --target )
            func_validate_parameter_value "${1}" "${2}"
            TARGET="${2}"
            shift
            shift
            ;;
        --tree-path )
            func_validate_parameter_value "${1}" "${2}"
            TREE_PATH="${2}"
            shift
            shift
            ;;
        # ccache
        --ccache-dir )
            func_validate_parameter_value "${1}" "${2}"
            CCACHE_DIR="${2}"
            shift
            shift
            ;;
        --ccache-size )
            func_validate_parameter_value "${1}" "${2}"
            CCACHE_SIZE="${2}"
            shift
            shift
            ;;
        # optional
        --build-method )
            func_validate_parameter_value "${1}" "${2}"
            BUILD_METHOD="${2}"
            shift
            shift
            ;;
        --out-dir )
            func_validate_parameter_value "${1}" "${2}"
            OUT_DIR="${2}"
            shift
            shift
            ;;
        --out-soong-dir )
            func_validate_parameter_value "${1}" "${2}"
            OUT_SOONG_DIR="${2}"
            shift
            shift
            ;;
        --out-soong-is-symlink )
            OUT_SOONG_IS_SYMLINK="true"
            shift
            ;;
        # optional bools
        --allow-vendorsetup-sh )
            ALLOW_VENDORSETUP_SH="true"
            shift
            ;;
        --cleanup-out-target )
            CLEANUP_OUT_TARGET="true"
            shift
            ;;
        # misc
        --env-script )
            func_validate_parameter_value "${1}" "${2}"
            ENV_SCRIPT="${2}"
            if ! [ -f "$ENV_SCRIPT" ]; then
                func_abort_with_msg "Environment script $ENV_SCRIPT is not accessible!"
            fi
            shift
            shift
            ;;
        --dry-run )
            DRY_RUN="true"
            shift
            ;;
        --help )
            func_help
            exit 0
            ;;
        -*)
            func_abort_with_msg "Unknown parameter: $1"
            ;;
        *)
            shift
            ;;
    esac
done

# Load or override variables from env script
if [ -f "$ENV_SCRIPT" ]; then
    source $ENV_SCRIPT
fi

# Print info
func_log_vars "TARGET" "TREE_PATH" "CCACHE_DIR" "CCACHE_SIZE" \
    "BUILD_METHOD" "OUT_DIR" "OUT_SOONG_DIR" "OUT_SOONG_IS_SYMLINK" \
    "ALLOW_VENDORSETUP_SH" "CLEANUP_OUT_TARGET" "ENV_SCRIPT" "DRY_RUN"

# Variable sanitization
func_abort_if_blank_param_or_var "--target" "TARGET"
if ! func_validate_codename "$TARGET"; then
    func_abort_with_msg "Invalid target: $TARGET"
fi
func_abort_if_blank_param_or_var "--tree-path" "TREE_PATH"
if ! [ -f "$TREE_PATH/build/make/envsetup.sh" ]; then
    func_abort_with_msg "Tree path $TREE_PATH is invalid!"
fi
if [ -z "$OUT_DIR" ]; then
    OUT_DIR="$TREE_PATH/out"
    if ! [ -d "$OUT_DIR" ]; then
        if ! func_exec_bash "mkdir -p $OUT_DIR"; then
            func_abort_with_msg "Failed to create directory $TREE_PATH/out !"
        fi
    fi
else
    if ! [ -d "$OUT_DIR" ]; then
        func_abort_with_msg "Out dir $OUT_DIR is invalid!"
    fi
fi
if [ "$OUT_SOONG_IS_SYMLINK" == "true" ]; then
    if ! [ -d "$OUT_SOONG_DIR" ]; then
        func_abort_with_msg "Out soong dir $OUT_SOONG_DIR is invalid!"
    fi
    if [ -s "$OUT_DIR/soong" ]; then
        if [ -L "$OUT_DIR/soong" ]; then
            if [ "$(realpath `readlink $OUT_DIR/soong`)" != "$(realpath $OUT_SOONG_DIR)" ]; then
                func_log_warn "out/soong symlink is pointed to $(readlink ${OUT_DIR}/soong), not ${OUT_SOONG_DIR}, correcting it"
                func_exec_bash "rm $OUT_DIR/soong && ln -sf $OUT_SOONG_DIR $OUT_DIR/soong"
            fi
        else
            func_abort_with_msg "out/soong exists and is NOT a symlink!"
        fi
    else
        func_log_info "out/soong symlink does not exist, creating it"
        func_exec_bash "ln -sf $OUT_SOONG_DIR $OUT_DIR/soong"
    fi
else
    OUT_SOONG_DIR="$OUT_DIR/soong"
fi
if ! [ -z "$CCACHE_SIZE" ]; then
    func_abort_if_blank_param_or_var "--ccache-dir" "CCACHE_DIR"
    if ! [ -d "$CCACHE_DIR" ]; then
        func_abort_with_msg "ccache dir $CCACHE_DIR is invalid!"
    fi
fi
case "$BUILD_METHOD" in
    mka_bacon|brunch_target)
        ;;
    "")
        BUILD_METHOD="brunch_target"
        ;;
    *)
        func_abort_with_msg "Invalid build method: $BUILD_METHOD"
        ;;
esac

func_sanitize_var_path "CCACHE_DIR"
func_sanitize_var_path "ENV_SCRIPT"
func_sanitize_var_path "OUT_DIR"
func_sanitize_var_path "OUT_SOONG_DIR"
func_sanitize_var_path "TREE_PATH"

# Print info
func_log_vars "TARGET" "TREE_PATH" "CCACHE_DIR" "CCACHE_SIZE" \
    "BUILD_METHOD" "OUT_DIR" "OUT_SOONG_DIR" "OUT_SOONG_IS_SYMLINK" \
    "ALLOW_VENDORSETUP_SH" "CLEANUP_OUT_TARGET" "ENV_SCRIPT" "DRY_RUN"

# Preparation
if [ "$ALLOW_VENDORSETUP_SH" == "true" ]; then
    func_log_info "vendorsetup.sh is allowed. Removing device/allowed-vendorsetup_sh-files"
    func_exec_bash "cd $TREE_PATH && rm device/allowed-vendorsetup_sh-files; exit 0"
else
    func_log_info "vendorsetup.sh is disallowed. Creating device/allowed-vendorsetup_sh-files"
    func_exec_bash "cd $TREE_PATH && touch device/allowed-vendorsetup_sh-files"
fi
if [ "$CLEANUP_OUT_TARGET" == "true" ]; then
    func_log_info "Cleaning up out target directory."
    func_exec_bash "rm -rf $OUT_DIR/target/product/$TARGET"
fi

# Generate build command
func_log_border
BUILD_CMD+="cd ${TREE_PATH}"
BUILD_CMD+=" && export LC_ALL=C"
if ! [ -z "$CCACHE_SIZE" ]; then
    BUILD_CMD+=" && export USE_CCACHE=1 CCACHE_DIR=${CCACHE_DIR}"
    BUILD_CMD+=" && ccache -M ${CCACHE_SIZE}"
fi
BUILD_CMD+=" && source build/envsetup.sh"
case "$BUILD_METHOD" in
    mka_bacon)
        BUILD_CMD+=" && breakfast ${TARGET} && mka bacon"
        ;;
    brunch_target)
        BUILD_CMD+=" && brunch ${TARGET}"
        ;;
esac
func_log_info "Generated build command: \"${BUILD_CMD}\""

# Dry run
if [ "$DRY_RUN" == "true" ]; then exit ; fi

# Run the build
func_log_border
func_log_info "Starting the build."
func_exec_bash "${BUILD_CMD}"
exit $?