#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Propagate errors from adb shell
function qimsdk-local-device-command ()
{
    local rc

    adb shell "$1 && echo 0 > /data/rc.txt"
    rc=$?
    [ $rc -ne 0 ] && print-red "Executing Command $1 failed !!!" && return $rc

    adb pull /data/rc.txt /tmp/rc.txt 2>&1 > /dev/null
    rc=$?
    adb shell "rm -f /data/rc.txt"
    [ $rc -ne 0 ] && (rm -f /tmp/rc.txt; print-red "Command $1 failed !!!") && return $rc

    rc=`cat /tmp/rc.txt`
    rm -f /tmp/rc.txt
    [ $rc -ne 0 ] && print-red "Command $1 return code is not 0 !!!" && return $rc

    return $rc
}

# Sync packages with the device from specified folder
#   $1 - (mandatory) path to the packages to be synced
function qimsdk-local-sync() {
    local FOLDER=$1
    echo $FOLDER
    ll $FOLDER
    [ ! -d "${FOLDER}" ] && \
        echo "Path to folder with packages must be provided as first argument !!!" && return -1

    local FILE
    for FILE in ${FOLDER}/*.ipk; do
        local PACKAGE_NAME=$(basename "${FILE}")

        adb push ${FILE} /tmp/                                                                  || \
            {
                echo "Push package to device failed !!!";
                return -1;
            }

        qimsdk-local-device-command "opkg --force-depends --force-reinstall --force-overwrite install /tmp/${PACKAGE_NAME}" || \
            {
                adb shell "rm -f /tmp/${PACKAGE_NAME}"
                print-red "Install package to device failed !!!";
                return -2;
            }

        adb shell "rm -f /tmp/${PACKAGE_NAME}"
        rm -f ${FILE}
    done

    echo "Device synced successfully !!!"
}

# Print help
echo "qimsdk-local-sync"
echo "    must be invoked to sync packages with the device from specified folder"
