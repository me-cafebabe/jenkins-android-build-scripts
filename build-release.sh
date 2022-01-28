#!/bin/bash

MY_PATH=$(dirname $(realpath "$0"))
BUILD_SCRIPT="$MY_PATH/build.sh"

source $MY_PATH/utils/init.sh
source $MY_PATH/utils/log.sh
source $MY_PATH/utils/abort.sh
source $MY_PATH/utils/validate.sh
source $MY_PATH/utils/sanitize.sh
source $MY_PATH/utils/git.sh

# Print help text
func_help() {
    echo "Options for build script:"
    $BUILD_SCRIPT --help
    echo
    echo "Repo options:"
    echo "  --repo-sync | REPO_SYNC: Run \"repo sync\". Syncs all repos by default."
    echo "  --repo-sync-force | REPO_SYNC_FORCE: Append --force-sync to repo command."
    echo "  --repo-sync-params | REPO_SYNC_PARAMS: Pass parameters to repo sync command."
    echo
    echo "Upload options:"
    echo "  --upload | UPLOAD: Specify a file to upload."
    echo "  --upload-expire-days | UPLOAD_EXPIRE_DAYS: Expiration days for UPLOAD_SITE (if supported)."
    echo "  --upload-scp | UPLOAD_SCP: Upload to SCP destination. Specify this like \"user@host:/dir/\""
    echo "  --upload-scp-pass | UPLOAD_SCP_PASS: Password for SCP uploading."
    echo "  --upload-site | UPLOAD_SITE: Specify whether to upload to oshi.at or transfer.sh."
    echo
    echo "Misc options:"
    echo "  --env-script | ENV_SCRIPT: Script to load environment variables."
    echo "  --dry-run | DRY_RUN: Do not actually do anything."
    echo "  --help: Print this help text."
}

if [ "$#" -eq 0 ]; then
    func_help
    exit 0
fi

# Disable globbing
set -f

# Parse Parameters
while [ "${#}" -gt 0 ]; do
    case "${1}" in
        # Required for build script
        --rom-name )
            func_validate_parameter_value "${1}" "${2}"
            BUILD_SCRIPT_ARGS+="${1} ${2} "
            ROM_NAME="${2}"
            shift
            shift
            ;;
        # Required for both scripts
        --device )
            func_validate_parameter_value "${1}" "${2}"
            BUILD_SCRIPT_ARGS+="${1} ${2} "
            DEVICE="${2}"
            shift
            shift
            ;;
        --tree-path )
            func_validate_parameter_value "${1}" "${2}"
            BUILD_SCRIPT_ARGS+="${1} ${2} "
            TREE_PATH="${2}"
            shift
            shift
            ;;
        --out-dir )
            func_validate_parameter_value "${1}" "${2}"
            BUILD_SCRIPT_ARGS+="${1} ${2} "
            OUT_DIR="${2}"
            shift
            shift
            ;;
        # Repo
        --repo-sync )
            REPO_SYNC="true"
            shift
            ;;
        --repo-sync-force )
            REPO_SYNC_FORCE="true"
            shift
            ;;
        --repo-sync-params )
            func_validate_parameter_value "${1}" "${2}"
            REPO_SYNC_PARAMS="${2}"
            shift
            shift
            ;;
        # Upload
        --upload )
            func_validate_parameter_value "${1}" "${2}"
            UPLOAD="${2}"
            shift
            shift
            ;;
        --upload-expire-days )
            func_validate_parameter_value "${1}" "${2}"
            UPLOAD_EXPIRE_DAYS="${2}"
            shift
            shift
            ;;
        --upload-scp )
            func_validate_parameter_value "${1}" "${2}"
            UPLOAD_SCP="${2}"
            shift
            shift
            ;;
        --upload-scp-pass )
            func_validate_parameter_value "${1}" "${2}"
            UPLOAD_SCP_PASS="${2}"
            shift
            shift
            ;;
        --upload-site )
            func_validate_parameter_value "${1}" "${2}"
            UPLOAD_SITE="${2}"
            shift
            shift
            ;;
        # misc
        --env-script )
            func_validate_parameter_value "${1}" "${2}"
            ENV_SCRIPT="${2}"
            if ! [ -f "$ENV_SCRIPT" ]; then
                func_abort_with_msg "Environment script $ENV_SCRIPT is not accessible!"
            fi
            BUILD_SCRIPT_ARGS+="${1} "
            shift
            shift
            ;;
        --dry-run )
            DRY_RUN="true"
            BUILD_SCRIPT_ARGS+="${1} "
            shift
            ;;
        --help )
            func_help
            exit 0
            ;;
        *)
            BUILD_SCRIPT_ARGS+="${1} "
            shift
            ;;
    esac
done

func_log_info "Parameters to pass to build script: \"${BUILD_SCRIPT_ARGS}\""
if ! func_validate_parameter_list "${BUILD_SCRIPT_ARGS}"; then
    func_abort_with_msg "Validation of parameters failed!"
fi

# Load or override variables from env script
if [ -f "$ENV_SCRIPT" ]; then
    source $ENV_SCRIPT
fi

# Check dependency
if ! [ -z "$UPLOAD_SCP_PASS" ]; then
    if ! sshpass -V > /dev/null; then
        func_abort_with_msg "Dependency check failed: sshpass"
    fi
fi

