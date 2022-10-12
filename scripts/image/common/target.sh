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
    done < <(find ${QIMSDK_ESDK_BASE_FOLDER}/tmp/deploy/ipk/ -type f \( -name "*.ipk" \) -anewer ${QIMSDK_WORK_FOLDER}/sync -print0)
}

# Get updated release packages
#   $1 - (mandatory) /output/ updated packages
function qimsdk-target-get-updated-packages-rel() {
    local -n UPDATED_PACKAGES=$1

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_FOLDER}/tmp/deploy/ipk/ -type f \( -name "*.ipk" ! -iname "*-dev_*" ! -iname "*-staticdev_*" ! -iname "*-doc_*" ! -iname "*-dbg_*" \) -anewer ${QIMSDK_WORK_FOLDER}/sync -print0)
}

# Get updated debug packages
#   $1 - (mandatory) /output/ updated packages
function qimsdk-target-get-updated-packages-dbg() {
    local -n UPDATED_PACKAGES=$1

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_FOLDER}/tmp/deploy/ipk/ -type f \( -name "*-dbg_*.ipk" ! -iname "*-dev_*" ! -iname "*-staticdev_*" ! -iname "*-doc_*" \) -anewer ${QIMSDK_WORK_FOLDER}/sync -print0)
}

# Sync compiled packages with the target
#   $1 - (mandatory) variant: rel or dbg
#   $2 - (mandatory) target: device or remote
function qimsdk-target-sync() {
    local VARIANT=$1
    local TARGET=$2
    [ ! "${VARIANT}" == "rel" ] && [ ! "${VARIANT}" == "dbg" ]              && \
        print-red "Variant input argument rel or dev is required" && return -1

    [ ! "${TARGET}" == "device" ] && [ ! "${TARGET}" == "remote" ]          && \
        print-red "Target input argument device or remote is required" && return -2

    # Check whether code was already prepared
    [ ! -f ${QIMSDK_WORK_FOLDER}/sync ] && print-red "Layers are not prepared" && return -3

    # Get updated packages
    local PKGS
    qimsdk-target-get-updated-packages-${VARIANT} PKGS                      || \
        {
            print-red "Failed to get updated packages";
            return -4;
        }

    # Sync only new packages
    local PKG
    local SYNC_FILE="${QIMSDK_WORK_FOLDER}/${TARGET}_sync.log"

    for PKG in "${PKGS[@]}"; do
        local DATE=`date -r ${PKG}`
        local LOG="Pushing ${PKG} ${DATE}"

        cat ${SYNC_FILE} 2>/dev/null | grep "${LOG}" 1>/dev/null            || \
            qimsdk-${TARGET}-pkg-sync ${PKG}                                || \
            return -5
        PKG=$(basename ${PKG})
        sed -i "/${PKG}/d" ${SYNC_FILE} 2>/dev/null
        echo "${LOG}" >> ${SYNC_FILE}
    done

    print-green "Packages synced successfully !!!"
}
