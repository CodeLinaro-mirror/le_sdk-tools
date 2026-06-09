#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

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

# Parse json configuraiton
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) variable to take container name value
#   $3 - (mandatory) variable to take image name value
#   $4 - (mandatory) variable to take camera-service sources of SP
#   $5 - (mandatory) variable to take Gstreamer sources of SP
#   $6 - (mandatory) variable to take solutions-microservices sources of SP
#   $7 - (mandatory) variable to take QAIRT SDK version
function qimsdk-docker-parse-json() {
    local QIMSDK_ARG_COUNT_EXPECTED=7
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_CONTAINER_NAME=${2}
    local -n OUT_QIMSDK_IMAGE_NAME=${3}
    local -n OUT_QIMSDK_CAMERA_SERVICE_SOURCES=${4}
    local -n OUT_QIMSDK_GST_SOURCES=${5}
    local -n OUT_MICROSERVICES_SOURCES=${6}
    local -n OUT_QIMSDK_QAIRT_SDK_VERSION=${7}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ]                                                           && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local ADDITIONAL_TAG_CONTAINER=$(
        echo ${JSON_CONTENT} |  jq '.Additional_tag_container' | tr -d '"'
    )

    [ ! -z "${ADDITIONAL_TAG_CONTAINER}" ]                                                      && {
        ADDITIONAL_TAG_CONTAINER="-${ADDITIONAL_TAG_CONTAINER}"
    }

    OUT_QIMSDK_CONTAINER_NAME="qimsdk${ADDITIONAL_TAG_CONTAINER}"

    local ADDITIONAL_TAG_IMAGE=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_image' | tr -d '"')

    [ -z "${ADDITIONAL_TAG_IMAGE}" ]                                                            && {
        print-red "Please provide additional tag for image name in config json!!!"
        return -1
    }

    ADDITIONAL_TAG_IMAGE="-${ADDITIONAL_TAG_IMAGE}"
    OUT_QIMSDK_IMAGE_NAME="qimsdk${ADDITIONAL_TAG_IMAGE}"

    OUT_QIMSDK_CAMERA_SERVICE_SOURCES=$(echo ${JSON_CONTENT} | jq '.camera_service_Source_Dir'   | \
            tr -d '"')
    OUT_QIMSDK_CAMERA_SERVICE_SOURCES=${OUT_QIMSDK_CAMERA_SERVICE_SOURCES%/}

    qimsdk-expand-tilde OUT_QIMSDK_CAMERA_SERVICE_SOURCES

    [ -d "${OUT_QIMSDK_CAMERA_SERVICE_SOURCES}/.git" ]                                          || \
            [ -d "${OUT_QIMSDK_CAMERA_SERVICE_SOURCES}/recorder" ]                              || {
        print-red "Please provide path to camera-service directory in config json!!!"
        print-red "Directory currently provided: ${OUT_QIMSDK_CAMERA_SERVICE_SOURCES}"
        return -1
    }

    OUT_QIMSDK_GST_SOURCES=$(echo ${JSON_CONTENT} | jq '.IM_SDK_Source_Dir' | tr -d '"')
    OUT_QIMSDK_GST_SOURCES=${OUT_QIMSDK_GST_SOURCES%/}

    qimsdk-expand-tilde OUT_QIMSDK_GST_SOURCES

    [ -d "${OUT_QIMSDK_GST_SOURCES}/.git" ]                                                     || \
            [ -d "${OUT_QIMSDK_GST_SOURCES}/gst-plugin-base" ]                                  || {
        print-red "Please provide path to gst-plugins-imsdk directory in config json!!!"
        print-red "Directory currently provided: ${OUT_QIMSDK_GST_SOURCES}"
        return -1
    }

    OUT_MICROSERVICES_SOURCES=$(echo ${JSON_CONTENT} |                                             \
            jq '.solutions_microservices_Source_dir' | tr -d '"')
    OUT_MICROSERVICES_SOURCES=${OUT_MICROSERVICES_SOURCES%/}

    qimsdk-expand-tilde OUT_MICROSERVICES_SOURCES

    [ -d "${OUT_MICROSERVICES_SOURCES}/.git" ]                                                  || \
            [ -d "${OUT_MICROSERVICES_SOURCES}/microservices" ]                                 || {
        print-red "Please provide path to solutions-microservices directory in config json!!!"
        print-red "Directory currently provided: ${OUT_MICROSERVICES_SOURCES}"
        return -1
    }

    OUT_QIMSDK_QAIRT_SDK_VERSION=$(echo ${JSON_CONTENT} |  jq '.QAIRT_SDK_version' | tr -d '"')

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

    # The device ID may be either an adb device serial number, or a remote
    # device IPv4 address in dotted-quad (XXX.XXX.XXX.XXX) form. Validate that
    # it matches one of these two accepted patterns.
    qimsdk-is-adb-serial "${OUT_TARGET_DEVICE_ID}"                                              || \
            qimsdk-is-ipv4 "${OUT_TARGET_DEVICE_ID}"                                            || {
        print-red "Target_device_ID '${OUT_TARGET_DEVICE_ID}' is neither a valid adb serial"
        print-red "number nor a valid IPv4 address (XXX.XXX.XXX.XXX) !!!"
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

# Qimsdk initialize docker build
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) variable to take container name value
#   $3 - (mandatory) variable to take image name value
#   $4 - (mandatory) temp folder
#   $5 - (mandatory) docker image path
#   $6 - (mandatory) device ID
#   $7 - (mandatory) QAIRT SDK version
function qimsdk-docker-build-initialize() {
    local QIMSDK_ARG_COUNT_EXPECTED=7
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}

    local -n QIMSDK_CONTAINER_NAME_PTR=${2}
    local -n QIMSDK_IMAGE_NAME_PTR=${3}
    local -n QIMSDK_TMP_FOLDER_PTR=${4}
    local -n DOCKER_IMAGE_PATH_PTR=${5}
    local -n QIMSDK_DEVICE_ID_PTR=${6}
    local -n QIMSDK_QAIRT_SDK_VERSION_PTR=${7}

    local QIMSDK_CAMERA_SERVICE_SOURCES
    local QIMSDK_GST_SOURCES
    local QIMSDK_MICROSERVICES_SOURCES

    qimsdk-docker-parse-json ${PATH_TO_CONFIG_JSON}                                                \
            QIMSDK_CONTAINER_NAME_PTR                                                              \
            QIMSDK_IMAGE_NAME_PTR                                                                  \
            QIMSDK_CAMERA_SERVICE_SOURCES                                                          \
            QIMSDK_GST_SOURCES                                                                     \
            QIMSDK_MICROSERVICES_SOURCES                                                           \
            QIMSDK_QAIRT_SDK_VERSION_PTR                                                        || {
        print-red "FAILED: qimsdk-docker-parse-json !!!"
        return -1
    }

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH_PTR                   || {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return -1
    }

    [[ "${DOCKER_IMAGE_PATH_PTR}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH_PTR}" ]            && {
        mkdir -p ${DOCKER_IMAGE_PATH_PTR}                                                       || {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH_PTR} !!!"
            return -1
        }
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID_PTR                            || {
        print-red "FAILED: qimsdk-get-device-id !!!"
        return -1
    }

    git -C ${QIMSDK_CAMERA_SERVICE_SOURCES} branch | grep -q "main"                             || {
        print-red "ERROR: ${QIMSDK_CAMERA_SERVICE_SOURCES} does not contain local branch: main !!!"
        return -1
    }

    git -C ${QIMSDK_GST_SOURCES} branch | grep -q "main"                                        || {
        print-red "ERROR: ${QIMSDK_GST_SOURCES} does not contain local branch: main !!!"
        return -1
    }

    git -C ${QIMSDK_MICROSERVICES_SOURCES} branch | grep -q "iot-solutions.lnx.1.0"             || {
        print-red "ERROR: ${QIMSDK_GST_SOURCES} does not contain local branch: iot-solutions.lnx.1.0 !!!"
        return -1
    }

    rsync -aL ${QIMSDK_CAMERA_SERVICE_SOURCES}/ ${QIMSDK_TMP_FOLDER_PTR}/camera-service         && \
            rsync -aL ${QIMSDK_GST_SOURCES}/ ${QIMSDK_TMP_FOLDER_PTR}/gst-plugins-imsdk         && \
            rsync -aL ${QIMSDK_MICROSERVICES_SOURCES}/ ${QIMSDK_TMP_FOLDER_PTR}/solutions-microservices
}