# Print info
func_log_vars "REPO_SYNC" "REPO_SYNC_FORCE" "REPO_SYNC_PARAMS" \
    "UPLOAD_EXPIRE_DAYS" "UPLOAD_SCP" "UPLOAD_SITE" "UPLOAD" \
    "ENV_SCRIPT" "DRY_RUN" "TREE_PATH" "OUT_DIR" "DEVICE"

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
func_abort_if_blank_param_or_var "--rom-name" "ROM_NAME"
if ! func_validate_codename "$ROM_NAME"; then
    func_abort_with_msg "Invalid ROM Name: $ROM_NAME"
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
func_sanitize_var_default "UPLOAD_EXPIRE_DAYS" "7"
if ! func_validate_number "$UPLOAD_EXPIRE_DAYS" || ! [ "$UPLOAD_EXPIRE_DAYS" -gt 0 ] ; then
    func_abort_with_msg "Invalid expiration days: $UPLOAD_EXPIRE_DAYS"
fi
case "$UPLOAD_SITE" in
    "oshi.at")
        if [ "$UPLOAD_EXPIRE_DAYS" -gt 30 ] ; then
            func_abort_with_msg "Max expiration days for oshi.at is 30 days!"
        fi
        ;;
    "transfer.sh")
        func_log_info "transfer.sh has fixed expiration days: 14 days."
        ;;
    "")
        ;;
    *)
        func_abort_with_msg "Unsupported upload site: $UPLOAD_SITE"
        ;;
esac

func_sanitize_var_command "REPO_SYNC_PARAMS"
func_sanitize_var_command "UPLOAD"
func_sanitize_var_command "UPLOAD_SCP"
func_sanitize_var_command "UPLOAD_SCP_PASS"

# Print info
func_log_vars "REPO_SYNC" "REPO_SYNC_FORCE" "REPO_SYNC_PARAMS" \
    "UPLOAD_EXPIRE_DAYS" "UPLOAD_SCP" "UPLOAD_SITE" "UPLOAD" \
    "ENV_SCRIPT" "DRY_RUN" "TREE_PATH" "OUT_DIR" "DEVICE"

# Sync repositories
if [ "$REPO_SYNC" == "true" ]; then
    func_log_info "Syncing repositories."
    REPO_SYNC_CMD="repo sync ${REPO_SYNC_PARAMS}"
    if [ "$REPO_SYNC_FORCE" == "true" ]; then
        REPO_SYNC_CMD+=" --force-sync"
    fi
    if [ "$DRY_RUN" != "true" ]; then
        if ! func_exec_bash "cd $TREE_PATH && $REPO_SYNC_CMD"; then
            func_abort_with_msg "Failed to sync repositories."
        fi
    fi
fi

# Build
func_log_border
func_log_info "Starting to build."
if ! func_exec_bash "${BUILD_SCRIPT} ${BUILD_SCRIPT_ARGS}"; then
    func_abort_with_msg "Failed to build."
fi

# Upload
func_log_border
OUT_DEVICE_DIR="${OUT_DIR}/target/product/${DEVICE}/"
if ! [ -z "${UPLOAD}" ] && [ -d "$OUT_DEVICE_DIR" ] ; then
    UPLOAD_FILENAME=$(bash -c "cd $OUT_DEVICE_DIR && (ls ${UPLOAD} 2>/dev/null|head -n 1) ; exit 0")
fi
if ! [ -z "${UPLOAD_FILENAME}" ]; then
    func_log_info "Uploading artifact ${UPLOAD_FILENAME}."
    if [ "$DRY_RUN" != "true" ]; then
        # SCP
        if ! [ -z "$UPLOAD_SCP" ]; then
            func_log_info "Uploading to SCP..."
            if [ -z "$UPLOAD_SCP_PASS" ]; then
                if ! func_exec_bash "scp -o StrictHostKeyChecking=no ${OUT_DEVICE_DIR}/${UPLOAD_FILENAME} ${UPLOAD_SCP}"; then
                    func_log_error "Failed to upload to SCP!"
                fi
            else
                OLD_DEBUG=$DEBUG
                DEBUG=0
                if ! func_exec_bash "sshpass -p \"$UPLOAD_SCP_PASS\" scp -o StrictHostKeyChecking=no ${OUT_DEVICE_DIR}/${UPLOAD_FILENAME} ${UPLOAD_SCP}"; then
                    func_log_error "Failed to upload to SCP with password!"
                fi
                DEBUG=$OLD_DEBUG
            fi
        fi
        # Website
        case "$UPLOAD_SITE" in
            "oshi.at")
                func_log_info "Uploading to oshi.at"
                if ! func_exec_bash "curl --upload-file ${OUT_DEVICE_DIR}/${UPLOAD_FILENAME} https://oshi.at/${UPLOAD_FILENAME}/$(($UPLOAD_EXPIRE_DAYS*1440))"; then
                    func_log_error "Failed to upload to oshi.at!"
                fi
                ;;
            "transfer.sh")
                func_log_info "Uploading to transfer.sh"
                if ! func_exec_bash "curl --upload-file ${OUT_DEVICE_DIR}/${UPLOAD_FILENAME} https://transfer.sh/${UPLOAD_FILENAME}"; then
                    func_log_error "Failed to upload to transfer.sh!"
                fi
                ;;
        esac
    fi
else
    func_log_warn "Nothing to upload!"
fi

# End
func_log_info "Done."
exit 0