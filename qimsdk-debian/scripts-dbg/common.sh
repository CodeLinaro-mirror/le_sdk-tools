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

# Argument count function validator helper
#   $1 - (mandatory) actual calling function argument count - allowed
# to be equal or higher than the value of the expected argument count
#   $2 - (mandatory) expected calling function argument count
function qimsdk-arg-count-check() {
    [ $# -ne 2 ] && print-red "${FUNCNAME[0]}: two arguments needed!" && return -1

    ! [[ "$1" =~ ^[0-9]{1,2}$ ]]                                                                && \
        print-red "${FUNCNAME[0]}: first argument must be a non-signed number!" && return -1

    ! [[ "$2" =~ ^[0-9]{1,2}$ ]]                                                                && \
        print-red "${FUNCNAME[0]}: second argument must be a non-signed number!" && return -1

    [[ "$1" -ne "$2" ]] && [[ "$1" -lt "$2" ]] && return -1

    return 0
}

# Propagate errors from adb shell
#   $1 - (mandatory) cmd to be executed
#   $2 - (optional) device ID
function qimsdk-device-command () {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

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
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

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
#   $3 - (mandatory) give image name as argument
function qimsdk-get-container-and-image-name() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

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
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

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

# Get qimsdk components commit ID or tag
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give camera service commit ID or tag as argument
#   $3 - (mandatory) give gst plugins commit ID or tag as argument
#   $4 - (mandatory) give solutions microservices commit ID or tag as argument
function qimsdk-get-components-tag() {
    local QIMSDK_ARG_COUNT_EXPECTED=4
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_CAMERA_SERVICE_TAG=${2}
    local -n OUT_QIMSDK_GST_PLUGINS_TAG=${3}
    local -n OUT_QIMSDK_SOLUTIONS_MICROSERVICES_TAG=${4}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QIMSDK_CAMERA_SERVICE_TAG=$(
        jq -er '.camera_service_git_tag // ""' <<< "${JSON_CONTENT}" 2>/dev/null || echo ""
    )

    OUT_QIMSDK_GST_PLUGINS_TAG=$(
        jq -er '.IM_SDK_Source_git_tag // ""' <<< "${JSON_CONTENT}" 2>/dev/null || echo ""
    )

    OUT_QIMSDK_SOLUTIONS_MICROSERVICES_TAG=$(
        jq -er '.solutions_microservices_Source_git_tag // ""' <<< "${JSON_CONTENT}"               \
                2>/dev/null || echo ""
    )

    return 0
}

# Get Device ID from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Device ID as argument
function qimsdk-get-device-id() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

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

# Remote Sync Wrapper
# Sync from host to remote and clean-up if success
#   $1 - (mandatory) SRC: source to sync
#   $2 - (mandatory) DST: destination where to sync
function qimsdk-sync-to-remote-and-clean() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

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
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

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
#   $1 - (mandatory) path to Docker compose yaml
#   $2 - (mandatory) container name from user's config json
#   $3 - (mandatory) image name from user's config json
function qimsdk-generate-docker-compose-yaml() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_DOCKER_COMPOSE_YAML=${1}
    local CONTAINER_NAME=${2}
    local IMAGE_NAME=${3}
    local MODEL_ROOT="/etc"
    declare -a QIMSDK_USER_CONTENTS_DIRS_ARRAY=("media" "models" "labels" "configs")

    yq -n ".name=\"${IMAGE_NAME}\"" > ${PATH_TO_DOCKER_COMPOSE_YAML}                            && \
            yq -i ".services.qimsdk.image=\"${IMAGE_NAME}\"" ${PATH_TO_DOCKER_COMPOSE_YAML}     && \
            yq -i ".services.qimsdk.container_name\"${CONTAINER_NAME}\""                           \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i ".services.qimsdk.hostname=\"${CONTAINER_NAME}\""                                \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i '.services.qimsdk.stdin_open=true' ${PATH_TO_DOCKER_COMPOSE_YAML}             && \
            yq -i '.services.qimsdk.tty=true' ${PATH_TO_DOCKER_COMPOSE_YAML}                    && \
            yq -i '.services.qimsdk.restart="always"' ${PATH_TO_DOCKER_COMPOSE_YAML}            && \
            yq -i '.services.qimsdk.network_mode="host"' ${PATH_TO_DOCKER_COMPOSE_YAML}         && \
            for I in ${QIMSDK_USER_CONTENTS_DIRS_ARRAY[@]}; do
                yq -i ".services.qimsdk.volumes += [\"${MODEL_ROOT}/${I}:${MODEL_ROOT}/${I}\"]"    \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}
            done                                                                                && \
            yq -i '.services.qimsdk.env_file=["/etc/docker/env/qimsdk.env"]'                       \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i '.services.qimsdk.deploy.resources.reservations.devices[0].driver = "cdi"'       \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i '.services.qimsdk.deploy.resources.reservations.devices[0].device_ids[0] =
                    "qualcomm.com/device=cdi-hw-acc"' ${PATH_TO_DOCKER_COMPOSE_YAML}            && \
            yq -i '.services.qimsdk.deploy.resources.reservations.devices[0].capabilities =
                    ["hw-acc"]' "${PATH_TO_DOCKER_COMPOSE_YAML}"                                || {
        print-red "Failed to generate Docker compose CDI yaml file !!!"
        rm -rf  ${PATH_TO_DOCKER_COMPOSE_YAML}
        return -1
    }

    return 0
}