# Qimsdk build qimsdk-debian deploy docker image
#   $1 - (mandatory) image name
#   $2 - (mandatory) path to target config json
function qimsdk-docker-build-qimsdk-debian-deploy-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local IMAGE_NAME=${1}
    local PATH_TO_CONFIG_JSON=${2}
    local PATH_TO_QIMSDK_DEBIAN_DOCKERFILE=${QIMSDK_DOCKER_DIR}
    local QIMSDK_MAX_BUILD_JOBS

    [ ! -d ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} ]                                                && {
        print-red "No such directory: ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE}!"
        return -1
    }

    [ -z ${IMAGE_NAME} ]                                                                        && {
        print-red "Image name is empty!"
        return -1
    }

    ! qimsdk-get-max-build-jobs ${PATH_TO_CONFIG_JSON} QIMSDK_MAX_BUILD_JOBS                    && {
        print-red "Incorrect QIMSDK_MAX_BUILD_JOBS argument value!"
        return -1
    }

    (
        cd ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} || return -1

        local DOCKERFILE="${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE}/Dockerfile"

        # Modify Dockerfile to import artifacts from debug build container
        sed -E "s/--from=qimsdk_build/--from=${IMAGE_NAME}-debian/g"                               \
                ${DOCKERFILE} > ${DOCKERFILE}.work_deploy                                       || {
            rm -f ${DOCKERFILE}.work_deploy
            print-red "Modify Dockerfile to import artifacts from debug build container failed!"
            return -1
        }

        DOCKER_BUILDKIT=1 docker build                                                             \
                --progress=plain --target qimsdk_deploy_arm64                                      \
                ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} -t ${IMAGE_NAME}-debian-deploy                 \
                --build-arg QIMSDK_ARG_MAX_JOBS=${QIMSDK_MAX_BUILD_JOBS}                           \
                -f ${DOCKERFILE}.work_deploy                                                    || {
            rm -f ${DOCKERFILE}.work_deploy
            print-red "Build ${IMAGE_NAME}-debian-deploy image failed !!!"
            return -1
        }

        rm -f ${DOCKERFILE}.work_deploy
    )
}

# Qimsdk build qimsdk-debian deploy docker image with python use-case support
#   $1 - (mandatory) image name
function qimsdk-docker-build-qimsdk-debian-deploy-py-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local IMAGE_NAME=${1}

    local PATH_TO_QIMSDK_DEBIAN_DOCKERFILE=${QIMSDK_DOCKER_DIR}

    [ ! -d ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} ]                                                && {
        print-red "No such directory: ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE}!"
        return -1
    }

    [ -z ${IMAGE_NAME} ]                                                                        && {
        print-red "Image name is empty!"
        return -1
    }

    (
        cd ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} || return -1

        local DOCKERFILE="${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE}/Dockerfile"

        # Modify Dockerfile to import artifacts from debug build container
        sed -E "s/--from=qimsdk_build/--from=${IMAGE_NAME}-debian/g"                               \
                ${DOCKERFILE} > ${DOCKERFILE}.work_deploy_py                                    || {
            rm -f ${DOCKERFILE}.work_deploy_py
            print-red "Modify Dockerfile to import artifacts from debug build container failed!"
            return -1
        }

        DOCKER_BUILDKIT=1 docker build                                                             \
                --progress=plain --target qimsdk_deploy_py_arm64                                   \
                ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} -t ${IMAGE_NAME}-debian-deploy-py              \
                -f ${DOCKERFILE}.work_deploy_py                                                 || {
            rm -f ${DOCKERFILE}.work_deploy_py
            print-red "Build ${IMAGE_NAME}-debian-deploy-py image failed !!!"
            return -1
        }

        rm -f ${DOCKERFILE}.work_deploy_py
    )
}

