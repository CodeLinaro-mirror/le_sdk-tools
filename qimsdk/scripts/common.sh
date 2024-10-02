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
        [ ${rc} -ne 0 ] && (rm -f /tmp/rc.txt; print-red "Command ${CMD} failed !!!") && return ${rc}

        rc=`cat /tmp/rc.txt`
        rm -f /tmp/rc.txt
        [ ${rc} -ne 0 ] && print-red "Command ${CMD} return code is not 0 !!!" && return ${rc}

        return 0
    )

    rc=$?

    return ${rc}
}

# Prepare device after reboot
#   $1 - (optional) device ID
function qimsdk-device-prepare() {
    local TARGET_DEVICE_ID=${1}

    local rc

    echo "Waiting for device"

    (
        [ ! -z ${TARGET_DEVICE_ID} ] && {
            export ANDROID_SERIAL=${TARGET_DEVICE_ID}
        }

        local rc

        adb wait-for-device root wait-for-device
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb root failed !!!" && return -1

        adb wait-for-device remount wait-for-device
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb remount failed !!!" && return -2

        qimsdk-device-command "mount -o remount,rw / > /dev/null" ${TARGET_DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb file system remount failed !!!" && return -3

        qimsdk-device-command "! command -v setenforce || setenforce 0" ${TARGET_DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb disable SE Linux failed !!!" && return -4

        return 0
    )

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: Device prepare !!!"
        return ${rc}
    }

    print-green "Device prepared successfully !!!"

    return 0
}

# Get container and image from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give container name as argument
#   $2 - (mandatory) give image name as argument
function qimsdk-get-container-and-image-name() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_CONTAINER_NAME=${2}
    local -n OUT_QIMSDK_IMAGE_NAME=${3}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local QIMSDK_ADDITIONAL_TAG=$(
        echo ${JSON_CONTENT} |  jq '.Additional_tag_container' | tr -d '"'
    )

    [ ! -z "${QIMSDK_ADDITIONAL_TAG}" ] && {
        QIMSDK_ADDITIONAL_TAG="-${QIMSDK_ADDITIONAL_TAG}"
    }

    OUT_QIMSDK_CONTAINER_NAME="qimsdk${QIMSDK_ADDITIONAL_TAG}"

    local ADDITIONAL_TAG_IMAGE=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_image' | tr -d '"')

    [ ! -z "${ADDITIONAL_TAG_IMAGE}" ] && {
        ADDITIONAL_TAG_IMAGE="-${ADDITIONAL_TAG_IMAGE}"
    }

    OUT_QIMSDK_IMAGE_NAME="qimsdk${ADDITIONAL_TAG_IMAGE}"

    return 0
}

# Get remote sync destination from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Docker_image_path as argument
function qimsdk-get-docker-image-path() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_DOCKER_IMAGE_PATH=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_DOCKER_IMAGE_PATH=$(echo ${JSON_CONTENT} |  jq '.Docker_image_path' | tr -d '"')

    [ -z "${OUT_DOCKER_IMAGE_PATH}" ] && {
        print-red "Docker_image_path attribute in config.json is not set !!!"
        return -2
    }

    return 0
}

# Get Device ID from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Device ID as argument
function qimsdk-get-device-id() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_TARGET_DEVICE_ID=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_TARGET_DEVICE_ID=$(echo ${JSON_CONTENT} |  jq '.Target_device_ID' | tr -d '"')

    [ -z "${OUT_TARGET_DEVICE_ID}" ] && {
        print-red "Target_device_ID attribute in config.json is not set !!!"
        return -2
    }

    return 0
}

# Get Platform_Specific_Mappings from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Platform specific map as argument
function qimsdk-get-platform-specific-mapping() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_PLATFORM_SPECIFIC_MAP=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    declare -a PLATFORM_SPECIFIC_MAPS_ARRAY

    PLATFORM_SPECIFIC_MAPS_ARRAY=$(
        echo ${JSON_CONTENT} | jq '.Platform_Specific_Mappings[]' | tr -d '"'
    )

    [ -z "${PLATFORM_SPECIFIC_MAPS_ARRAY}" ] && {
        print-red "Platform_Specific_Mappings attribute in ${PATH_TO_CONFIG_JSON} is not set !!!"
        return -2
    }

    declare -a PLATFORM_SPECIFIC_MAPS_ARRAY_TEMP=""

    for SPECIFIC_MAP in ${PLATFORM_SPECIFIC_MAPS_ARRAY[@]}; do

        PLATFORM_SPECIFIC_MAPS_ARRAY_TEMP+="--device ${SPECIFIC_MAP} "

    done

    OUT_PLATFORM_SPECIFIC_MAP=${PLATFORM_SPECIFIC_MAPS_ARRAY_TEMP}

    return 0
}

# Get Platform_Libraries_To_Mount from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Platform specific libraries to be mounted as argument
function qimsdk-get-platform-libs-to-mount() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_PLATFORM_SPECIFIC_LIBS=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    declare -a PLATFORM_SPECIFIC_LIBS_ARRAY

    PLATFORM_SPECIFIC_LIBS_ARRAY=$(
        echo ${JSON_CONTENT} | jq '.Platform_Libraries_To_Mount[]' | tr -d '"'
    )

    [ -z "${PLATFORM_SPECIFIC_LIBS_ARRAY}" ] && {
        print-red "Platform_Libraries_To_Mount attribute in ${PATH_TO_CONFIG_JSON} is not set !!!"
        return -2
    }

    declare -a PLATFORM_SPECIFIC_LIBS_ARRAY_TEMP=""

    for PLATFORM_LIB in ${PLATFORM_SPECIFIC_LIBS_ARRAY[@]}; do

        PLATFORM_SPECIFIC_LIBS_ARRAY_TEMP+="-v ${PLATFORM_LIB}:${PLATFORM_LIB} "

    done

    OUT_PLATFORM_SPECIFIC_LIBS=${PLATFORM_SPECIFIC_LIBS_ARRAY_TEMP}

    return 0
}

