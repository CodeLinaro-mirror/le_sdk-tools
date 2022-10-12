#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Sync compiled package with the remote
#   $1 - (mandatory) path to the package to be synced
function qimsdk-remote-pkg-sync() {
    [ -z ${QIMSDK_ESDK_DEPLOY_URL} ] && print-red "Deploy URL must be provided in config json !!!" && return -1

    local PATH_TO_PACKAGE=$1
    [ -z "${PATH_TO_PACKAGE}" ] && print-red "Package name must be provided as first argument !!!" && return -2

    [ ! -f "${PATH_TO_PACKAGE}" ] && print-red "File "${PATH_TO_PACKAGE}" does not exist !!!" && return -3

    rsync -a --progress ${PATH_TO_PACKAGE} ${QIMSDK_ESDK_DEPLOY_URL}                             || \
        {
            print-red "rsync package to deploy URL failed !!!";
            return -4;
        }

    return 0
}

# Clear remote target sync log to update all packets on next remote sync
function qimsdk-remote-sync-log-clear() {
    rm -f ${QIMSDK_WORK_FOLDER}/remote_sync.log
}

# Sync compiled release packages with the remote target
function qimsdk-remote-sync-rel() {
    qimsdk-target-sync rel remote
}

# Sync compiled debug packages with the remote target
function qimsdk-remote-sync-dbg() {
    qimsdk-target-sync dbg remote
}

[ ! -z ${QIMSDK_ESDK_DEPLOY_URL} ]                                                              && \
    {
        print-blue "qimsdk-remote-sync-rel";
        echo "    must be invoked to sync release packages with the remote target";
        print-blue "qimsdk-remote-sync-dbg";
        echo "    must be invoked to sync debug packages with the remote target";
    }