# Qimsdk build qimsdk-debian docker image
#   $1 - (mandatory) image name
#   $2 - (mandatory) QAIRT SDK VERSION
#   $3 - (mandatory) path to target config json
function qimsdk-docker-build-qimsdk-debian-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local IMAGE_NAME=${1}
    local QIMSDK_QAIRT_SDK_VERSION=${2}
    local PATH_TO_CONFIG_JSON=${3}
    local QIMSDK_CAMERA_SERVICE_TAG
    local QIMSDK_GST_PLUGINS_TAG
    local QIMSDK_SOLUTIONS_MICROSERVICES_TAG
    local QIMSDK_MAX_BUILD_JOBS

    local PATH_TO_QIMSDK_DEBIAN_DOCKERFILE=${QIMSDK_DOCKER_DIR}

    [ ! -d ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} ]                                                && {
        print-red "No such directory: ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE}!"
        return -1
    }

    [ -z ${IMAGE_NAME} ]                                                                        && {
        print-red "Image name is empty!"
        return -1
    }

    ! qimsdk-get-max-build-jobs ${PATH_TO_CONFIG_JSON} QIMSDK_MAX_BUILD_JOBS                    && {
        print-red "Incorrect QIMSDK_MAX_BUILD_JOBS argument value!"
        return -1
    }

    qimsdk-get-components-tag ${PATH_TO_CONFIG_JSON} QIMSDK_CAMERA_SERVICE_TAG                     \
        QIMSDK_GST_PLUGINS_TAG QIMSDK_SOLUTIONS_MICROSERVICES_TAG                               || {
        print-red "FAILED: qimsdk-get-components-tag !!!"
        return -1
    }

    (
        cd ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} || return -1

        local DOCKERFILE="${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE}/Dockerfile"

        # Modify Dockerfile to use debug container as base
        sed -E                                                                                     \
            "s|^(FROM[[:space:]]+)debian:trixie-slim([[:space:]]+AS[[:space:]]+qimsdk_build)|\1${IMAGE_NAME}\2|"  \
            ${DOCKERFILE} > ${DOCKERFILE}.work

        DOCKER_BUILDKIT=1 docker build                                                             \
                --build-arg QIMSDK_ARG_QNP_VERSION=${QIMSDK_QAIRT_SDK_VERSION}                     \
                --build-arg QIMSDK_ARG_CAMERA_SERVICE_TAG=${QIMSDK_CAMERA_SERVICE_TAG}             \
                --build-arg QIMSDK_ARG_GST_PLUGINS_TAG=${QIMSDK_GST_PLUGINS_TAG}                   \
                --build-arg QIMSDK_ARG_SOLUTIONS_MICROSERVICES_TAG=${QIMSDK_SOLUTIONS_MICROSERVICES_TAG} \
                --build-arg QIMSDK_ARG_MAX_JOBS=${QIMSDK_MAX_BUILD_JOBS}                           \
                --progress=plain --target qimsdk_build                                             \
                ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} -t ${IMAGE_NAME}-debian                        \
                -f ${DOCKERFILE}.work                                                           || {
            rm -f ${DOCKERFILE}.work
            print-red "Build qimsdk-debian image failed !!!"
            return -1
        }

        rm -f ${DOCKERFILE}.work
    )
}

# Build device docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-docker-build-image-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-dbg-docker-build-image ${PATH_TO_CONFIG_JSON}                                        || {
        print-red "FAILED: qimsdk-dbg-docker-build-image !!!"
        return -1
    }

    qimsdk-docker-build-qimsdk-debian-deploy-image ${QIMSDK_IMAGE_NAME} ${PATH_TO_CONFIG_JSON}  || {
        print-red "FAILED: qimsdk-docker-build-qimsdk-debian-deploy-image !!!"
        return -1
    }

    [ "${CONTAINER_TYPE}" == "python" ]                                                         && {
        qimsdk-docker-build-qimsdk-debian-deploy-py-image ${QIMSDK_IMAGE_NAME}                  || {
            print-red "FAILED: qimsdk-docker-build-qimsdk-debian-deploy-py-image !!!"
            return -1
        }
    }

    print-green "Build image completed successfully !!!"

    return 0
}

# Build device docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function qimsdk-docker-build-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-build-image-variant ${PATH_TO_CONFIG_JSON} native
}

# Build device docker image, including the python-enabled deploy image, based on Dockerfile
# in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function qimsdk-docker-build-image-py() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-build-image-variant ${PATH_TO_CONFIG_JSON} python
}

