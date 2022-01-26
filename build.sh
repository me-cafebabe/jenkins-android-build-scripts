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
    echo "  --device | DEVICE: Target device"
    echo "  --tree-path | TREE_PATH: Path to the ROM tree"
    echo
    echo "Ccache options:"
    echo "  --ccache-dir | CCACHE_DIR: ccache Directory"
    echo "  --ccache-size | CCACHE_SIZE: ccache Size"
    echo
    echo "Optional:"
    echo "  --allow-missing-dependencies | ALLOW_MISSING_DEPENDENCIES: Allow missing dependencies"
    echo "  --allow-vendorsetup-sh | ALLOW_VENDORSETUP_SH: Allow vendorsetup.sh"
    echo "  --build-method | BUILD_METHOD: Build Method. Value can be mka_bacon or brunch_target"
    echo "  --build-module | BUILD_MODULE: Build specific module. (make -j$(nproc) MODULE)"
    echo "  --build-target | BUILD_TARGET: Build Target. (e.g. vendorimage or recoveryimage)"
    echo "  --cleanup-out-device | CLEANUP_OUT_DEVICE: Cleanup out device directory"
    echo "  --out-dir | OUT_DIR: Output Directory"
    echo "  --out-soong-dir | OUT_SOONG_DIR: Out soong Directory"
    echo "  --out-soong-is-symlink | OUT_SOONG_IS_SYMLINK: Indicating if out/soong is symlink"
    echo "  --workspace | WORKSPACE: Jenkins Workspace Directory, for uploading artifacts"
    echo "  --workspace-copy | WORKSPACE_COPY: Copy out target files to workspace directory. Specify this like \"{vendor/build.prop,lineage-18.1-*.zip,boot.img}\""
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

# Disable globbing
set -f

# Parameters
while [ "${#}" -gt 0 ]; do
    case "${1}" in
        # Required
        --device )
            func_validate_parameter_value "${1}" "${2}"
            DEVICE="${2}"
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
        --build-module )
            func_validate_parameter_value "${1}" "${2}"
            BUILD_MODULE="${2}"
            shift
            shift
            ;;
        --build-target )
            func_validate_parameter_value "${1}" "${2}"
            BUILD_TARGET="${2}"
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
        --allow-missing-dependencies )
            ALLOW_MISSING_DEPENDENCIES="true"
            shift
            ;;
        --workspace )
            func_validate_parameter_value "${1}" "${2}"
            WORKSPACE="${2}"
            shift
            shift
            ;;
        --workspace-copy )
            func_validate_parameter_value "${1}" "${2}"
            WORKSPACE_COPY="${2}"
            shift
            shift
            ;;
        # optional bools
        --allow-vendorsetup-sh )
            ALLOW_VENDORSETUP_SH="true"
            shift
            ;;
        --cleanup-out-device )
            CLEANUP_OUT_DEVICE="true"
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
func_log_vars "DEVICE" "TREE_PATH" "CCACHE_DIR" "CCACHE_SIZE" \
    "BUILD_METHOD" "OUT_DIR" "OUT_SOONG_DIR" "OUT_SOONG_IS_SYMLINK" \
    "ALLOW_VENDORSETUP_SH" "CLEANUP_OUT_DEVICE" "ENV_SCRIPT" "DRY_RUN" \
    "ALLOW_MISSING_DEPENDENCIES" "BUILD_MODULE" "BUILD_TARGET" "WORKSPACE" \
    "WORKSPACE_COPY"

# Variable sanitization
func_log_info "Sanitize variables."
func_abort_if_blank_param_or_var "--device" "DEVICE"
if ! func_validate_codename "$DEVICE"; then
    func_abort_with_msg "Invalid device: $DEVICE"
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
if ! [ -z "$BUILD_MODULE" ]; then
    if ! func_validate_modulename "$BUILD_MODULE"; then
        func_abort_with_msg "Invalid module name: $BUILD_MODULE"
    fi
elif ! [ -z "$BUILD_TARGET" ]; then
    if ! func_validate_codename "$BUILD_TARGET"; then
        func_abort_with_msg "Invalid target name: $BUILD_TARGET"
    fi
fi

