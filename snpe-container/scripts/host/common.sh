#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

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

# Propagate errors from adb shell
#   $1 - (mandatory) cmd to be executed
#   $2 - (optional) device ID
function qml-device-command () {
    local CMD=$1
    local DEVICE_ID=$2
    local rc

    (
        [ ! -z ${DEVICE_ID} ] && {
            export ANDROID_SERIAL=${DEVICE_ID}
        }

        local rc

        adb shell "${CMD} && echo 0 > /tmp/rc.txt"
        rc=$?
        [ $rc -ne 0 ] && print-red "Executing Command ${CMD} failed !!!" && return $rc

        adb pull /tmp/rc.txt /tmp/rc.txt 2>&1 > /dev/null
        rc=$?
        adb shell "rm -f /tmp/rc.txt"
        [ $rc -ne 0 ] && (rm -f /tmp/rc.txt; print-red "Command ${CMD} failed !!!") && return $rc

        rc=`cat /tmp/rc.txt`
        rm -f /tmp/rc.txt
        [ $rc -ne 0 ] && print-red "Command ${CMD} return code is not 0 !!!" && return $rc

        return 0
    )

    rc=$?

    return $rc
}

# Prepare device after reboot
#   $1 - (optional) device ID
function qml-device-prepare() {
    local DEVICE_ID=$1

    local rc

    echo "Waiting for device"

    (
        [ ! -z ${DEVICE_ID} ] && {
            export ANDROID_SERIAL=${DEVICE_ID}
        }

        local rc

        adb wait-for-device root
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb root failed !!!" && return -1

        adb wait-for-device remount wait-for-device
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb remount failed !!!" && return -2

        qml-device-command "mount -o remount,rw / > /dev/null" ${DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb file system remount failed !!!" && return -3

        qml-device-command "! command -v setenforce || setenforce 0" ${DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb disable SE Linux failed !!!" && return -4

        return 0
    )

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: Device prepare !!!"
        return $rc
    }

    print-green "Device prepared successfully !!!"

    return 0
}

# Get container and image from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give container name as argument
#   $2 - (mandatory) give image name as argument
function qml-get-container-and-image-name() {
    local PATH_TO_CONFIG_JSON=$1
    local -n OUT_QML_CONTAINER_NAME=$2
    local -n OUT_QML_IMAGE_NAME=$3

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local QML_ADDITIONAL_TAG=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_container' | tr -d '"')

    if [ -z "${QML_ADDITIONAL_TAG}" -o "${QML_ADDITIONAL_TAG}"="null" ]; then
        QML_ADDITIONAL_TAG=""
    else
        QML_ADDITIONAL_TAG="-${QML_ADDITIONAL_TAG}"
    fi

    OUT_QML_CONTAINER_NAME="qml${QML_ADDITIONAL_TAG}"

    local ADDITIONAL_TAG_IMAGE=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_image' | tr -d '"')

    if [ -z "${ADDITIONAL_TAG_IMAGE}" -o "${ADDITIONAL_TAG_IMAGE}"="null" ]; then
        ADDITIONAL_TAG_IMAGE=""
    else
        ADDITIONAL_TAG_IMAGE="-${ADDITIONAL_TAG_IMAGE}"
    fi

    OUT_QML_IMAGE_NAME="qml${ADDITIONAL_TAG_IMAGE}"

    return 0
}

# Get remote sync destination from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give URL as argument
function qml-get-url() {
    local PATH_TO_CONFIG_JSON=$1
    local -n OUT_URL=$2

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_URL=$(echo ${JSON_CONTENT} |  jq '.URL' | tr -d '"')

    [ -z "${OUT_URL}" ] && {
        print-red "URL attribute in config.json is not set !!!"
        return -2
    }

    return 0
}

# Get Device ID from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Device ID as argument
function qml-get-device-id() {
    local PATH_TO_CONFIG_JSON=$1
    local -n OUT_DEVICE_ID=$2

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_DEVICE_ID=$(echo ${JSON_CONTENT} |  jq '.DeviceID' | tr -d '"')

    [ -z "${OUT_DEVICE_ID}" ] && {
        print-red "DeviceID attribute in config.json is not set !!!"
        return -2
    }

    return 0
}

print-yellow "qml-device-prepare                                    <Device-ID (optional argument)>"
echo "    Prepare device after reboot"