# Build dbg dev docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-docker-build-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH
    local QIMSDK_DEVICE_ID
    local QIMSDK_QAIRT_SDK_VERSION
    local QIMSDK_MAX_BUILD_JOBS

    local QIMSDK_TMP_FOLDER="${QIMSDK_DOCKER_DIR}/tmp"
    mkdir -p ${QIMSDK_TMP_FOLDER}

    qimsdk-docker-build-initialize ${PATH_TO_CONFIG_JSON}                                          \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                      \
            QIMSDK_TMP_FOLDER                                                                      \
            DOCKER_IMAGE_PATH                                                                      \
            QIMSDK_DEVICE_ID                                                                       \
            QIMSDK_QAIRT_SDK_VERSION                                                            || {
        print-red "FAILED: qimsdk-docker-build-initialize !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return -1
    }

    ! qimsdk-get-max-build-jobs ${PATH_TO_CONFIG_JSON} QIMSDK_MAX_BUILD_JOBS                    && {
        print-red "Incorrect QIMSDK_MAX_BUILD_JOBS argument value!"
        return -1
    }

    DOCKER_BUILDKIT=1 docker build                                                                 \
            --build-arg QIMSDK_ARG_MAX_JOBS=${QIMSDK_MAX_BUILD_JOBS}                               \
            --progress=plain --target qimsdk_dbg_image -f ${QIMSDK_DOCKER_DIR}/Dockerfile.dbg      \
            ${QIMSDK_DOCKER_DIR} -t ${QIMSDK_IMAGE_NAME}                                        || {
        print-red "Build image failed !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return -1
    }

    qimsdk-docker-build-qimsdk-debian-image ${QIMSDK_IMAGE_NAME} ${QIMSDK_QAIRT_SDK_VERSION}       \
            ${PATH_TO_CONFIG_JSON}                                                              || {
        print-red "FAILED: qimsdk-docker-build-qimsdk-debian-image !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return -1
    }

    rm -rf ${QIMSDK_TMP_FOLDER}

    print-green "Build image completed successfully !!!"

    return 0
}

# Update selected device image to the device
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-docker-device-update-image-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID
    local DEVICE_IMAGES_PATH="/tmp/data/docker_images"

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id !!!"
        return -1
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}${SUFFIX_NAME}.tar"

    docker save ${QIMSDK_IMAGE_NAME}-debian-deploy${SUFFIX_NAME}:latest -o ${FILE_NAME}         || {
        print-red "Device update${SUFFIX_NAME} image failed: docker save failed !!!"
        rm ${FILE_NAME}
        return -1
    }

    (
        [ -z "${QIMSDK_DEVICE_ID}" ]                                                            && {
            print-red "Device ID is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qimsdk-device-command "${QIMSDK_DEVICE_ID}" "mkdir -p ${DEVICE_IMAGES_PATH}"            || {
            print-red "FAILED: qimsdk-device-command !!!"
            rm ${FILE_NAME}

            return -1
        }

        qimsdk-cmd "${QIMSDK_DEVICE_ID}" push ${FILE_NAME} ${DEVICE_IMAGES_PATH}                || {
            print-red "FAILED: push ${FILE_NAME} ${DEVICE_IMAGES_PATH} !!!"
            rm ${FILE_NAME}

            return -1
        }

        rm ${FILE_NAME}

        qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                                \
                "docker load -i ${DEVICE_IMAGES_PATH}/${FILE_NAME}"                             || {
            print-red "Device update${SUFFIX_NAME} image failed: docker load failed !!!"
            return -1
        }

        qimsdk-device-command "${QIMSDK_DEVICE_ID}" "rm ${DEVICE_IMAGES_PATH}/${FILE_NAME}"     || {
            print-red "Device failed to remove ${FILE_NAME} !!!"
            return -1
        }
    )                                                                                           || {
        print-red "FAILED: Device update${SUFFIX_NAME} image !!!"
        return -1
    }

    print-green "Device update${SUFFIX_NAME} image successful !!!"

    return 0
}

# Update selected device image to the device
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-update-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-update-image-variant ${PATH_TO_CONFIG_JSON} native
}

# Update selected py device image to the device
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-update-py-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-update-image-variant ${PATH_TO_CONFIG_JSON} python
}

# Save selected device image
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-docker-device-save-image-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH                       || {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return -1
    }

    [[ "${DOCKER_IMAGE_PATH}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH}" ]                    && {
        mkdir -p ${DOCKER_IMAGE_PATH}                                                           || {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH} !!!"
            return -1
        }
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}${SUFFIX_NAME}.tar"

    local COMMON_PATH=""

    [ -d ${DOCKER_IMAGE_PATH} ]                                                                 && {
        COMMON_PATH=${DOCKER_IMAGE_PATH}
    }                                                                                           || {
        COMMON_PATH=$(mktemp -d)

        [ ! -d ${COMMON_PATH} ]                                                                 && {
            print-red "Failed to create docker image tmp path!"
            return -1
        }
    }

    docker save ${QIMSDK_IMAGE_NAME}-debian-deploy${SUFFIX_NAME}:latest                            \
            -o ${COMMON_PATH}/${FILE_NAME}                                                      || {
        print-red "Device save${SUFFIX_NAME} image failed: docker save failed !!!"
        rm -f ${COMMON_PATH}/${FILE_NAME}

        return -1
    }

    qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/${FILE_NAME} ${DOCKER_IMAGE_PATH}            || {
        print-red "FAILED: qimsdk-sync-to-remote-and-clean"
        rm -f ${COMMON_PATH}/${FILE_NAME}

        return -1
    }

    qimsdk-generate-docker-run-cmd ${COMMON_PATH}/docker_run${SUFFIX_NAME}.sh                      \
            ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME}                                                 \
            ${QIMSDK_IMAGE_NAME}-debian-deploy${SUFFIX_NAME}                                    || {
        print-red "Generate ${COMMON_PATH}/docker_run${SUFFIX_NAME}.sh file failed !!!"
        rm -f ${COMMON_PATH}/docker_run${SUFFIX_NAME}.sh
        return -1
    }

    qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/docker_run${SUFFIX_NAME}.sh                     \
            ${DOCKER_IMAGE_PATH}                                                                || {
        print-red "FAILED: qimsdk-sync-to-remote-and-clean"
        rm -f ${COMMON_PATH}/docker_run${SUFFIX_NAME}.sh
        return -1
    }

    qimsdk-generate-docker-compose-yaml ${COMMON_PATH}/docker-compose${SUFFIX_NAME}.yml            \
            ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME}                                                 \
            ${QIMSDK_IMAGE_NAME}-debian-deploy${SUFFIX_NAME}                                    || {
        print-red "Generate qimsdk docker compose CDI file failed !!!"
        rm -f ${COMMON_PATH}/docker-compose${SUFFIX_NAME}.yml
        return -1
    }

    qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/docker-compose${SUFFIX_NAME}.yml                \
            ${DOCKER_IMAGE_PATH}                                                                || {
        print-red "FAILED: qimsdk-sync-to-remote-and-clean"
        rm -f ${COMMON_PATH}/docker-compose${SUFFIX_NAME}.yml
        return -1
    }

    print-green "Device save${SUFFIX_NAME} image successful !!!"

    return 0
}