func_sanitize_var_path "CCACHE_DIR"
func_sanitize_var_path "ENV_SCRIPT"
func_sanitize_var_path "OUT_DIR"
func_sanitize_var_path "OUT_SOONG_DIR"
func_sanitize_var_path "TREE_PATH"
func_sanitize_var_path "WORKSPACE"

# Print info
func_log_vars "DEVICE" "TREE_PATH" "CCACHE_DIR" "CCACHE_SIZE" \
    "BUILD_METHOD" "OUT_DIR" "OUT_SOONG_DIR" "OUT_SOONG_IS_SYMLINK" \
    "ALLOW_VENDORSETUP_SH" "CLEANUP_OUT_DEVICE" "ENV_SCRIPT" "DRY_RUN" \
    "ALLOW_MISSING_DEPENDENCIES" "BUILD_MODULE" "BUILD_TARGET" "WORKSPACE" \
    "WORKSPACE_COPY"

# Preparation
if [ "$ALLOW_VENDORSETUP_SH" == "true" ]; then
    func_log_info "vendorsetup.sh is allowed. Removing device/allowed-vendorsetup_sh-files"
    func_exec_bash "cd $TREE_PATH && rm device/allowed-vendorsetup_sh-files; exit 0"
else
    func_log_info "vendorsetup.sh is disallowed. Creating device/allowed-vendorsetup_sh-files"
    func_exec_bash "cd $TREE_PATH && touch device/allowed-vendorsetup_sh-files"
fi
if [ "$CLEANUP_OUT_DEVICE" == "true" ]; then
    func_log_info "Cleaning up out target directory."
    func_exec_bash "rm -rf $OUT_DIR/target/product/$DEVICE"
fi

# Generate build command
func_log_border
BUILD_CMD+="cd ${TREE_PATH}"
BUILD_CMD+=" && export LC_ALL=C"
if [ "$ALLOW_MISSING_DEPENDENCIES" == "true" ]; then
    BUILD_CMD+=" && export ALLOW_MISSING_DEPENDENCIES=true"
fi
if ! [ -z "$CCACHE_SIZE" ]; then
    BUILD_CMD+=" && export USE_CCACHE=1 CCACHE_DIR=${CCACHE_DIR}"
    BUILD_CMD+=" && ccache -M ${CCACHE_SIZE}"
fi
BUILD_CMD+=" && source build/envsetup.sh"
if ! [ -z "$BUILD_MODULE" ]; then
    func_log_info "Build module: $BUILD_MODULE"
    BUILD_CMD+=" && breakfast ${DEVICE} && mma ${BUILD_MODULE}"
elif ! [ -z "$BUILD_TARGET" ]; then
    func_log_info "Build target: $BUILD_TARGET"
    BUILD_CMD+=" && breakfast ${DEVICE} && mka ${BUILD_TARGET}"
else
    func_log_info "Build ROM."
    case "$BUILD_METHOD" in
        mka_bacon)
            BUILD_CMD+=" && breakfast ${DEVICE} && mka bacon"
            ;;
        brunch_target)
            BUILD_CMD+=" && brunch ${DEVICE}"
            ;;
    esac
fi
func_log_info "Generated build command: \"${BUILD_CMD}\""

# Run the build
func_log_border
func_log_info "Starting the build."
if [ "$DRY_RUN" != "true" ]; then
    if func_exec_bash "${BUILD_CMD}"; then
        func_log_info "Build finished."
    else
        func_abort_with_msg "Build failed."
    fi
fi

# Copy out target files to workspace directory
OUT_DEVICE_DIR="${OUT_DIR}/target/product/${DEVICE}/"
if [ -d "$WORKSPACE" ] && ! [ -z "$WORKSPACE_COPY" ]; then
    func_log_border
    func_log_info "Copy out target files to workspace directory."
    if [ "$DRY_RUN" == "true" ]; then
        func_exec_bash "cd ${OUT_DEVICE_DIR} && ls ${WORKSPACE_COPY} ; exit 0"
    else
        if ! func_exec_bash "cd ${OUT_DEVICE_DIR} && cp -vr --parents ${WORKSPACE_COPY} ${WORKSPACE}/ ; exit 0"; then
            func_abort_with_msg "Failed to copy out target files to workspace directory."
        fi
    fi
fi

# End
func_log_info "Done."
exit 0