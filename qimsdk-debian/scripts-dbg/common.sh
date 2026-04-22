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
        [ "${rc}" -ne 0 ] && print-red "adb remount failed !!!" && return -1

        adb wait-for-device

        qimsdk-device-command "mount -o remount,rw / > /dev/null" ${TARGET_DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb file system remount failed !!!" && return -1

        qimsdk-device-command "mount -o remount,rw /usr > /dev/null" ${TARGET_DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb remount /usr on system failed !!!" && return -1

        qimsdk-device-command "! command -v setenforce || setenforce 0" ${TARGET_DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "adb disable SE Linux failed !!!" && return -1

        qimsdk-device-command "date `date +%m%d%H%M%Y.%S`" ${TARGET_DEVICE_ID}
        rc=$?
        [ "${rc}" -ne 0 ] && print-red "setting device date failed !!!" && return -1

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

    qimsdk-expand-tilde OUT_DOCKER_IMAGE_PATH

    [ -z "${OUT_DOCKER_IMAGE_PATH}" ] && {
        print-red "Docker_image_path attribute in config.json is not set !!!"
        return -1
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
        return -1
    }

    return 0
}

# Get User_Specific_Mappings from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give User specific map as argument
function qimsdk-get-user-specific-mapping() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_USER_SPECIFIC_MAP=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    declare -a USER_SPECIFIC_MAPS_ARRAY

    USER_SPECIFIC_MAPS_ARRAY=$(
        echo ${JSON_CONTENT} | jq '.User_Specific_Mappings[]' | tr -d '"'
    )

    [ -z "${USER_SPECIFIC_MAPS_ARRAY}" ] && {
        declare -a USER_SPECIFIC_MAPS_ARRAY_TEMP=""

        for SPECIFIC_MAP in ${USER_SPECIFIC_MAPS_ARRAY[@]}; do
            USER_SPECIFIC_MAPS_ARRAY_TEMP+="--device ${SPECIFIC_MAP} "
        done

        OUT_USER_SPECIFIC_MAP=${USER_SPECIFIC_MAPS_ARRAY_TEMP}
    } || {
        OUT_USER_SPECIFIC_MAP=""
    }

    return 0
}

# Get User_Libraries_To_Mount from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give User specific libraries to be mounted as argument
function qimsdk-get-user-libs-to-mount() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_USER_SPECIFIC_LIBS=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    declare -a USER_SPECIFIC_LIBS_ARRAY

    USER_SPECIFIC_LIBS_ARRAY=$(
        echo ${JSON_CONTENT} | jq '.User_Libraries_To_Mount[]' | tr -d '"'
    )

    [ ! -z "${USER_SPECIFIC_LIBS_ARRAY}" ] && {
        declare -a USER_SPECIFIC_LIBS_ARRAY_TEMP=""

        for PLATFORM_LIB in ${USER_SPECIFIC_LIBS_ARRAY[@]}; do
            USER_SPECIFIC_LIBS_ARRAY_TEMP+="-v ${PLATFORM_LIB}:${PLATFORM_LIB} "
        done

        OUT_USER_SPECIFIC_LIBS=${USER_SPECIFIC_LIBS_ARRAY_TEMP}
    } || {
        OUT_USER_SPECIFIC_LIBS=""
    }

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

# Get User_Exports from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) USER_EXPORTS: set of variables, which will be exported
function qimsdk-get-user-variables-to-export() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_USER_EXPORTS=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local USER_EXPORTS_LOCAL=$(
        echo ${JSON_CONTENT} | jq -r '.User_Exports[]'
    )

    declare -a USER_EXPORT_TEMP=""

    for USER_EXPORT in ${USER_EXPORTS_LOCAL[@]}; do
        USER_EXPORT_TEMP+="-e ${USER_EXPORT} "
    done

    OUT_USER_EXPORTS=${USER_EXPORT_TEMP}

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

# Generate Docker compose CDI yaml file
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) path to Docker compose yaml
#   $3 - (mandatory) container name from user's config json
#   $4 - (mandatory) image name from user's config json
function qimsdk-generate-docker-compose-cdi-yaml() {
    local PATH_TO_TARGET_CONFIG_JSON=${1}
    local PATH_TO_DOCKER_COMPOSE_YAML=${2}
    local CONTAINER_NAME=${3}
    local IMAGE_NAME=${4}

    [ ! -f "${PATH_TO_TARGET_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local TARGET_JSON_CONTENT=$(cat ${PATH_TO_TARGET_CONFIG_JSON})

    declare -a USER_SPECIFIC_LIBS_ARRAY
    USER_SPECIFIC_LIBS_ARRAY=$(
        echo ${TARGET_JSON_CONTENT} | jq '.User_Libraries_To_Mount[]' | tr -d '"'
    )

    declare -a USER_SPECIFIC_MAPS_ARRAY
    USER_SPECIFIC_MAPS_ARRAY=$(
        echo ${TARGET_JSON_CONTENT} | jq '.User_Specific_Mappings[]' | tr -d '"'
    )

    declare -a USER_EXPORTS_ARRAY
    USER_EXPORTS_ARRAY=$(
        echo ${TARGET_JSON_CONTENT} | jq -r '.User_Exports[]'
    )

    USER_EXPORTS_ARRAY=$(
        echo ${USER_EXPORTS_ARRAY} | tr -d '"'
    )

    declare -a TARGET_EXPORTS_ARRAY
    TARGET_EXPORTS_ARRAY=$(
        echo ${TARGET_JSON_CONTENT} | jq -r '.Exports[]'
    )

    TARGET_EXPORTS_ARRAY=$(
        echo ${TARGET_EXPORTS_ARRAY} | tr -d '"'
    )

    local I
    echo "services:" > ${PATH_TO_DOCKER_COMPOSE_YAML}                                           && \
            yq -i ".services.qimsdk.image=\"${IMAGE_NAME}\""                                       \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i ".services.qimsdk.container_name=\"${CONTAINER_NAME}\""                          \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i ".services.qimsdk.hostname=\"${CONTAINER_NAME}\""                                \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i ".services.qimsdk.user=\"qimsdk\"" ${PATH_TO_DOCKER_COMPOSE_YAML}             && \
            yq -i ".services.qimsdk.stdin_open=true" ${PATH_TO_DOCKER_COMPOSE_YAML}             && \
            yq -i ".services.qimsdk.tty=true" ${PATH_TO_DOCKER_COMPOSE_YAML}                    && \
            yq -i ".services.qimsdk.restart=\"always\"" ${PATH_TO_DOCKER_COMPOSE_YAML}          && \
            for I in ${USER_EXPORTS_ARRAY[@]}; do
                yq -i ".services.qimsdk.environment += [\"${I}\"]" ${PATH_TO_DOCKER_COMPOSE_YAML}
            done                                                                                && \
            for I in ${TARGET_EXPORTS_ARRAY[@]}; do
                yq -i ".services.qimsdk.environment += [\"${I}\"]" ${PATH_TO_DOCKER_COMPOSE_YAML}
            done                                                                                && \
            for I in ${USER_SPECIFIC_MAPS_ARRAY[@]}; do
                yq -i ".services.qimsdk.devices += [\"${I}\"]" ${PATH_TO_DOCKER_COMPOSE_YAML}
            done                                                                                && \
            for I in ${USER_SPECIFIC_LIBS_ARRAY[@]}; do
                yq -i ".services.qimsdk.volumes += [\"${I}:${I}\"]" ${PATH_TO_DOCKER_COMPOSE_YAML}
            done                                                                                && \
            yq -i ".services.qimsdk.deploy.resources.reservations.devices[0].driver = \"cdi\""     \
                ${PATH_TO_DOCKER_COMPOSE_YAML} && \
            yq -i ".services.qimsdk.deploy.resources.reservations.devices[0].device_ids[0] = `
                `\"qualcomm.com/device=cdi-hw-acc\"" ${PATH_TO_DOCKER_COMPOSE_YAML}             && \
            yq -i ".services.qimsdk.network_mode=\"host\"" ${PATH_TO_DOCKER_COMPOSE_YAML}       || {
        print-red "Failed to generate Docker compose CDI yaml file !!!"
        rm -rf  ${PATH_TO_DOCKER_COMPOSE_YAML}
        return -1
    }

    return 0
}

# Generate docker run cdi cmd in shell file
#   $1 - (mandatory) path to qimsdk target json
#   $2 - (mandatory) remote path
#   $3 - (mandatory) container name from user's config json
#   $4 - (mandatory) image name from user's config json
function qimsdk-generate-docker-run-cmd() {
    local PATH_TO_TARGET_CONFIG_JSON=${1}
    local RESULT=${2}
    local CONTAINER_NAME=${3}
    local IMAGE_NAME=${4}

    [ ! -f "${PATH_TO_TARGET_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local USER_SPECIFIC_MAP

    qimsdk-get-user-specific-mapping ${PATH_TO_TARGET_CONFIG_JSON} USER_SPECIFIC_MAP

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-user-specific-mapping  !!!"
        return ${rc}
    }

    local USER_LIBS_TO_MOUNT
    qimsdk-get-user-libs-to-mount ${PATH_TO_TARGET_CONFIG_JSON} USER_LIBS_TO_MOUNT

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-user-libs-to-mount  !!!"
        return ${rc}
    }

    local USER_EXPORTS
    qimsdk-get-user-variables-to-export ${PATH_TO_TARGET_CONFIG_JSON}                              \
            USER_EXPORTS

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-user-variables-to-export !!!"
        return ${rc}
    }

    local TARGET_EXPORTS
    qimsdk-get-variables-to-export ${PATH_TO_TARGET_CONFIG_JSON}                                   \
            TARGET_EXPORTS

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-variables-to-export !!!"
        return ${rc}
    }

    local QIMSDK_DOCKER_RUN_CMD_ARGUMENTS=""

    QIMSDK_DOCKER_RUN_CMD_ARGUMENTS+="--device /dev/video32 "
    QIMSDK_DOCKER_RUN_CMD_ARGUMENTS+="--device /dev/video33 "

    QIMSDK_DOCKER_RUN_CMD_ARGUMENTS+="-v /dev/socket/weston:/dev/socket/weston "

    echo "docker run -it -d --net host --env-file /etc/docker/env/qimsdk.env                       \
            --device qualcomm.com/device=qimsdk ${QIMSDK_DOCKER_RUN_CMD_ARGUMENTS}                 \
            ${USER_SPECIFIC_MAP} ${USER_LIBS_TO_MOUNT} ${USER_EXPORTS} ${TARGET_EXPORTS}           \
            -h ${CONTAINER_NAME} --user qimsdk --name ${CONTAINER_NAME} ${IMAGE_NAME}" > ${RESULT}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: Failed to construct Docker run CDI cmd !!!"
        return ${rc}
    }

    return 0
}

# Get map of host to dbg container to mount src dirs
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) output map
function qimsdk-get-map-for-dbg-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_DEV_MAP=${2}

    local JSON_CONTENT=$(
        cat ${PATH_TO_CONFIG_JSON}
    )

    local DOCKER_IMAGE_PATH="/mnt/work/dev_artifacts"
    local HOST_DOCKER_IMAGE_PATH=""

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} HOST_DOCKER_IMAGE_PATH

    local MAP_SOURCES_TO_DEV_CONTAINER=$(
        echo ${JSON_CONTENT} |  jq '.MAP_sources_to_dev_container' | tr -d '"'
    )

    declare -a DEV_MAP_ARR=""

    [[ "${MAP_SOURCES_TO_DEV_CONTAINER}" =~ ^(TRUE|ENABLE|ENABLED)$ ]]                          && {

        local GST_SRC_DIR=$(
            echo ${JSON_CONTENT} |  jq '.IM_SDK_Source_Dir' | tr -d '"'
        )

        qimsdk-expand-tilde GST_SRC_DIR

        [[ -z ${GST_SRC_DIR} ]]                                                                 && {
            return 0
        }

        [ -d ${GST_SRC_DIR} ] && {
            DEV_MAP_ARR+="-v ${GST_SRC_DIR}:/mnt/work/src/gst-plugins-imsdk "
        }

    }

    DEV_MAP_ARR+="-v ${HOST_DOCKER_IMAGE_PATH}:${DOCKER_IMAGE_PATH} "

    OUT_DEV_MAP=${DEV_MAP_ARR}

    return 0
}

# expand tilde to real path
#   $1 - (mandatory) path
function qimsdk-expand-tilde() {
    local -n INPUT_PATH=${1}

    [[ "$INPUT_PATH" == ~* ]] && {
        # Swap "~" with ${HOME} variable
        INPUT_PATH="${INPUT_PATH/#\~/${HOME}}"
    }
}