# Save selected device image
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-save-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-save-image-variant ${PATH_TO_CONFIG_JSON} native
}

# Save selected py device image
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-save-py-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-save-image-variant ${PATH_TO_CONFIG_JSON} python
}

# Load selected device image
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-docker-device-load-image-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH
    local QIMSDK_DEVICE_ID
    local DEVICE_IMAGES_PATH="/tmp/data/docker_images"

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH                       || {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return -1
    }

    [[ "${DOCKER_IMAGE_PATH}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH}" ]                    && {
            mkdir -p ${DOCKER_IMAGE_PATH}                                                       || {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH} !!!"
            return -1
        }
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id !!!"
        return -1
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}${SUFFIX_NAME}.tar"

    local LOCAL_DOCKER_IMAGE="${DOCKER_IMAGE_PATH}/${FILE_NAME}"

    [ ! -d ${DOCKER_IMAGE_PATH} ]                                                               && {
        local TMP_DOCKER_IMAGE_PATH=$(mktemp -d)

        [ ! -d ${TMP_DOCKER_IMAGE_PATH} ]                                                       && {
            print-red "Failed to create docker image tmp dir!"
            return -1
        }

        rsync -aP ${DOCKER_IMAGE_PATH}/${FILE_NAME} ${TMP_DOCKER_IMAGE_PATH}/${FILE_NAME}       || {
            print-red "FAILED: rsync -aP ${DOCKER_IMAGE_PATH}/${FILE_NAME}                         \
                    ${TMP_DOCKER_IMAGE_PATH}/${FILE_NAME}"

            return -1
        }

        LOCAL_DOCKER_IMAGE="${TMP_DOCKER_IMAGE_PATH}/${FILE_NAME}"
    }

    (
        [ -z "${QIMSDK_DEVICE_ID}" ]                                                            && {
            print-red "Device ID is not set !!!"
            qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

            return -1
        }

        qimsdk-device-command "${QIMSDK_DEVICE_ID}" "mkdir -p ${DEVICE_IMAGES_PATH}"            || {
            print-red "FAILED: qimsdk-device-command !!!"
            qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

            return -1
        }

        qimsdk-cmd "${QIMSDK_DEVICE_ID}" push ${LOCAL_DOCKER_IMAGE} ${DEVICE_IMAGES_PATH}       || {
            print-red "FAILED: push ${LOCAL_DOCKER_IMAGE}                                          \
                    ${DEVICE_IMAGES_PATH} !!!"

            qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}
            return -1
        }

        qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

        qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                                \
                "docker load -i ${DEVICE_IMAGES_PATH}/${FILE_NAME}"                             || {
            print-red "Device load${SUFFIX_NAME} image failed: docker load failed !!!"
            return -1
        }

        qimsdk-device-command "${QIMSDK_DEVICE_ID}" "rm ${DEVICE_IMAGES_PATH}/${FILE_NAME}"     || {
            print-red "Device failed to remove ${FILE_NAME} !!!"
            return -1
        }

        return 0
    )                                                                                           || {
        print-red "FAILED: Device load${SUFFIX_NAME} image !!!"
        return -1
    }

    print-green "Device load${SUFFIX_NAME} image successful !!!"

    return 0
}

# Load selected device image
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-load-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-load-image-variant ${PATH_TO_CONFIG_JSON} native
}

# Load selected py device image
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-load-py-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-load-image-variant ${PATH_TO_CONFIG_JSON} python
}

# Run dbg dev container
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-docker-run-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local DOCKER_IMAGE_PATH
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH                       || {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return -1
    }

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return -1
    }

    local DEVELOPMENT_MAP

    qimsdk-get-map-for-dbg-container ${PATH_TO_CONFIG_JSON}                                        \
            DEVELOPMENT_MAP

    local USB_DEVICE=""
    [ -d /dev/bus/usbd ] && USB_DEVICE="--device /dev/bus/usb"

    docker run -it -d --net host -h ${QIMSDK_CONTAINER_NAME}_dbg                                   \
            --env QIMSDK_DEVICE_ID=${QIMSDK_DEVICE_ID}                                             \
            --env QIMSDK_CONTAINER_NAME=${QIMSDK_CONTAINER_NAME}                                   \
            --name ${QIMSDK_CONTAINER_NAME}_dbg                                                    \
            ${USB_DEVICE} ${DEVELOPMENT_MAP}                                                       \
            ${QIMSDK_IMAGE_NAME}-debian bash                                                    || {
        print-red "Run dbg container failed !!!"
        return -1
    }

    # Propagate ssh and gitconfig to container
    docker exec --user root ${QIMSDK_CONTAINER_NAME}_dbg mkdir -p /root/.ssh                    || {
        print-red "docker mkdir ~/.ssh failed !!!"
        return -1
    }

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp ${f} ${QIMSDK_CONTAINER_NAME}_dbg:/root/.ssh/${BASE_NAME}                 || {
                print-red "Propagating .ssh/ to docker failed !!!"
                return -1
            }
        done
        docker exec --user root ${QIMSDK_CONTAINER_NAME}_dbg chown -R root:root /root/.ssh      || {
            print-red "Propagating .ssh/ to docker failed !!!"
            return -1
        }
    fi

    if [ -f ~/.gitconfig ]; then
        docker cp ~/.gitconfig ${QIMSDK_CONTAINER_NAME}_dbg:/root/.gitconfig                    && \
            docker exec --user root ${QIMSDK_CONTAINER_NAME}_dbg chown -R root:root                \
                /root/.gitconfig                                                                || {
                print-red "Propagating .gitconfig to docker failed !!!"
                return -1
            }
    fi

    if [ -f /etc/gitconfig ]; then
        docker cp /etc/gitconfig ${QIMSDK_CONTAINER_NAME}_dbg:/etc/gitconfig                    || {
            print-red "Propagating .gitconfig to docker failed !!!"
            return -1
        }
    fi

    print-green "Run dbg container successful !!!"

    return 0
}

