#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Propagate errors from adb shell
#   $1 - (mandatory) device command to be executed
function qimsdk-device-command()
{
    local CMD=$1
    local rc

    adb shell "${CMD} && echo 0 > /data/rc.txt"
    rc=$?
    [ "${rc}" -ne 0 ] && print-red "Executing Command ${CMD} failed !!!" && return ${rc}

    local TMP_DIR=`mktemp -d`

    adb pull /data/rc.txt ${TMP_DIR}/rc.txt 2>&1 > /dev/null
    rc=$?
    adb shell "rm -f /data/rc.txt"
    [ "${rc}" -ne 0 ] && (rm -f ${TMP_DIR}/rc.txt; print-red "Command ${CMD} failed !!!") && return ${rc}

    rc=`cat ${TMP_DIR}/rc.txt`
    rm -f ${TMP_DIR}/rc.txt
    [ "${rc}" == "0" ]                                                                          || \
        {
            print-red "Command ${CMD} return code is not 0 !!!";
            return ${rc};
        }

    return ${rc}
}

# Invoke script file on the device
#   $1 - (mandatory) path to script file to be invoked
function qimsdk-device-script-invoke() {
    local SCRIPT_PATH=$1

    [ ! -f "${SCRIPT_PATH}" ]                                                                   && \
        print-red "Path to target script file must be provided as first argument !!!"           && \
        return -1

    # Invoke script file
    source ${SCRIPT_PATH}
}

# Prepare device
function qimsdk-device-prepare() {
    local rc

    echo "Waiting for device"
    adb wait-for-device root
    rc=$?
    [ "${rc}" -ne 0 ] && print-red "adb root failed !!!" && return -1

    adb wait-for-device remount wait-for-device
    rc=$?
    [ "${rc}" -ne 0 ] && print-red "adb remount failed !!!" && return -2

    qimsdk-device-command "mount -o remount,rw / > /dev/null"
    rc=$?
    [ "${rc}" -ne 0 ] && print-red "adb file system remount failed !!!" && return -3

    qimsdk-device-command "! command -v setenforce || setenforce 0"
    rc=$?
    [ "${rc}" -ne 0 ] && print-red "adb disable SE Linux failed !!!" && return -4

    print-green "Device prepared successfully !!!"
}

# Identify the package management configuration
function qimsdk-get-pkg-format() {
    [ -d ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb ] && echo "deb" || echo "ipk"
}

# Check whether compiled package is already present on the device
#   $1 - (mandatory) package to be cheked
function qimsdk-device-pkg-check() {
    local FULL_PACKAGE=$1
    local PACKAGE=`echo ${FULL_PACKAGE} | cut -d '_' -f 1`

    [ "$(qimsdk-get-pkg-format)" == "deb" ]                                                     && \
        adb shell "dpkg --list ${PACKAGE} > /tmp/log.txt"
    [ "$(qimsdk-get-pkg-format)" == "ipk" ]                                                     && \
    adb shell "opkg list-installed ${PACKAGE} > /tmp/log.txt"
    adb pull /tmp/log.txt /tmp/log.txt 1>/dev/null
    local rc=$?
    [ -s /tmp/log.txt ] || rc=-1

    adb shell "rm -f /tmp/log.txt"
    rm -f /tmp/log.txt

    return ${rc}
}

# Sync compiled package with the device
#   $1 - (mandatory) path to the package to be synced
#   $2 - (mandatory) package format
function qimsdk-device-pkg-sync() {
    local PATH_TO_PACKAGE=$1
    local PKG_FORMAT=$2
    [ -z "${PATH_TO_PACKAGE}" ] && print-red "Package name must be provided as first argument !!!" && return -1
    [ -z "${PKG_FORMAT}" ] && print-red "Package format deb or ipk must be provided as second argument !!!" && return -2

    [ ! -f "${PATH_TO_PACKAGE}" ] && print-red "File "${PATH_TO_PACKAGE}" does not exist !!!" && return -3

    local PACKAGE_NAME=$(basename "${PATH_TO_PACKAGE}")
    adb push "${PATH_TO_PACKAGE}" /tmp/                                                         || \
        {
            print-red "Push package to device /tmp directory failed !!!";
            return -4;
        }

    [ "${PKG_FORMAT}" == "deb" ]                                                                && \
        {
        qimsdk-device-command "dpkg --install --force-all /tmp/${PACKAGE_NAME}"                 || \
            {
                qimsdk-device-command "rm /tmp/${PACKAGE_NAME}";
                print-red "Install package to device failed !!!";
                return -5;
            }
        }                                                                                       || \
    qimsdk-device-command "opkg install --force-reinstall --force-depends --force-overwrite /tmp/${PACKAGE_NAME}" || \
        {
            qimsdk-device-command "rm /tmp/${PACKAGE_NAME}";
            print-red "Install package to device failed !!!";
            return -6;
        }

    qimsdk-device-command "rm /tmp/${PACKAGE_NAME}"                                             || \
        {
            print-red "Remove package from device /tmp directory failed !!!";
            return -7;
        }

    return 0
}

# Clear device sync log to update all packets on next device sync
function qimsdk-device-sync-log-clear() {
    rm -f ${QIMSDK_WORK_DIR}/device_sync.log
}

# Sync compiled release packages with the device
function qimsdk-device-sync-rel() {
    qimsdk-target-sync rel device $(qimsdk-get-pkg-format)
}

# Sync compiled debug packages with the device
function qimsdk-device-sync-dbg() {
    qimsdk-target-sync dbg device $(qimsdk-get-pkg-format)
}

# Remove installed packages from the device
function qimsdk-device-packages-remove() {
    qimsdk-target-packages-remove device
}

# Print help
print-red "qimsdk-device-prepare"
echo "    must be invoked to prepare device for pkg installation"
print-red "qimsdk-device-sync-rel"
echo "    must be invoked to sync release packages with the device"
print-red "qimsdk-device-sync-dbg"
echo "    must be invoked to sync debug packages with the device"
print-red "qimsdk-device-packages-remove"
echo "    must be invoked to remove installed packages from the device"