# Get Exports from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) EXPORTS: set of variables, which will be exported
function qimsdk-get-variables-to-export() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_EXPORTS=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local EXPORTS_LOCAL=$(
        echo ${JSON_CONTENT} | jq -r '.Exports[]'
    )

    declare -a EXPORT_TEMP=""

    for EXPORT in ${EXPORTS_LOCAL[@]}; do
        EXPORT_TEMP+="-e ${EXPORT} "
    done

    OUT_EXPORTS=${EXPORT_TEMP}

    return 0
}

# Remote Sync Wrapper
# Sync from host to remote and clean-up if success
#   $1 - (mandatory) SRC: source to sync
#   $2 - (mandatory) DST: destination where to sync
function qimsdk-sync-to-remote-and-clean() {
    local SRC=${1}
    local DST=${2}

    [[ -d ${DST} || -f ${DST} ]] && {
        return 0
    }

    rsync -aP ${SRC} ${DST}

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: rsync -aP ${SRC} ${DST}"
        return ${rc}
    }

    rm -f ${SRC}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: rm ${SRC}"
        return ${rc}
    }

    return 0
}

# Remove
# Remove argument if its located in tmp of file system
#   $1 - (mandatory) TEMP: file or dir to remove
function qimsdk-remove-if-temp() {
    local TEMP=${1}

    [ -z ${TEMP} ] && {
        return 0
    }

    [[ "${TEMP}" == /tmp/* ]] && {
        rm -rf ${TEMP}
    }

    return 0
}

# Get Platform_Libraries_To_Mount from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) path to docker compose yaml
function qimsdk-generate-docker-compose-yaml() {
    local PATH_TO_CONFIG_JSON=${1}
    local PATH_TO_DOCKER_COMPOSE_YAML=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    declare -a PLATFORM_SPECIFIC_LIBS_ARRAY
    PLATFORM_SPECIFIC_LIBS_ARRAY=$(
        echo ${JSON_CONTENT} | jq '.Platform_Libraries_To_Mount[]' | tr -d '"'
    )
    [ -z "${PLATFORM_SPECIFIC_LIBS_ARRAY}" ] && {
        print-red "Platform_Libraries_To_Mount attribute in ${PATH_TO_CONFIG_JSON} is not set !!!"
        return -2
    }

    declare -a PLATFORM_SPECIFIC_MAPS_ARRAY
    PLATFORM_SPECIFIC_MAPS_ARRAY=$(
        echo ${JSON_CONTENT} | jq '.Platform_Specific_Mappings[]' | tr -d '"'
    )
    [ -z "${PLATFORM_SPECIFIC_MAPS_ARRAY}" ] && {
        print-red "Platform_Specific_Mappings attribute in ${PATH_TO_CONFIG_JSON} is not set !!!"
        return -3
    }

    declare -a EXPORTS_ARRAY
    EXPORTS_ARRAY=$(
        echo ${JSON_CONTENT} | jq -r '.Exports[]'
    )

    EXPORTS_ARRAY=$(
        echo ${EXPORTS_ARRAY} | tr -d '"'
    )

    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH
    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local I
    echo "services:" > ${PATH_TO_DOCKER_COMPOSE_YAML}                                           && \
            yq -i ".services.qimsdk.image=\"${QIMSDK_IMAGE_NAME}\""                                \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i ".services.qimsdk.container_name=\"${QIMSDK_CONTAINER_NAME}\""                   \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i ".services.qimsdk.hostname=\"${QIMSDK_CONTAINER_NAME}\""                         \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i ".services.qimsdk.user=\"qimsdk\"" ${PATH_TO_DOCKER_COMPOSE_YAML}             && \
            yq -i ".services.qimsdk.command=\"bash\"" ${PATH_TO_DOCKER_COMPOSE_YAML}            && \
            yq -i ".services.qimsdk.restart=\"always\"" ${PATH_TO_DOCKER_COMPOSE_YAML}          && \
            for I in ${EXPORTS_ARRAY[@]}; do
                yq -i ".services.qimsdk.environment += [\"${I}\"]" ${PATH_TO_DOCKER_COMPOSE_YAML}
            done                                                                                && \
            for I in ${PLATFORM_SPECIFIC_MAPS_ARRAY[@]}; do
                yq -i ".services.qimsdk.devices += [\"${I}\"]" ${PATH_TO_DOCKER_COMPOSE_YAML}
            done                                                                                && \
            for I in ${PLATFORM_SPECIFIC_LIBS_ARRAY[@]}; do
                yq -i ".services.qimsdk.volumes += [\"${I}\"]" ${PATH_TO_DOCKER_COMPOSE_YAML}
            done                                                                                || {
        print-red "Failed to generate docker compose yaml file failed !!!"
        rm -rf  ${PATH_TO_DOCKER_COMPOSE_YAML}
        return -4
    }

    return 0
}