# Run selected device container
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-device-docker-run-container-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    docker run -it -d --net host -h ${QIMSDK_CONTAINER_NAME}                                       \
            --name ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME}                                          \
            ${QIMSDK_IMAGE_NAME}-debian-deploy${SUFFIX_NAME} bash                               || {
        print-red "Run${SUFFIX_NAME} device container failed on pc emulator !!!"
        return -1
    }

    # Propagate ssh and gitconfig to container
    docker exec --user root ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME} mkdir /root/.ssh             || {
        print-red "docker mkdir ~/.ssh failed !!!"
        return -1
    }

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp ${f} ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME}:/root/.ssh/${BASE_NAME}       || {
                print-red "Propagating .ssh/ to docker failed !!!"
                return -1
            }
        done
        docker exec --user root ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME}                             \
                chown -R root:root /root/.ssh                                                   || {
            print-red "Propagating .ssh/ to docker failed !!!"
            return -1
        }
    fi

    print-green "Run${SUFFIX_NAME} device container successful on pc emulator !!!"

    return 0
}

# Run selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-device-docker-run-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-device-docker-run-container-variant ${PATH_TO_CONFIG_JSON} native
}

# Run selected py device container
#   $1 - (mandatory) path to target config json
function qimsdk-device-docker-run-py-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-device-docker-run-container-variant ${PATH_TO_CONFIG_JSON} python
}

# Run selected device container in cdi mode
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-docker-device-run-container-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return -1
    }

    (
        local MACHINE=$(qimsdk-cmd "${QIMSDK_DEVICE_ID}"                                           \
                shell "cat /sys/devices/soc0/machine" | tr -d '\r')                             || {
            print-red "FAILED: reading /sys/devices/soc0/machine !!!"
            return -1
        }

        local MEDIA_DIRS=("labels" "media" "models" "configs")

        for idx in ${!MEDIA_DIRS[@]}; do
            qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                            \
                        "mkdir -m 777 -p /etc/${MEDIA_DIRS[$idx]}"                              || {
                print-red "FAILED: /etc/${MEDIA_DIRS[$idx]} can not be created in device !!!"
                return -1
            }
        done

        local TMP_RUN_CMD_DIR=$(mktemp -d)

        qimsdk-generate-docker-run-cmd ${TMP_RUN_CMD_DIR}/docker_run${SUFFIX_NAME}.sh              \
                ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME}                                             \
                ${QIMSDK_IMAGE_NAME}-debian-deploy${SUFFIX_NAME}                                || {
            print-red "Generate ${TMP_RUN_CMD_DIR}/docker_run${SUFFIX_NAME}.sh file failed !!!"
            rm -rf ${TMP_RUN_CMD_DIR}
            return -1
        }

        qimsdk-cmd "${QIMSDK_DEVICE_ID}" push ${TMP_RUN_CMD_DIR}/docker_run${SUFFIX_NAME}.sh       \
                /tmp/                                                                           && \
        qimsdk-device-command "${QIMSDK_DEVICE_ID}" "source /tmp/docker_run${SUFFIX_NAME}.sh"   || {
            rm -rf ${TMP_RUN_CMD_DIR}
            qimsdk-device-command "${QIMSDK_DEVICE_ID}" "rm -rf /tmp/docker_run${SUFFIX_NAME}.sh"
            echo "${FUNCNAME[0]} failed !!!"
            return -1
        }

        rm -rf ${TMP_RUN_CMD_DIR}
        qimsdk-device-command "${QIMSDK_DEVICE_ID}" "rm -rf /tmp/docker_run${SUFFIX_NAME}.sh"
    )                                                                                           || {
        print-red "Device run${SUFFIX_NAME} container failed !!!"
        return -1
    }

    print-green "Device run${SUFFIX_NAME} container successful !!!"

    return 0
}

# Run selected device container in cdi mode
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-run-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-run-container-variant ${PATH_TO_CONFIG_JSON} native
}

# Run selected py device container in cdi mode
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-run-py-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-run-container-variant ${PATH_TO_CONFIG_JSON} python
}

# Remove selected device container
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-docker-device-rm-container-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return -1
    }

    qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                                    \
            "docker rm ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME}"                                  || {
        print-red "Device rm${SUFFIX_NAME} container failed !!!"
        return -1
    }

    print-green "Device rm${SUFFIX_NAME} container successful !!!"

    return 0
}

# Remove selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-rm-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-rm-container-variant ${PATH_TO_CONFIG_JSON} native
}

# Remove selected py device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-rm-py-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-rm-container-variant ${PATH_TO_CONFIG_JSON} python
}

# Start selected device container
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-docker-device-start-container-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return -1
    }

    qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                                    \
            "docker start ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME}"                               || {
        print-red "Device start${SUFFIX_NAME} container failed !!!"
        return -1
    }

    print-green "Device start${SUFFIX_NAME} container successful !!!"

    return 0
}

# Start selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-start-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-start-container-variant ${PATH_TO_CONFIG_JSON} native
}

# Start selected py device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-start-py-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-start-container-variant ${PATH_TO_CONFIG_JSON} python
}

