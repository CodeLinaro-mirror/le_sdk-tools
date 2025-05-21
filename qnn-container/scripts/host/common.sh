#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
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

# Parse json configuraiton
#   $1 - (mandatory) path to target config json
#   $2 - /output/ (mandatory) image
#   $3 - /output/ (mandatory) target platform qcm6490
#   $4 - /output/ (mandatory) container name
#   $5 - /output/ (mandatory) Docker Image name
#   $6 - /output/ (mandatory) qnn version as downloaded
function qnn-tools-parse-json() {

    local PATH_TO_CONFIG_JSON=$1
    local -n OUT_QNN_BASE_IMAGE=$2
    local -n OUT_QNN_TARGET_PLATFORM=$3
    local -n OUT_QNN_CONTAINER_NAME=$4
    local -n OUT_QNN_IMAGE_NAME=$5
    local -n OUT_QNN_VERSION=$6

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QNN_BASE_IMAGE=$(echo ${JSON_CONTENT} | jq '.Base_Image' | tr -d '"')
    [ -z "${OUT_QNN_BASE_IMAGE}" ] && {
        print-red "Base_Image tag in json file must be set !!!"
        return -2
    }

    OUT_QNN_TARGET_PLATFORM=$(echo ${JSON_CONTENT} | jq '.Target_platform' | tr -d '"')
    [ -z "${OUT_QNN_TARGET_PLATFORM}" ] && {
        print-red "Target_platform attribute is not set in json file !!!"
        print-yellow "Target_platform attribute can be: kalama or qcs6490 or qrb5165 or qcs9100 or qcs8300."
        return -3
    }

    OUT_QNN_VERSION=$(echo ${JSON_CONTENT} | jq '.Qnn_Version' | tr -d '"')
    [ -z "${OUT_QNN_VERSION}" ] && {
        print-red "Qnn_Version tag in json file must be set !!!"
        return -4
    }

    OUT_ADDITIONAL_TAG=$(echo ${JSON_CONTENT} | jq '.Additional_tag' | tr -d '"')
    [ ! -z "${OUT_ADDITIONAL_TAG}" ] && {
        OUT_ADDITIONAL_TAG="-${OUT_ADDITIONAL_TAG}"
    }

    OUT_QNN_CONTAINER_NAME="qnn-${OUT_QNN_VERSION}${OUT_ADDITIONAL_TAG}"
    OUT_QNN_IMAGE_NAME="qnn-${OUT_QNN_VERSION}${OUT_ADDITIONAL_TAG}"

    return 0
}

# Get CONTAINER_NAME from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give container name as argument
#   $3 - (mandatory) give image name as argument
function qnn-tools-get-container-image-name() {
    local PATH_TO_CONFIG_JSON=$1
    local -n OUT_QNN_CONTAINER_NAME=$2
    local -n OUT_QNN_IMAGE_NAME=$3

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})
    local OUT_QNN_VERSION=$(echo ${JSON_CONTENT} | jq '.Qnn_Version' | tr -d '"')
    [ -z "${OUT_QNN_VERSION}" ] && {
        print-red "Qnn_Version tag in json file must be set !!!"
        return -1
    }

    local OUT_ADDITIONAL_TAG=$(echo ${JSON_CONTENT} | jq '.Additional_tag' | tr -d '"')
    [ ! -z "${OUT_ADDITIONAL_TAG}" ] && {
        OUT_ADDITIONAL_TAG="-${OUT_ADDITIONAL_TAG}"
    }

    OUT_QNN_CONTAINER_NAME="qnn-${OUT_QNN_VERSION}${OUT_ADDITIONAL_TAG}"
    OUT_QNN_IMAGE_NAME="qnn-${OUT_QNN_VERSION}${OUT_ADDITIONAL_TAG}"

    return 0
}

# Propagate errors from adb shell
#   $1 - (mandatory) cmd to be executed
#   $2 - (optional) device ID
function qnn-tools-device-command () {
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
function qnn-device-prepare() {
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

        qnn-device-command "mount -o remount,rw / > /dev/null" ${DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb file system remount failed !!!" && return -3

        qnn-device-command "! command -v setenforce || setenforce 0" ${DEVICE_ID}
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

# Get Device ID from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Device ID as argument
function qnn-get-device-id() {
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

# Get Device ID from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give URL as argument
function qnn-get-url() {
    local PATH_TO_CONFIG_JSON=$1
    local -n OUT_QNN_URL=$2

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QNN_URL=$(echo ${JSON_CONTENT} |  jq '.URL' | tr -d '"')
    [ -z "${OUT_QNN_URL}" ] && {
        print-red "URL attribute in config.json is not set !!!"
        return -2
    }

    return 0
}

print-yellow "qnn-device-prepare                                    <Device-ID (optional argument)>"
echo "    Prepare device after reboot"
