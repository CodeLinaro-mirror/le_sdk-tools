#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Send script file to the remote
#   $1 - (mandatory) path to script file to be sent to the remote
function qimsdk-remote-script-invoke() {
    local SCRIPT_PATH=$1

    [ ! -f "${SCRIPT_PATH}" ]                                                                   && \
        print-red "Path to target script file must be provided as first argument !!!"           && \
        return -1

    # Send script file to the remote
    rsync -a --progress ${SCRIPT_PATH} ${QIMSDK_ESDK_DEPLOY_URL}                                || \
        {
            print-red "rsync script file to deploy URL failed !!!";
            return -2;
        }

    # Notify that script needs to be invoked on the remote, cannot do it from this machine
    local SCRIPT_FILE=$(basename "${SCRIPT_PATH}")
    print-blue "Please note that ${SCRIPT_FILE} must be invoked on the host computer";
}

# Sync compiled package with the remote
#   $1 - (mandatory) path to the package to be synced
function qimsdk-remote-pkg-sync() {
    [ -z "${QIMSDK_ESDK_DEPLOY_URL}" ] && print-red "Deploy URL must be provided in config json !!!" && return -1

    local PATH_TO_PACKAGE=$1
    [ -z "${PATH_TO_PACKAGE}" ] && print-red "Package name must be provided as first argument !!!" && return -2

    [ ! -f "${PATH_TO_PACKAGE}" ] && print-red "File "${PATH_TO_PACKAGE}" does not exist !!!" && return -3

    local LOCAL_LOG_FILE="${QIMSDK_WORK_DIR}/local_md5.log"
    local REMOTE_PULLED_LOG_FILE="${QIMSDK_WORK_DIR}/remote_sync.log"
    local CHECKSUM=`grep ${PATH_TO_PACKAGE} ${LOCAL_LOG_FILE} | cut -d ' ' -f1`
    local PACKAGE_NAME=$(basename "${PATH_TO_PACKAGE}")

    grep -q "${CHECKSUM}" ${REMOTE_PULLED_LOG_FILE} 2>&1>/dev/null                              || \
        {
            rsync -a --progress ${PATH_TO_PACKAGE} ${QIMSDK_ESDK_DEPLOY_URL}                    || \
                {
                    print-red "rsync package to deploy URL failed !!!";
                    return -4;
                }

            sed -i "/\/${PACKAGE_NAME}/d" ${REMOTE_PULLED_LOG_FILE} 2>&1>/dev/null
            echo "${CHECKSUM} ${PATH_TO_PACKAGE}" >> ${REMOTE_PULLED_LOG_FILE}
        }

    return 0
}

# Sync compiled package with the remote
#   $1 - (mandatory) path to the package to be synced
function qimsdk-remote-pkg-sync-dev() {
    [ -z "${QIMSDK_ESDK_DEPLOY_URL_DEV}" ] && print-red "Deploy URL must be provided in config json !!!" && return -1

    local PATH_TO_PACKAGE=$1
    [ -z "${PATH_TO_PACKAGE}" ] && print-red "Package name must be provided as first argument !!!" && return -2

    [ ! -f "${PATH_TO_PACKAGE}" ] && print-red "File "${PATH_TO_PACKAGE}" does not exist !!!" && return -3

    local LOCAL_LOG_FILE="${QIMSDK_WORK_DIR}/local_md5.log"
    local REMOTE_PULLED_LOG_FILE="${QIMSDK_WORK_DIR}/remote_sync.log"
    local CHECKSUM=`grep ${PATH_TO_PACKAGE} ${LOCAL_LOG_FILE} | cut -d ' ' -f1`
    local PACKAGE_NAME=$(basename "${PATH_TO_PACKAGE}")

    grep -q "${CHECKSUM}" ${REMOTE_PULLED_LOG_FILE} 2>&1>/dev/null                              || \
        {
            rsync -a --progress ${PATH_TO_PACKAGE} ${QIMSDK_ESDK_DEPLOY_URL_DEV}                || \
                {
                    print-red "rsync package to deploy URL failed !!!";
                    return -4;
                }

            sed -i "/${PACKAGE_NAME}/d" ${REMOTE_PULLED_LOG_FILE} 2>&1>/dev/null
            echo "${CHECKSUM} ${PATH_TO_PACKAGE}" >> ${REMOTE_PULLED_LOG_FILE}
        }

    return 0
}