# Stop selected device container
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-docker-device-stop-container-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return -1
    }

    qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                                    \
            "docker stop ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME}"                                || {
        print-red "Device stop${SUFFIX_NAME} container failed !!!"
        return -1
    }

    print-green "Device stop${SUFFIX_NAME} container successful !!!"

    return 0
}

# Stop selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-stop-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-stop-container-variant ${PATH_TO_CONFIG_JSON} native
}

# Stop selected py device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-stop-py-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-stop-container-variant ${PATH_TO_CONFIG_JSON} python
}

# Execute CMD in device container
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) command to execute
#   $3 - (mandatory) container type: native | python
function qimsdk-docker-device-command-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CMD=${2}
    local CONTAINER_TYPE=${3}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return -1
    }

    qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                                    \
            "docker exec ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME} bash -c ${CMD}"                 || {
        print-red "FAILED: qimsdk-device-command !!!"
        return -1
    }

    return 0
}

# Execute CMD in device container
#   $1 - (mandatory) path to target config json
#   $2 - (optional) command to execute
function qimsdk-docker-device-command() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CMD=${2}
    qimsdk-docker-device-command-variant ${PATH_TO_CONFIG_JSON} ${CMD} native
}

# Execute CMD in py device container
#   $1 - (mandatory) path to target config json
#   $2 - (optional) command to execute
function qimsdk-docker-device-py-command() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CMD=${2}
    qimsdk-docker-device-command-variant ${PATH_TO_CONFIG_JSON} ${CMD} python
}

# Start shell in the docker container on the device
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) container type: native | python
function qimsdk-docker-device-shell-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local CONTAINER_TYPE=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    [ "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                  || {
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    local SUFFIX_NAME=""
    [ "${CONTAINER_TYPE}" == "python" ] && SUFFIX_NAME="-py"

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return -1
    }

    local TRANSPORT
    qimsdk-device-transport "${QIMSDK_DEVICE_ID}" TRANSPORT                                     || {
        print-red "FAILED: qimsdk-device-transport !!!"
        return -1
    }

    if [ "${TRANSPORT}" = "adb" ]; then
        adb -s ${QIMSDK_DEVICE_ID} shell -t                                                        \
                "docker exec -it ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME} bash"
    else
        # Connect using the bare device ID as the ssh target and let the host's
        # ~/.ssh/config govern the user, hostname and identity (passwordless,
        # key-based access).
        local -a SSH_OPTS
        qimsdk-ssh-opts SSH_OPTS
        ssh -t "${SSH_OPTS[@]}" "${QIMSDK_DEVICE_ID}"                                              \
                "docker exec -it ${QIMSDK_CONTAINER_NAME}${SUFFIX_NAME} bash"
    fi
}

# Start shell in the docker container on the device
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-shell() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-shell-variant ${PATH_TO_CONFIG_JSON} native
}

# Start shell in the py docker container on the device
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-py-shell() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-docker-device-shell-variant ${PATH_TO_CONFIG_JSON} python
}

# Docker device images clean up
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-images-cleanup() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_DEVICE_ID

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return -1
    }

    local DEVICE_DOCKER_IMAGES=$(
        qimsdk-device-command "${QIMSDK_DEVICE_ID}" "docker images -f 'dangling=true' -q"
    )

    qimsdk-device-command "${QIMSDK_DEVICE_ID}" "docker rmi ${DEVICE_DOCKER_IMAGES}"            || {
        print-red "FAILED: qimsdk-device-command !!!"
        return -1
    }

    print-green "Device docker images cleanup complete !!!"

    return 0
}

# Docker host images clean up
function qimsdk-docker-host-images-cleanup() {
    local HOST_DOCKER_IMAGES=$(docker images -f "dangling=true" -q)

    docker rmi ${HOST_DOCKER_IMAGES}                                                            || {
        print-red "FAILED: docker rmi of all !!!"
        return -1
    }

    docker builder prune -a -f                                                                  || {
        print-red "FAILED: docker builder prune -a -f !!!"
        return -1
    }

    print-green "Host docker images cleanup complete !!!"

    return 0
}

