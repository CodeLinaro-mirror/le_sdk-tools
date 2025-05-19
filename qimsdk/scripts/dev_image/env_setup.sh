#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Propagate errors from adb shell
#   $1 - (mandatory) cmd to be executed
#   $2 - (optional) device ID
function qimsdk-device-command () {
    local CMD=${1}
    local TARGET_DEVICE_ID=${2}
    local rc

    (
        [ ! -z ${TARGET_DEVICE_ID} ] && {
            export ANDROID_SERIAL=${TARGET_DEVICE_ID}
        }

        local rc

        adb shell "${CMD} && echo 0 > /tmp/rc.txt"
        rc=$?
        [ ${rc} -ne 0 ] && print-red "Executing Command ${CMD} failed !!!" && return ${rc}

        adb pull /tmp/rc.txt /tmp/rc.txt 2>&1 > /dev/null
        rc=$?
        adb shell "rm -f /tmp/rc.txt"
        [ ${rc} -ne 0 ] && (rm -f /tmp/rc.txt; print-red "Command ${CMD} failed !!!")           && \
            return ${rc}

        rc=`cat /tmp/rc.txt`
        rm -f /tmp/rc.txt
        [ ${rc} -ne 0 ] && print-red "Command ${CMD} return code is not 0 !!!" && return ${rc}

        return 0
    )

    rc=$?

    return ${rc}
}

function print-red() {
    tput setaf 1 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

function print-green() {
    tput setaf 2 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

function print-yellow() {
    tput setaf 3 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

function print-blue() {
    tput setaf 4 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

# Source all scripts
for f in ${QIMSDK_SCRIPTS}/*.sh; do
    [ "${f}" == "${QIMSDK_SCRIPTS}/env_setup.sh" ] || source ${f}
done
$@
