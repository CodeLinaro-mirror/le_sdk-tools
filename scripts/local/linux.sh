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

# Sync packages with the device from specified directory
#   $1 - (mandatory) path to the packages to be synced
function qimsdk-local-sync() {
    local PACKAGES_PATH=$1
    [ ! -d "${PACKAGES_PATH}" ] || [ -z "${PACKAGES_PATH}" ]                                    && \
        {
            echo "Path to directory with packages must be provided as first argument !!!"
            return -1
        }

    PACKAGES_PATH=`echo ${PACKAGES_PATH}/ | sed 's/\/\//\//g'`

    local FILE
    for FILE in ${PACKAGES_PATH}*; do
        local PACKAGE=$(basename "${FILE}")
        local PACKAGE_FORMAT=$(basename -- "${FILE}")

        PACKAGE_FORMAT="${PACKAGE_FORMAT##*.}"

        adb push "${FILE}" /tmp/                                                                || \
            {
                echo "Push package to device failed !!!";
                return -1;
            }

        [ "${PACKAGE_FORMAT}" == "deb" ]                                                        && \
            {
                qimsdk-local-device-command "dpkg --install --force-all /tmp/${PACKAGE}"   || \
                    {
                        adb shell "rm -f /tmp/${PACKAGE}"
                        print-red "Install package to device failed !!!";
                        return -2;
                    }
            }

        [ "${PACKAGE_FORMAT}" == "ipk" ]                                                        && \
            {
                qimsdk-local-device-command "opkg --force-depends --force-reinstall --force-overwrite install /tmp/${PACKAGE}" || \
                    {
                        qimsdk-local-device-command "rm -f /tmp/${PACKAGE}"
                        print-red "Install package to device failed !!!";
                        return -3;
                    }
            }

        # Get package name and add it to uninstall script
        local PACKAGE_NAME=`echo ${PACKAGE} | cut -d '_' -f 1`
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

        qimsdk-local-device-command "rm -f /tmp/${PACKAGE}"
        rm -f ${FILE}
    done

    echo "Device synced successfully !!!"
}

# Uninstall packages previously installed on the devices
#   $1 - (mandatory) path to the packages to be synced
function qimsdk-local-packages-remove() {
    local PACKAGES_PATH=$1
    [ ! -d "${PACKAGES_PATH}" ] || [ -z "${PACKAGES_PATH}" ]                                    && \
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
            return -3
        }

    echo "Packages uninstalled successfully !!!"
}

# Print help
echo "qimsdk-local-sync"
echo "    must be invoked to sync packages with the device from specified directory"
echo "qimsdk-local-packages-remove"
echo "    must be invoked to uninstall packages previously installed on the device"