# Load artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) artifacts variant - release or debug
function qimsdk-dbg-load-artifacts-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local VARIANT=${2}
    local CONTAINER_TYPE=${3}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID
    local DOCKER_IMAGE_PATH

    [ "${VARIANT}" == "release" ] || [ "${VARIANT}" == "debug" ]                                || {
        print-red "Failed to load ${VARIANT} packages !!!"
        print-red "Wrong variant provided: supported variants: release, debug !!!"
        return -1
    }

    [  "${CONTAINER_TYPE}" == "native" ] || [ "${CONTAINER_TYPE}" == "python" ]                 || {
        print-red "Failed to load ${CONTAINER_TYPE} packages !!!"
        print-red "Wrong container type provided: supported options: native, python !!!"
        return -1
    }

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    [ "${CONTAINER_TYPE}" == "python" ] && QIMSDK_CONTAINER_NAME="${QIMSDK_CONTAINER_NAME}-py"

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH                       || {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return -1
    }

    [[ "${DOCKER_IMAGE_PATH}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH}" ]                    && {
        mkdir -p ${DOCKER_IMAGE_PATH}                                                           || {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH} !!!"
            return -1
        }
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    (
        [ -z "${QIMSDK_DEVICE_ID}" ]                                                            && {
            print-red "Device ID is not set !!!"
            rm -f qimsdk_dev_artifacts_${VARIANT}.tar

            return -1
        }

        rsync -aP ${DOCKER_IMAGE_PATH}/qimsdk_dev_artifacts_${VARIANT}.tar .                    && \
                qimsdk-device-command "${QIMSDK_DEVICE_ID}" "mkdir -p /tmp/qti/development"     && \
                qimsdk-cmd "${QIMSDK_DEVICE_ID}" push qimsdk_dev_artifacts_${VARIANT}.tar          \
                        /tmp/qti/development/                                                   && \
                qimsdk-device-command "${QIMSDK_DEVICE_ID}" "cd /tmp/qti/development && `
                        `tar -xf /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar && `
                        `docker cp usr ${QIMSDK_CONTAINER_NAME}:/"                              && \
                qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                        \
                        "rm -rf /tmp/qti/development/usr"                                       || {
            print-red "Artifacts load failed !!!"

            qimsdk-device-command "${QIMSDK_DEVICE_ID}" "rm -rf /tmp/qti/development/usr"
            qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                            \
                    "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"

            rm -f qimsdk_dev_artifacts_${VARIANT}.tar

            return -1
        }

        qimsdk-device-command "${QIMSDK_DEVICE_ID}"                                                \
                "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"
        rm -f qimsdk_dev_artifacts_${VARIANT}.tar
    )

    echo "dbg ${VARIANT} artifacts loaded from ${DOCKER_IMAGE_PATH}"
}

# Load release artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-load-artifacts() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-dbg-load-artifacts-variant ${PATH_TO_CONFIG_JSON} release native
}

# Load release artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-load-artifacts-py() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-dbg-load-artifacts-variant ${PATH_TO_CONFIG_JSON} release python
}

# Load debug artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-load-artifacts-dbg() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-dbg-load-artifacts-variant ${PATH_TO_CONFIG_JSON} debug native
}

# Load debug artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-load-artifacts-dbg-py() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-dbg-load-artifacts-variant ${PATH_TO_CONFIG_JSON} debug python
}

# Abosulute path to the Docker source directory
QIMSDK_DOCKER_DIR="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"/.. && pwd )"
source ${QIMSDK_DOCKER_DIR}/scripts-dbg/common.sh

print-green "Docker build environment setup"
echo "=============================="
print-yellow "Device Docker Commands"
echo        "======================"
print-green "qimsdk-docker-build-image                                        <path-to-config-json>"
echo "    Build device Docker image"
print-blue "qimsdk-docker-device-update-image                                 <path-to-config-json>"
echo "    Update selected device image to the device"
print-blue "qimsdk-docker-device-save-image                                   <path-to-config-json>"
echo "    Save selected device image, compose file and run command"
print-blue "qimsdk-docker-device-load-image                                   <path-to-config-json>"
echo "    Loads device image on the device"
print-blue "qimsdk-docker-device-run-container                                <path-to-config-json>"
echo "    Run device container in mode"
print-blue "qimsdk-docker-device-rm-container                                 <path-to-config-json>"
echo "    Remove device container"
print-blue "qimsdk-docker-device-start-container                              <path-to-config-json>"
echo "    Start device container"
print-blue "qimsdk-docker-device-stop-container                               <path-to-config-json>"
echo "    Stop device container"
print-blue "qimsdk-docker-device-command                                <path-to-config-json> <CMD>"
echo "    Execute CMD in device container"
print-blue "qimsdk-docker-device-shell                                        <path-to-config-json>"
echo "    Start shell in the docker container on the device"
print-red "qimsdk-docker-device-images-cleanup                                <path-to-config-json>"
echo "    Docker device images clean up"
print-red "qimsdk-docker-host-images-cleanup"
echo "    Docker host images clean up"
echo        "==================="
print-yellow "Device Docker Commands for container with python support"
echo        "==================="
print-green "qimsdk-docker-build-image-py                                     <path-to-config-json>"
echo "    Build device Docker image with python support"
print-blue "qimsdk-docker-device-update-py-image                              <path-to-config-json>"
echo "    Update selected device image to the device"
print-blue "qimsdk-docker-device-save-py-image                                <path-to-config-json>"
echo "    Save selected device image, compose file and run command"
print-blue "qimsdk-docker-device-load-py-image                                <path-to-config-json>"
echo "    Loads device image on the device"
print-blue "qimsdk-docker-device-run-py-container                             <path-to-config-json>"
echo "    Run device container in mode"
print-blue "qimsdk-docker-device-rm-py-container                              <path-to-config-json>"
echo "    Remove device container"
print-blue "qimsdk-docker-device-start-py-container                           <path-to-config-json>"
echo "    Start device container"
print-blue "qimsdk-docker-device-stop-py-container                            <path-to-config-json>"
echo "    Stop device container"
print-blue "qimsdk-docker-device-py-command                             <path-to-config-json> <CMD>"
echo "    Execute CMD in device container"
print-blue "qimsdk-docker-device-py-shell                                     <path-to-config-json>"
echo "    Start shell in the docker container on the device"
echo        "==================="
print-yellow "Debug dev Docker Commands"
echo        "==================="
print-green "qimsdk-dbg-docker-build-image                                    <path-to-config-json>"
echo "    Build debug dev Docker image"
print-blue "qimsdk-dbg-docker-run-container                                   <path-to-config-json>"
echo "    Run debug dev Docker container"
print-blue "qimsdk-dbg-send-artifacts-to-device                               <path-to-config-json>"
echo "    Copy artifacts directly to /tmp/qti/development/ path in device"
print-blue "qimsdk-dbg-save-artifacts                                         <path-to-config-json>"
echo "    Save artifacts to Docker_image_path provided in config json file."
print-blue "qimsdk-dbg-save-artifacts-dbg                                     <path-to-config-json>"
echo "    Save debug artifacts to Docker_image_path provided in config json file."
print-blue "qimsdk-dbg-load-artifacts                                         <path-to-config-json>"
echo "    Load artifacts from Docker_image_path provided in config json file."
print-blue "qimsdk-dbg-load-artifacts-dbg                                     <path-to-config-json>"
echo "    Load debug artifacts from Docker_image_path provided in config json file."
print-blue "qimsdk-dbg-load-artifacts-py                                      <path-to-config-json>"
echo "    Load artifacts from Docker_image_path provided in config json file to py container."
print-blue "qimsdk-dbg-load-artifacts-dbg-py                                  <path-to-config-json>"
echo "    Load debug artifacts from Docker_image_path provided in config json file to py container."
