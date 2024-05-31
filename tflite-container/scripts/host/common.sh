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

# Parse json configuraiton
#   $1 - (mandatory) path to target config json
#   $2 - /output/ (mandatory) image
#   $3 - /output/ (mandatory) device os
#   $4 - /output/ (mandatory) additional tag
#   $5 - /output/ (mandatory) tflite version
#   $6 - /output/ (mandatory) container name
#   $7 - /output/ (optional) rsync destination
#   $8 - /output/ (mandatory for LE) full path to sdk file
#   $9 - /output/ (mandatory) environment setup script of sdk
#   $10 - /output/ (mandatory) to enable/disable hexagon delegate option
#   $11 - /output/ (mandatory) to enable/disable gpu delegate option
#   $12 - /output/ (mandatory) to enable/disable xnnpack delegate option
#   $13 - /output/ (mandatory) to specify device install prefix
#   $14 - /output/ (mandatory) to specify target sys
function tflite-tools-host-parse-json() {
    local PATH_TO_CONFIG_JSON=$1
    local -n OUT_IMAGE=$2
    local -n OUT_DEVICE_OS=$3
    local -n OUT_ADDITIONAL_TAG=$4
    local -n OUT_TFLITE_VERSION=$5
    local -n OUT_CONTAINER_NAME=$6
    local -n OUT_TFLITE_RSYNC_DST=$7
    local -n OUT_SDK_FULL_PATH=$8
    local -n OUT_SDK_ENV_SETUP_SCRIPT=$9
    local -n OUT_HEXAGON_DELEGATE=${10}
    local -n OUT_GPU_DELEGATE=${11}
    local -n OUT_XNNPACK_DELEGATE=${12}
    local -n OUT_TFLITE_DEVICE_INSTALL_PREFIX=${13}
    local -n OUT_TFLITE_TARGET_SYS=${14}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ]                                                                               && \
        print-red "Path to config json must be provided as first argument !!!"                                      && \
        return -1

    local BUFFER=`cat ${PATH_TO_CONFIG_JSON}`

    OUT_IMAGE=`echo ${BUFFER} | jq '.Image' | tr -d '"'`

    OUT_DEVICE_OS=`echo ${BUFFER} |  jq '.Device_OS' | tr -d '"'`
    [ ! "${OUT_DEVICE_OS}" == "le" ] && [ ! "${OUT_DEVICE_OS}" == "la" ] && [ ! "${OUT_DEVICE_OS}" == "lu" ]        && \
        print-red "Reconfigure Device_OS attribute with correct data in targets/.json file !!!"                     && \
        print-yellow "Avaliable OS are le, lu and la."                                                              && \
        return -3

    OUT_ADDITIONAL_TAG=`echo ${BUFFER} |  jq '.Additional_tag' | tr -d '"'`
    [[ ! -z "${OUT_ADDITIONAL_TAG}" ]] && OUT_ADDITIONAL_TAG="-${OUT_ADDITIONAL_TAG}"

    OUT_TFLITE_VERSION=`echo ${BUFFER} | jq '.TFLite_Version' | tr -d '"'`
    [ ! "${OUT_TFLITE_VERSION}" == "2.16.1" ]                                                                       && \
    [ ! "${OUT_TFLITE_VERSION}" == "2.15.1" ]                                                                       && \
    [ ! "${OUT_TFLITE_VERSION}" == "2.15.0" ]                                                                       && \
    [ ! "${OUT_TFLITE_VERSION}" == "2.14.1" ]                                                                       && \
    [ ! "${OUT_TFLITE_VERSION}" == "2.13.1" ]                                                                       && \
    [ ! "${OUT_TFLITE_VERSION}" == "2.12.1" ]                                                                       && \
    [ ! "${OUT_TFLITE_VERSION}" == "2.11.1" ]                                                                       && \
    [ ! "${OUT_TFLITE_VERSION}" == "2.10.1" ]                                                                       && \
    [ ! "${OUT_TFLITE_VERSION}" == "2.8.0" ]                                                                        && \
    [ ! "${OUT_TFLITE_VERSION}" == "2.6.0" ]                                                                        && \
        print-red "Reconfigure Version attribute with correct data in targets/.json file !!!"                       && \
        print-yellow "Avaliable versions are:"                                                                      && \
        print-yellow "2.16.1, 2.15.1, 2.15.0, 2.14.1, 2.13.1, 2.12.1, 2.11.1, 2.10.1, 2.8.0 and 2.6.0 !!!"                          && \
        return -4

    OUT_TFLITE_RSYNC_DST=`echo ${BUFFER} | jq '.TFLite_rsync_destination' | tr -d '"'`

    local SDK_PATH=`echo ${BUFFER} | jq '.SDK_path' | tr -d '"'`
    local SDK_FILE=`echo ${BUFFER} | jq '.SDK_shell_file' | tr -d '"'`
    OUT_SDK_FULL_PATH=${SDK_PATH}/${SDK_FILE}

    [ "${OUT_DEVICE_OS}" == "le" ] || [ "${OUT_DEVICE_OS}" == "lu" ] && [ ! -f ${OUT_SDK_FULL_PATH} ]               && \
        print-red "SDK path and file are not specified !!!"                                                         && \
        return -5

    local SDK_JSON=${SDK_FILE%.*}
    SDK_JSON="${SDK_JSON}.testdata.json"

    local ENV_SCRIPT_VAR_SUFFIX=""
    cat ${SDK_PATH}/${SDK_JSON} | grep env_setup_script_llvm > /dev/null && ENV_SCRIPT_VAR_SUFFIX="_llvm"

    local ENV_SCRIPT_VAR="env_setup_script${ENV_SCRIPT_VAR_SUFFIX}"

    OUT_TFLITE_TARGET_SYS=`cat ${SDK_PATH}/${SDK_JSON} | jq '.TARGET_SYS' | tr -d '"'`

    local POST_SDK_ENV_SETUP_SCRIPT=$(cat ${SDK_PATH}/${SDK_JSON} | grep "${ENV_SCRIPT_VAR}")

    OUT_SDK_ENV_SETUP_SCRIPT=${POST_SDK_ENV_SETUP_SCRIPT#*$ENV_SCRIPT_VAR}

    OUT_SDK_ENV_SETUP_SCRIPT=$(echo ${OUT_SDK_ENV_SETUP_SCRIPT} | cut -d '\' -f 2 | cut -d '/' -f 2)

    OUT_CONTAINER_NAME="${OUT_DEVICE_OS}-${OUT_IMAGE}-${OUT_TFLITE_VERSION}${OUT_ADDITIONAL_TAG}"

    local DELEGATE_BUFFER=`echo ${BUFFER} | jq '.Delegates'`

    OUT_HEXAGON_DELEGATE=`echo ${DELEGATE_BUFFER} | jq '.Hexagon_delegate' | tr -d '"'`
    OUT_GPU_DELEGATE=`echo ${DELEGATE_BUFFER} | jq '.Gpu_delegate' | tr -d '"'`
    OUT_XNNPACK_DELEGATE=`echo ${DELEGATE_BUFFER} | jq '.Xnnpack_delegate' | tr -d '"'`

    OUT_TFLITE_DEVICE_INSTALL_PREFIX=`echo ${BUFFER} | jq '.Device_install_prefix' | tr -d '"'`

    OUT_TFLITE_DEVICE_INSTALL_PREFIX=`echo ${OUT_TFLITE_DEVICE_INSTALL_PREFIX} | tr -s '/'`

    return 0
}

# Get CONTAINER_NAME from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give container name as argument
function tflite-tools-get-container-image-name() {
    local PATH_TO_CONFIG_JSON=$1
    local -n CONTAINER_NAME_OUT=$2
    local -n OUT_IMAGE=$3
    local DEVICE_OS
    local ADDITIONAL_TAG
    local TFLITE_VERSION
    local TFLITE_RSYNC_DST
    local SDK_FULL_PATH
    local SDK_ENV_SETUP_SCRIPT
    local HEXAGON_DELEGATE
    local GPU_DELEGATE
    local XNNPACK_DELEGATE
    local TFLITE_DEVICE_INSTALL_PREFIX
    local TFLITE_TARGET_SYS
    local IMAGE

    tflite-tools-host-parse-json ${PATH_TO_CONFIG_JSON} IMAGE DEVICE_OS ADDITIONAL_TAG TFLITE_VERSION CONTAINER_NAME_OUT TFLITE_RSYNC_DST SDK_FULL_PATH SDK_ENV_SETUP_SCRIPT HEXAGON_DELEGATE GPU_DELEGATE XNNPACK_DELEGATE TFLITE_DEVICE_INSTALL_PREFIX TFLITE_TARGET_SYS
    OUT_IMAGE="${IMAGE}"
}

# Propagate errors from adb shell
#   $1 - (mandatory) cmd to be executed
#   $2 - (optional) device ID
function tflite-tools-device-command () {
    local CMD=$1
    local DEVICE_ID=$2
    local rc

    (
        [ ! -z ${DEVICE_ID} ] && {
            export ANDROID_SERIAL=${DEVICE_ID}
        }

        local rc

        adb shell "${CMD} && echo 0 > /data/rc.txt"
        rc=$?
        [ $rc -ne 0 ] && print-red "Executing Command ${CMD} failed !!!" && return $rc

        adb pull /data/rc.txt /tmp/rc.txt 2>&1 > /dev/null
        rc=$?
        adb shell "rm -f /data/rc.txt"
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
function tflite-device-prepare() {
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

        tflite-device-command "mount -o remount,rw / > /dev/null" ${DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb file system remount failed !!!" && return -3

        tflite-device-command "! command -v setenforce || setenforce 0" ${DEVICE_ID}
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
function tflite-get-device-id() {
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

print-yellow "tflite-device-prepare                                    <Device-ID (optional argument)>"
echo "    Prepare device after reboot"
