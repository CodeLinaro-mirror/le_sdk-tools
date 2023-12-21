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
    [ -d "${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb" ] && echo "deb" || echo "ipk"
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

    local LOCAL_LOG_FILE="${QIMSDK_WORK_DIR}/local_md5.log"
    local DEVICE_PULLED_LOG_FILE="${QIMSDK_WORK_DIR}/device_sync.log"
    local CHECKSUM=`grep "${PATH_TO_PACKAGE}" ${LOCAL_LOG_FILE} | cut -d ' ' -f1`
    local PACKAGE_NAME=$(basename "${PATH_TO_PACKAGE}")

    grep -q "${CHECKSUM}" ${DEVICE_PULLED_LOG_FILE}                                             || \
        {
            adb push "${PATH_TO_PACKAGE}" /tmp/                                                 || \
                {
                    print-red "Push package to device /tmp directory failed !!!";
                    return -4;
                }

            [ "${PKG_FORMAT}" == "deb" ]                                                        && \
                {
                    qimsdk-device-command "dpkg --instdir=${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX} --install --force-all /tmp/${PACKAGE_NAME}" || \
                        {
                            qimsdk-device-command "rm /tmp/${PACKAGE_NAME}";
                            print-red "Install package to device failed !!!";
                            return -5;
                        }
                }

            [ "${PKG_FORMAT}" == "ipk" ]                                                        && \
                {
                    qimsdk-device-command "opkg install -d qimsdk_install_path --force-reinstall --force-depends --force-overwrite /tmp/${PACKAGE_NAME}" || \
                        {
                            qimsdk-device-command "rm /tmp/${PACKAGE_NAME}";
                            print-red "Install package to device failed !!!";
                            return -7;
                        }
                }

            qimsdk-device-command "rm /tmp/${PACKAGE_NAME}"                                     || \
                {
                    print-red "Remove package from device /tmp directory failed !!!";
                    return -8;
                }
            sed -i "/\/${PACKAGE_NAME}/d" ${DEVICE_PULLED_LOG_FILE} 2>&1>/dev/null
            echo "${CHECKSUM} ${PATH_TO_PACKAGE}" >> ${DEVICE_PULLED_LOG_FILE}
        }

    return 0
}

# Clear device sync log to update all packets on next device sync
function qimsdk-device-sync-log-clear() {
    touch ${QIMSDK_WORK_DIR}/device_sync.log

    adb push ${QIMSDK_WORK_DIR}/device_sync.log ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/device_sync.log 2>&1>/dev/null

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
    qimsdk-target-packages-remove device                                                        || \
        {
            print-red "Device uninstall failed !!!";
            return -1;
        }
}

# Choose which device to use when more than one device is available in adb devices
function qimsdk-device-select() {
    local QIMSDK_INPUT_DEVICE
    local QIMSDK_DEVICES=(`adb devices -l | grep 'device ' | rev | cut -f2 -d\: | rev | cut -f1 -d\-`)
    local i=0

    echo "adb connected devices:"
    for DEVICE in ${QIMSDK_DEVICES[@]}; do
        i=$((i+1))
        echo "    $i. ${DEVICE}"
    done

    while true; do
        echo -e "\n"
        read -p 'Please choose device: ' QIMSDK_INPUT_DEVICE

        [ "$QIMSDK_INPUT_DEVICE" -lt 1 ] || [ "$QIMSDK_INPUT_DEVICE" -gt $i ]                       && \
            {
                echo "Please enter a number between 1 and $i!!!"
                continue
            }

        break
    done

    local QIMSDK_SELECTED_DEVICE=${QIMSDK_DEVICES[$((QIMSDK_INPUT_DEVICE-1))]}
    local QIMSDK_SELECTED_DEVICE_ID=`adb devices -l | grep ${QIMSDK_SELECTED_DEVICE} | cut -d ' ' -f1`

    export ANDROID_SERIAL=${QIMSDK_SELECTED_DEVICE_ID}

    echo "Device ${QIMSDK_SELECTED_DEVICE} set successfully!"
    return 0
}

# Pull log from remote in order to compare with local log and update if needed
function qimsdk-device-pull-log() {
    local DEVICE_LOG_FILE="${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/device_sync.log"

    qimsdk-device-command "[ -f ${DEVICE_LOG_FILE} ]" 2>&1>/dev/null                            || \
        {
            qimsdk-device-command "touch ${DEVICE_LOG_FILE}"
        }

    adb pull ${DEVICE_LOG_FILE} ${QIMSDK_WORK_DIR}/                                             || \
        {
            print-red "Failed to pull device log !!!"
            return -1
        }

    return 0
}

# Push updated log to device after putting in the hashes for newly pushed packages
function qimsdk-device-update-log() {

    adb push ${QIMSDK_WORK_DIR}/device_sync.log ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/       || \
        {
            print-red "Failed to push updated log to device !!!"
            return -1
        }

    return 0
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
print-red "qimsdk-device-select"
echo "    must be invoked to select device when multiple devices are connected"
