#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Get all updated packages
#   $1 - (mandatory) /output/ updated packages
function qimsdk-target-get-updated-packages-all() {
    local -n UPDATED_PACKAGES=$1

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/ipk/ -type f \( -name "*.ipk" \) -cnewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

# Get updated release packages
#   $1 - (mandatory) /output/ updated packages
function qimsdk-target-get-updated-packages-rel() {
    local -n UPDATED_PACKAGES=$1

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/ipk/ -type f \( -name "*.ipk" ! -iname "*-dev_*" ! -iname "*-staticdev_*" ! -iname "*-doc_*" ! -iname "*-dbg_*" \) -cnewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

# Get updated debug packages
#   $1 - (mandatory) /output/ updated packages
function qimsdk-target-get-updated-packages-dbg() {
    local -n UPDATED_PACKAGES=$1

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/ipk/ -type f \( -name "*-dbg_*.ipk" ! -iname "*-dev_*" ! -iname "*-staticdev_*" ! -iname "*-doc_*" \) -cnewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

function qimsdk-target-get-updated-packages-dev() {
    local -n UPDATED_PACKAGES=$1

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/ipk/ -type f \( -name "*-dev_*.ipk" ! -iname "*-dbg_*" ! -iname "*-staticdev_*" ! -iname "*-doc_*" \) -cnewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

function qimsdk-target-get-updated-packages-staticdev() {
    local -n UPDATED_PACKAGES=$1

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/ipk/ -type f \( -name "*-staticdev_*.ipk" ! -iname "*-dbg_*" ! -iname "*-doc_*" \) -anewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

# Sync compiled packages with the target
#   $1 - (mandatory) variant: rel or dbg
#   $2 - (mandatory) target: device or remote
function qimsdk-target-sync() {
    local VARIANT=$1
    local TARGET=$2
    [ ! "${VARIANT}" == "rel" ] && [ ! "${VARIANT}" == "dbg" ]                                  && \
        [ ! "${VARIANT}" == "dev" ] && [ ! "${VARIANT}" == "staticdev" ]                        && \
        print-red "Variant input argument dbg, rel, dev or staticdev is required" && return -1

    [ ! "${TARGET}" == "device" ] && [ ! "${TARGET}" == "remote" ]                              && \
        print-red "Target input argument device or remote is required" && return -2

    # Check whether code was already prepared
    [ ! -f ${QIMSDK_WORK_DIR}/prepared ] && print-red "Layers are not prepared" && return -3

    # Get updated packages
    local PKGS
    qimsdk-target-get-updated-packages-${VARIANT} PKGS                                          || \
        {
            print-red "Failed to get updated packages";
            return -4;
        }

    # Sync only new packages
    local PKG
    local SYNC_FILE="${QIMSDK_WORK_DIR}/${TARGET}_sync.log"
    local REMOVE_PKG_FILE="${QIMSDK_WORK_DIR}/${TARGET}_packages_remove.sh"

    for PKG in "${PKGS[@]}"; do
        local DATE=`date -r ${PKG}`
        local LOG="Pushing ${PKG} ${DATE}"
        local PKG_NAME=`echo $(basename ${PKG}) | cut -d '_' -f 1`
        local DEV=""
        [ ${VARIANT} == "dev" ] || [ ${VARIANT} == "staticdev" ]                                && \
            {
                DEV="-dev"
            }

        cat ${SYNC_FILE} 2>/dev/null | grep "${LOG}" 1>/dev/null                                || \
            {
                qimsdk-${TARGET}-pkg-sync${DEV} ${PKG}                                          && \
                {
                    sed -i "/${PKG_NAME}/d" ${REMOVE_PKG_FILE} 2>/dev/null
                    echo "adb shell \"opkg remove --force-depends ${PKG_NAME}\"" >> ${REMOVE_PKG_FILE}
                }                                                                               || \
                return -5
            }
        PKG=$(basename ${PKG})
        sed -i "/${PKG}/d" ${SYNC_FILE} 2>/dev/null
        echo "${LOG}" >> ${SYNC_FILE}
    done

    print-green "Packages synced successfully !!!"
}

# Create packages archive for the target
#   $1 - (mandatory) variant: rel, dev or all
function qimsdk-target-sync-artifacts() {
    local VARIANT=$1

    [ ! "${VARIANT}" == "rel" ] && [ ! "${VARIANT}" == "dev" ] && [ ! "${VARIANT}" == "all" ]   && \
        print-red "Variant input argument dbg, rel, dev or staticdev is required" && return -1

    # Check whether code was already prepared
    [ ! -f ${QIMSDK_WORK_DIR}/prepared ] && print-red "Layers are not prepared" && return -2

    # Get updated packages
    local PKGS
    qimsdk-target-get-updated-packages-${VARIANT} PKGS                                          || \
        {
            print-red "Failed to get updated packages";
            return -3;
        }

    # Set variant postfix depending on variant
    [ "${VARIANT}" == "rel" ] && VARIANT="_rel"
    [ "${VARIANT}" == "dev" ] && VARIANT="_dev"
    [ "${VARIANT}" == "all" ] && VARIANT=""

    mkdir -p ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}

    # Sync only new packages
    local PKG
    local SYNC_FILE="${QIMSDK_WORK_DIR}/artifacts_sync${VARIANT}.log"

    for PKG in "${PKGS[@]}"; do
        local DATE=`date -r ${PKG}`
        local LOG="Pushing ${PKG} ${DATE}"
        local PKG_NAME=`echo $(basename ${PKG}) | cut -d '_' -f 1`

        cat ${SYNC_FILE} 2>/dev/null | grep "${LOG}" 1>/dev/null                                || \
            {
                rsync -a --progress ${PKG} ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}      || \
                    {
                        print-red "rsync package ${PKG_NAME} to artifacts dir failed !!!";
                        return -4;
                    }
            }
        PKG=$(basename ${PKG})
        sed -i "/${PKG}/d" ${SYNC_FILE} 2>/dev/null
        echo "${LOG}" >> ${SYNC_FILE}
    done

    # Remove old artifacts archive
    rm -f ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}.zip

    # Create new artifacts archive
    pushd ${QIMSDK_WORK_DIR}/artifacts 1>/dev/null
        zip -j packages${VARIANT}.zip ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}/*
    popd 1>/dev/null

    print-green "Artifacts synced successfully !!!"
}

function qimsdk-target-sync-artifacts-rel() {
    qimsdk-target-sync-artifacts rel
}

function qimsdk-target-sync-artifacts-dev() {
    qimsdk-target-sync-artifacts dev
}

function qimsdk-target-sync-artifacts-all() {
    qimsdk-target-sync-artifacts all
}

# Remove installed packages from the target
#   $1 - (mandatory) target: device or remote
function qimsdk-target-packages-remove() {
    local TARGET=$1

    [ ! "${TARGET}" == "device" ] && [ ! "${TARGET}" == "remote" ]                              && \
        print-red "Target input argument device or remote is required" && return -1

    local REMOVE_PKG_FILE="${QIMSDK_WORK_DIR}/${TARGET}_packages_remove.sh"

    # Remove packages and clear sync log
    qimsdk-${TARGET}-script-invoke ${REMOVE_PKG_FILE}                                           && \
        qimsdk-${TARGET}-sync-log-clear

    print-green "Packages removed successfully !!!"
}
