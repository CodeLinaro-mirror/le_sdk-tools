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

# Get list of packages
#   $1 - (mandatory) path to the packages
function qimsdk-local-get-list-of-packages() {
    local PACKAGES_PATH=$1
    IFS=$'\n' read -r -d '' -a PKGS < <( find ${PACKAGES_PATH} \( -name "*.ipk" -o -name "*.deb" \))
}

# Check the installed packages on the target
#   $1 - (mandatory) path to the packages
function qimsdk-local-check-installed-packages() {
    local PACKAGES_PATH=$1
    local rc

    qimsdk-local-device-command "ls ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/device_sync.log" > /dev/null 2>&1    || \
        {
            # Get list of packages
            qimsdk-local-get-list-of-packages ${PACKAGES_PATH}

            local INITIALLY_INSTALLED_PKGS

            find ${PACKAGES_PATH}/*.deb > /dev/null 2>&1
            rc=$?

            [ "$rc" -eq 0 ]                                                                     && \
                INITIALLY_INSTALLED_PKGS=$(adb shell dpkg --get-selections | awk '{print $1}')  || \
                    INITIALLY_INSTALLED_PKGS=$(adb shell opkg list-installed | cut -d ' ' -f 1)

            [ -z "${INITIALLY_INSTALLED_PKGS}" ]                                                && \
                {
                    tput setaf 1 2>/dev/null
                    echo "Failed to get list of initially installed packages";
                    echo "Please, check adb connection with the device.";
                    tput sgr0 2>/dev/null
                    return -1
                }

            for PKG in "${PKGS[@]}"; do
                PKG_NAME=$(basename -- ${PKG} | cut -d '_' -f 1 )
                echo ${INITIALLY_INSTALLED_PKGS} | grep -wq "${PKG_NAME}"
                rc=$?
                [ "${rc}" -eq 0 ]                                                               && \
                {
                    tput setaf 1 2>/dev/null
                    echo ${PKG_NAME} \(${PKG}\) is already installed on the target. Exiting...
                    tput sgr0 2>/dev/null
                    return -2
                }
            done

        return 0
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

    qimsdk-local-check-installed-packages ${PACKAGES_PATH}
    rc=$?
    [ "${rc}" -eq 0 ] || return -2

    adb push ${PACKAGES_PATH}qim-sdk.sh /etc/profile.d/ || return -3
    qimsdk-local-device-command "mkdir -p ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc" || return -4
    qimsdk-local-device-command "source /etc/profile.d/qim-sdk.sh" || return -5

    [ -n "$(find ${PACKAGES_PATH} -maxdepth 1 -name '*.ipk' -type f -print -quit)" ]            && \
        {
            qimsdk-local-set-opkg-prefix
        }

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
            return -6
        }

    for PACKAGE in ${PKGS[@]}; do
        local FILE="${PACKAGE}"
        local PACKAGE_FILE_NAME=$(basename -- "${FILE}")

        local CHECKSUM=`grep "/${PACKAGE_FILE_NAME}" ${LOCAL_LOG_FILE} | cut -d ' ' -f1`
        PACKAGE_FORMAT="${PACKAGE_FILE_NAME##*.}"
        grep -q "${CHECKSUM}" ${DEVICE_PULLED_LOG_FILE} 2>&1>/dev/null                          || \
            {
                [ "${PACKAGE_FORMAT}" == "deb" ]                                                && \
                    {
                        adb push "${FILE}" /tmp/                                                || \
                            {
                                echo "Push package to device failed !!!";
                                return -7;
                            }

                        qimsdk-local-device-command "dpkg --instdir=${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX} --install --force-all /tmp/${PACKAGE_FILE_NAME}" || \
                            {
                                qimsdk-local-device-command "rm /tmp/${PACKAGE_FILE_NAME}";
                                echo "Install package to device failed !!!";
                                return -8;
                            }
                    }

                [ "${PACKAGE_FORMAT}" == "ipk" ]                                                && \
                    {
                        adb push "${FILE}" /tmp/                                                || \
                            {
                                echo "Push package to device failed !!!";
                                return -9;
                            }

                        qimsdk-local-device-command "opkg install -d qimsdk_install_path --force-reinstall --force-depends --force-overwrite /tmp/${PACKAGE_FILE_NAME}" || \
                            {
                                qimsdk-local-device-command "rm /tmp/${PACKAGE_FILE_NAME}";
                                adb push ${PACKAGES_PATH}device_sync.log ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/ || \
                                    {
                                        echo "Failed to push updated log to device !!!"
                                        return -10
                                    }
                                echo "Install package to device failed !!!";
                                return -11;
                            }
                    }

                # Get package name and add it to uninstall script
                local PACKAGE_NAME=`echo ${PACKAGE_FILE_NAME} | cut -d '_' -f 1`
                grep "${PACKAGE_NAME}" ${PACKAGES_PATH}uninstall.sh 2>&1 > /dev/null                    || \
                    {
                        [ "${PACKAGE_FORMAT}" == "deb" ]                                                && \
                            {
                                echo "dpkg --remove --force-all ${PACKAGE_NAME}" >> ${PACKAGES_PATH}uninstall.sh
                            }

                        [ "${PACKAGE_FORMAT}" == "ipk" ]                                                && \
                            {
                                echo "opkg remove --force-depends ${PACKAGE_NAME}" >> ${PACKAGES_PATH}uninstall.sh
                            }
                    }
                sed -i "/\/${PACKAGE_NAME}/d" ${DEVICE_PULLED_LOG_FILE} 2>&1>/dev/null
                echo "${CHECKSUM} /${PACKAGE_NAME}" >> ${DEVICE_PULLED_LOG_FILE}
                qimsdk-local-device-command "rm -f /tmp/${PACKAGE_NAME}"
                rm -f ${FILE}
            }
    done

    adb push ${PACKAGES_PATH}device_sync.log ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/          || \
        {
            echo "Failed to push updated log to device !!!"
            return -12
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

    PACKAGES_PATH=`echo ${PACKAGES_PATH}/ | sed 's/\/\//\//g'`

    # Call uninstall script for according Packages Path
    adb push ${PACKAGES_PATH}uninstall.sh /tmp                                                  || \
        {
            echo "Pushing uninstall command to device failed !!!"
            return -2
        }

    qimsdk-local-device-command "source /tmp/uninstall.sh"                                      || \
        {
            echo "Uninstall command execution failed !!!"
            return -3;
        }

    echo "Packages uninstalled successfully !!!"
}

# Print help
echo "qimsdk-local-sync"
echo "    must be invoked to sync packages with the device from specified directory"
echo "qimsdk-local-packages-remove"
echo "    must be invoked to uninstall packages previously installed on the device"