# Generate docker run cdi cmd in shell file
#   $1 - (mandatory) remote path
#   $2 - (mandatory) container name from user's config json
#   $3 - (mandatory) image name from user's config json
function qimsdk-generate-docker-run-cmd() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local RESULT=${1}
    local CONTAINER_NAME=${2}
    local IMAGE_NAME=${3}
    local MODEL_ROOT="/etc"

    echo "docker run -it -d --net host --env-file /etc/docker/env/qimsdk.env `
            `--device qualcomm.com/device=qimsdk -h ${CONTAINER_NAME} `
            `-v ${MODEL_ROOT}/media:${MODEL_ROOT}/media `
            `-v ${MODEL_ROOT}/models:${MODEL_ROOT}/models `
            `-v ${MODEL_ROOT}/labels:${MODEL_ROOT}/labels `
            `-v ${MODEL_ROOT}/configs:${MODEL_ROOT}/configs `
            `--name ${CONTAINER_NAME} ${IMAGE_NAME}" > ${RESULT}

    local rc=$?
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
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

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
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local -n INPUT_PATH=${1}

    [[ "$INPUT_PATH" == ~* ]] && {
        # Swap "~" with ${HOME} variable
        INPUT_PATH="${INPUT_PATH/#\~/${HOME}}"
    }
}

# Argument unsigned 10-digit number checker.
#   $1 - (mandatory) number argument to be checked
function qimsdk-is-arg-number() {
    local ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${ARG_COUNT_EXPECTED}                                           && \
        print-red "${FUNCNAME[0]}: expects ${ARG_COUNT_EXPECTED} arguments, but got $#!"        && \
        return -1

    local NUMBER_ARG=${1}

    ! [[ "${NUMBER_ARG}" =~ ^[0-9]{1,10}$ ]]                                                    && \
        return -1

    return 0
}

# Get maximum number of build threads from json
#   $1 - (mandatory) path to target config json
#   $2 - (output) give number of max build threads, if set
function qimsdk-get-max-build-jobs() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_MAX_BUILD_JOBS=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ]                                                           && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QIMSDK_MAX_BUILD_JOBS=$(echo ${JSON_CONTENT} |                                             \
            jq '.MAX_build_cpu_threads' | tr -d '"')

    [[ -n "${OUT_QIMSDK_MAX_BUILD_JOBS}" ]]                                                     && \
                    qimsdk-is-arg-number "${OUT_QIMSDK_MAX_BUILD_JOBS}"                         && {
        [[ "${OUT_QIMSDK_MAX_BUILD_JOBS}" -le 0 ]]                                              || \
                [[ "${OUT_QIMSDK_MAX_BUILD_JOBS}" -gt $(nproc) ]]                               && {
            print-red "Max build threads argument value set: ${OUT_QIMSDK_MAX_BUILD_JOBS}"
            print-red "Max build threads argument value must be within: 0 - $(nproc)! Exit!"
            return -1
        }                                                                                       || {
            OUT_QIMSDK_MAX_BUILD_JOBS="${OUT_QIMSDK_MAX_BUILD_JOBS#+}"
        }
    }                                                                                           || {
        OUT_QIMSDK_MAX_BUILD_JOBS=$(nproc)
    }

    return 0
}
