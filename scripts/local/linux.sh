#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Propagate errors from adb shell
#   $1 - (mandatory) device command to be executed
function qimsdk-local-device-command ()
{
    local CMD=$1
    local rc

    adb shell "${CMD} && echo 0 > /tmp/rc.txt"
    rc=$?
    [ "${rc}" -ne 0 ] && echo "Executing Command ${CMD} failed !!!" && return ${rc}

    local TMP_DIR=`mktemp -d`

    adb pull /tmp/rc.txt ${TMP_DIR}/rc.txt 2>&1 > /dev/null
    rc=$?
    adb shell "rm -f /tmp/rc.txt"
    [ "${rc}" -ne 0 ] && (rm -f ${TMP_DIR}/rc.txt; echo "Command ${CMD} failed on device!!!") && return ${rc}

    rm -f ${TMP_DIR}/rc.txt

    return ${rc}
}

# Propagate the correct install path to opkg config
function qimsdk-local-set-opkg-prefix () {
    qimsdk-local-device-command "cat /etc/opkg/opkg.conf | grep \"dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}\"" 1>/dev/null || \
        {
            qimsdk-local-device-command 'sed -i '/qimsdk_install_path/d' /etc/opkg/opkg.conf'
            qimsdk-local-device-command "echo \"dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}\" >> /etc/opkg/opkg.conf"
        }
}

# Sync packages with the device from specified directory
#   $1 - (mandatory) path to the packages to be synced
function qimsdk-local-sync() {
    local PACKAGES_PATH=$1
    [ ! -d "${PACKAGES_PATH}" ]                                                                 && \
        {
            echo "Path to directory with packages must be provided as first argument !!!"
            return -1
        }

    PACKAGES_PATH=`echo ${PACKAGES_PATH}/ | sed 's/\/\//\//g'`

    QIMSDK_ESDK_DEVICE_INSTALL_PREFIX="$(cat ${PACKAGES_PATH}qim-sdk-install-prefix.txt 2> /dev/null)"

    adb push ${PACKAGES_PATH}qim-sdk.sh /etc/profile.d/ || return -2
    qimsdk-local-device-command "mkdir -p ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc" || return -3
    qimsdk-local-device-command "source /etc/profile.d/qim-sdk.sh" || return -4

    [ -n "$(find ${PACKAGES_PATH} -maxdepth 1 -name '*.ipk' -type f -print -quit)" ]            && \
        {
            qimsdk-local-set-opkg-prefix
        }

    local PKGS=(`ls ${PACKAGES_PATH}`)
    local LOCAL_LOG_FILE="${PACKAGES_PATH}local_md5.log"
    local REMOTE_LOG_FILE="${PACKAGES_PATH}remote_sync.log"
    local DEVICE_LOG_FILE="${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/device_sync.log"
    local DEVICE_PULLED_LOG_FILE="${PACKAGES_PATH}device_sync.log"

    # Pull device sync log file
    qimsdk-local-device-command "[ -f ${DEVICE_LOG_FILE} ]" 2>&1>/dev/null                      || \
        {
            qimsdk-local-device-command "touch ${DEVICE_LOG_FILE}"
        }

    adb pull ${DEVICE_LOG_FILE} ${PACKAGES_PATH}                                                || \
        {
            echo "Failed to pull device log !!!"
            return -5
        }

    for PACKAGE in ${PKGS[@]}; do
        local FILE="${PACKAGES_PATH}${PACKAGE}"
        local PACKAGE_FORMAT=$(basename -- "${FILE}")

        # Skip Non-package files
        [ "${PACKAGE}" == "qim-sdk-install-prefix.txt" ] && continue;
        [ "${PACKAGE}" == "qim-sdk.sh" ] && continue;
        [ "${PACKAGE}" == "local_md5.log" ] && continue;
        [ "${PACKAGE}" == "device_sync.log" ] && continue;
        [ "${PACKAGE}" == "remote_sync.log" ] && continue;
        [ "${PACKAGE}" == "sdk-tools-git-logs.txt" ] && continue;

        local CHECKSUM=`grep "/${PACKAGE}" ${LOCAL_LOG_FILE} | cut -d ' ' -f1`
        PACKAGE_FORMAT="${PACKAGE_FORMAT##*.}"
        grep -q "${CHECKSUM}" ${DEVICE_PULLED_LOG_FILE} 2>&1>/dev/null                          || \
            {
                [ "${PACKAGE_FORMAT}" == "deb" ]                                                && \
                    {
                        adb push "${FILE}" /tmp/                                                || \
                            {
                                echo "Push package to device failed !!!";
                                return -6;
                            }

                        qimsdk-local-device-command "dpkg --instdir=${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX} --install --force-all /tmp/${PACKAGE}" || \
                            {
                                qimsdk-local-device-command "rm /tmp/${PACKAGE}";
                                echo "Install package to device failed !!!";
                                return -7;
                            }
                    }

                [ "${PACKAGE_FORMAT}" == "ipk" ]                                                && \
                    {
                        adb push "${FILE}" /tmp/                                                || \
                            {
                                echo "Push package to device failed !!!";
                                return -8;
                            }

                        qimsdk-local-device-command "opkg install -d qimsdk_install_path --force-reinstall --force-depends --force-overwrite /tmp/${PACKAGE}" || \
                            {
                                qimsdk-local-device-command "rm /tmp/${PACKAGE}";
                                adb push ${PACKAGES_PATH}device_sync.log ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/ || \
                                    {
                                        echo "Failed to push updated log to device !!!"
                                        return -9
                                    }
                                echo "Install package to device failed !!!";
                                return -10;
                            }
                    }
                sed -i "/\/${PACKAGE}/d" ${DEVICE_PULLED_LOG_FILE} 2>&1>/dev/null
                echo "${CHECKSUM} /${PACKAGE}" >> ${DEVICE_PULLED_LOG_FILE}
                qimsdk-local-device-command "rm -f /tmp/${PACKAGE}"
                rm -f ${FILE}
            }
    done

    adb push ${PACKAGES_PATH}device_sync.log ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/          || \
        {
            echo "Failed to push updated log to device !!!"
            return -11
        }

    rm -f "${DEVICE_PULLED_LOG_FILE}"
    rm -f "${LOCAL_LOG_FILE}"
    rm -f "${REMOTE_LOG_FILE}"

    echo "Device synced successfully !!!"
}

# Uninstall packages previously installed on the devices
#   $1 - (mandatory) path to the packages to be synced
function qimsdk-local-packages-remove() {
    local PACKAGES_PATH=$1
    [ ! -d "${PACKAGES_PATH}" ]                                                                 && \
        {
            echo "Path to directory with packages must be provided as first argument !!!"
            return -1
        }

    QIMSDK_ESDK_DEVICE_INSTALL_PREFIX="$(cat ${PACKAGES_PATH}qim-sdk-install-prefix.txt 2> /dev/null)"

    qimsdk-local-device-command "rm -rf ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}"                   || \
        {
            echo "Device uninstall failed !!!";
            return -2;
        }

    echo "Packages uninstalled successfully !!!"
}

# Print help
echo "qimsdk-local-sync"
echo "    must be invoked to sync packages with the device from specified directory"
echo "qimsdk-local-packages-remove"
echo "    must be invoked to uninstall packages previously installed on the device"