# Clear remote target sync log to update all packets on next remote sync
function qimsdk-remote-sync-log-clear() {
    touch ${QIMSDK_WORK_DIR}/remote_sync.log
    [ -z "${QIMSDK_ESDK_DEPLOY_URL}" ]                                                          || \
        rsync -qu ${QIMSDK_WORK_DIR}/remote_sync.log ${QIMSDK_ESDK_DEPLOY_URL} 2>&1>/dev/null
    [ -z "${QIMSDK_ESDK_DEPLOY_URL_DEV}" ]                                                      || \
        rsync -qu ${QIMSDK_WORK_DIR}/remote_sync.log ${QIMSDK_ESDK_DEPLOY_URL_DEV} 2>&1>/dev/null

    rm -f ${QIMSDK_WORK_DIR}/remote_sync.log
}

# Sync compiled release packages with the remote target
function qimsdk-remote-sync-rel() {
    qimsdk-target-sync rel remote $(qimsdk-get-pkg-format)
}

# Sync compiled debug packages with the remote target
function qimsdk-remote-sync-dbg() {
    qimsdk-target-sync dbg remote $(qimsdk-get-pkg-format)
}

function qimsdk-remote-sync-dev() {
    qimsdk-target-sync dev remote $(qimsdk-get-pkg-format)
}

function qimsdk-remote-sync-staticdev() {
    qimsdk-target-sync staticdev remote $(qimsdk-get-pkg-format)
}

# Pull remote log from remote in order to compare with local log and update if needed
function qimsdk-remote-pull-log() {
    local VARIANT=$1

    local DEPLOY_URL=
    [ "${VARIANT}" == "dev" ] || [ "${VARIANT}" == "staticdev" ]                                && \
        {
            [ -z "${QIMSDK_ESDK_DEPLOY_URL_DEV}" ] && print-red "Deploy URL must be provided in config json !!!" && return -1
            DEPLOY_URL="${QIMSDK_ESDK_DEPLOY_URL_DEV}"
        }

    [ -z "${QIMSDK_ESDK_DEPLOY_URL}" ] && print-red "Deploy URL must be provided in config json !!!" && return -2
    DEPLOY_URL="${QIMSDK_ESDK_DEPLOY_URL}"

    local REMOTE_LOG_FILE="${DEPLOY_URL}/remote_sync.log"

    rsync -q ${REMOTE_LOG_FILE} ${QIMSDK_WORK_DIR}/                                             || \
        {
            touch ${QIMSDK_WORK_DIR}/remote_sync.log
            rsync -q ${QIMSDK_WORK_DIR}/remote_sync.log ${DEPLOY_URL}/
        }

    return 0
}

# Push updated log to remote after putting in the hashes for newly pushed packages
function qimsdk-remote-update-log() {
    local VARIANT=$1

    local DEPLOY_URL=
    [ "${VARIANT}" == "dev" ] || [ "${VARIANT}" == "staticdev" ]                                && \
        {
            [ -z "${QIMSDK_ESDK_DEPLOY_URL_DEV}" ] && print-red "Deploy URL must be provided in config json !!!" && return -1
            DEPLOY_URL="${QIMSDK_ESDK_DEPLOY_URL_DEV}"
        }

    [ -z "${QIMSDK_ESDK_DEPLOY_URL}" ] && print-red "Deploy URL must be provided in config json !!!" && return -2
    DEPLOY_URL="${QIMSDK_ESDK_DEPLOY_URL}"

    rsync -q ${QIMSDK_WORK_DIR}/remote_sync.log ${DEPLOY_URL}/                                  || \
        {
            print-red "Failed to sync updated remote log !!!"
            return -3
        }

    return 0
}

[ ! -z "${QIMSDK_ESDK_DEPLOY_URL}" ]                                                            && \
    {
        print-blue "qimsdk-remote-sync-rel";
        echo "    must be invoked to sync release packages with the remote target";
        print-blue "qimsdk-remote-sync-dbg";
        echo "    must be invoked to sync debug packages with the remote target";
        print-blue "qimsdk-remote-sync-dev";
        echo "    must be invoked to sync dev packages with the remote target";
        print-blue "qimsdk-remote-sync-staticdev";
        echo "    must be invoked to sync staticdev packages with the remote target";
    }
