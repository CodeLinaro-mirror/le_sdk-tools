#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# expand tilde to real path
#   $1 - (mandatory) path
function builder-expand-tilde() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local -n INPUT_PATH=${1}

    [[ "$INPUT_PATH" == ~* ]] && {
        # Swap "~" with ${HOME} variable
        INPUT_PATH="${INPUT_PATH/#\~/${HOME}}"
    }
}

# Get container and image from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give container name as argument
#   $3 - (mandatory) give image name as argument
function builder-get-container-and-image-name() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
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

# Parse json configuraiton
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) variable to take container name value
#   $3 - (mandatory) variable to take image name value
#   $4 - (mandatory) variable to take qimsdk sources dir
function builder-docker-parse-json() {
    local QIMSDK_ARG_COUNT_EXPECTED=4
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_CONTAINER_NAME=${2}
    local -n OUT_QIMSDK_IMAGE_NAME=${3}
    local -n OUT_QIMSDK_SOURCE_DIR=${4}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ]                                                           && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    # Forward through distinctly-named locals: builder-get-container-and-image-name
    # declares its own namerefs as OUT_QIMSDK_CONTAINER_NAME/OUT_QIMSDK_IMAGE_NAME,
    # so passing those same names here would make its `local -n` self-referential
    # (bash "circular name reference"), silently losing the value.
    local QIMSDK_PARSED_CONTAINER_NAME
    local QIMSDK_PARSED_IMAGE_NAME

    builder-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                    \
            QIMSDK_PARSED_CONTAINER_NAME                                                           \
            QIMSDK_PARSED_IMAGE_NAME                                                            || {
        print-red "FAILED: builder-get-container-and-image-name !!!"
        return -1
    }

    OUT_QIMSDK_CONTAINER_NAME="${QIMSDK_PARSED_CONTAINER_NAME}"
    OUT_QIMSDK_IMAGE_NAME="${QIMSDK_PARSED_IMAGE_NAME}"

    OUT_QIMSDK_SOURCE_DIR=$(echo ${JSON_CONTENT} | jq '.QIMSDK_Source_Dir' | tr -d '"')
    OUT_QIMSDK_SOURCE_DIR=${OUT_QIMSDK_SOURCE_DIR%/}

    builder-expand-tilde OUT_QIMSDK_SOURCE_DIR

    [ -d "${OUT_QIMSDK_SOURCE_DIR}/.git" ]                                                      || \
            [ -d "${OUT_QIMSDK_SOURCE_DIR}/gstreamer/gst-plugin-base" ]                         || {
        print-red "Please provide path to qimsdk directory in config json!!!"
        print-red "Directory currently provided: ${OUT_QIMSDK_SOURCE_DIR}"
        return -1
    }

    return 0
}

# Get remote sync destination from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Docker_image_path as argument
function builder-get-docker-image-path() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
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

    builder-expand-tilde OUT_DOCKER_IMAGE_PATH

    [ -z "${OUT_DOCKER_IMAGE_PATH}" ] && {
        print-red "Docker_image_path attribute in config.json is not set !!!"
        return -1
    }

    return 0
}

# Get target device ID from json (optional)
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give device ID as argument
function builder-get-device-id() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
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

    [ -z "${OUT_TARGET_DEVICE_ID}" ] && return 0

    builder-is-adb-serial "${OUT_TARGET_DEVICE_ID}"                                             || \
            builder-is-ipv4 "${OUT_TARGET_DEVICE_ID}"                                           || {
        print-red "Target_device_ID '${OUT_TARGET_DEVICE_ID}' is neither a valid adb serial"
        print-red "number nor a valid IPv4 address (XXX.XXX.XXX.XXX) !!!"
        return -1
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
function builder-docker-build-initialize() {
    local QIMSDK_ARG_COUNT_EXPECTED=6
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}

    local -n QIMSDK_CONTAINER_NAME_PTR=${2}
    local -n QIMSDK_IMAGE_NAME_PTR=${3}
    local -n QIMSDK_TMP_FOLDER_PTR=${4}
    local -n DOCKER_IMAGE_PATH_PTR=${5}
    local -n QIMSDK_DEVICE_ID_PTR=${6}

    local QIMSDK_SOURCE_DIR

    builder-docker-parse-json ${PATH_TO_CONFIG_JSON}                                               \
            QIMSDK_CONTAINER_NAME_PTR                                                              \
            QIMSDK_IMAGE_NAME_PTR                                                                  \
            QIMSDK_SOURCE_DIR                                                                   || {
        print-red "FAILED: builder-docker-parse-json !!!"
        return -1
    }

    builder-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH_PTR                  || {
        print-red "FAILED: builder-get-docker-image-path !!!"
        return -1
    }

    [[ "${DOCKER_IMAGE_PATH_PTR}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH_PTR}" ]            && {
        mkdir -p ${DOCKER_IMAGE_PATH_PTR}                                                       || {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH_PTR} !!!"
            return -1
        }
    }

    builder-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID_PTR                           || {
        print-red "FAILED: builder-get-device-id !!!"
        return -1
    }

    rsync -aL ${QIMSDK_SOURCE_DIR}/ ${QIMSDK_TMP_FOLDER_PTR}/qimsdk                             || {
        print-red "FAILED: rsync ${QIMSDK_SOURCE_DIR} to ${QIMSDK_TMP_FOLDER_PTR} !!!"
        return -1
    }

    return 0
}

# Argument unsigned 10-digit number checker.
#   $1 - (mandatory) number argument to be checked
function builder-is-arg-number() {
    local ARG_COUNT_EXPECTED=1
    ! builder-arg-count-check $# ${ARG_COUNT_EXPECTED}                                          && \
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
function builder-get-max-build-jobs() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
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
                    builder-is-arg-number "${OUT_QIMSDK_MAX_BUILD_JOBS}"                        && {
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

# Get optional qimsdk git tag/branch/commit to build from json
#   $1 - (mandatory) path to target config json
#   $2 - (output) give tag value, empty if unset
function builder-get-qimsdk-tag() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_GST_PLUGINS_TAG=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ]                                                           && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QIMSDK_GST_PLUGINS_TAG=$(
        jq -er '.QIMSDK_Source_git_tag // ""' <<< "${JSON_CONTENT}" 2>/dev/null || echo ""
    )

    return 0
}

# Get optional name of the deploy docker container running on the target
# device to build from json
#   $1 - (mandatory) path to target config json
#   $2 - (output) give container name value, empty if unset
function builder-get-deploy-container-name() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_DEPLOY_CONTAINER_NAME=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ]                                                           && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QIMSDK_DEPLOY_CONTAINER_NAME=$(
        jq -er '.Target_deploy_container_name // ""' <<< "${JSON_CONTENT}" 2>/dev/null || echo ""
    )

    [ -n "${OUT_QIMSDK_DEPLOY_CONTAINER_NAME}" ]                                                && \
            ! [[ "${OUT_QIMSDK_DEPLOY_CONTAINER_NAME}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]       && {
        print-red "Target_deploy_container_name '${OUT_QIMSDK_DEPLOY_CONTAINER_NAME}' is not a"
        print-red "valid docker container name !!!"
        return -1
    }

    return 0
}

# Qimsdk build qimsdk_dev_builder docker image, rebased onto the local dbg base image
#   $1 - (mandatory) final image name
#   $2 - (mandatory) dbg base image to rebase FROM onto
#   $3 - (mandatory) path to target config json
function builder-docker-build-builder-dev-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local IMAGE_NAME=${1}
    local QIMSDK_DBG_BASE_IMAGE=${2}
    local PATH_TO_CONFIG_JSON=${3}
    local QIMSDK_MAX_BUILD_JOBS
    local QIMSDK_GST_PLUGINS_TAG

    [ ! -d ${QIMSDK_DOCKER_DIR} ]                                                               && {
        print-red "No such directory: ${QIMSDK_DOCKER_DIR}!"
        return -1
    }

    [ -z ${IMAGE_NAME} ]                                                                        && {
        print-red "Image name is empty!"
        return -1
    }

    ! builder-get-max-build-jobs ${PATH_TO_CONFIG_JSON} QIMSDK_MAX_BUILD_JOBS                   && {
        print-red "Incorrect QIMSDK_MAX_BUILD_JOBS argument value!"
        return -1
    }

    builder-get-qimsdk-tag ${PATH_TO_CONFIG_JSON} QIMSDK_GST_PLUGINS_TAG                        || {
        print-red "FAILED: builder-get-qimsdk-tag !!!"
        return -1
    }

    (
        cd ${QIMSDK_DOCKER_DIR} || return -1

        local DOCKERFILE="${QIMSDK_DOCKER_DIR}/Dockerfile"

        # Modify Dockerfile to use the freshly-built dbg base image as base
        sed -E                                                                                     \
            "s|^(FROM[[:space:]]+)debian:trixie-slim([[:space:]]+AS[[:space:]]+qimsdk_dev_builder)|\1${QIMSDK_DBG_BASE_IMAGE}\2|" \
            ${DOCKERFILE} > ${DOCKERFILE}.work

        grep -qF "FROM ${QIMSDK_DBG_BASE_IMAGE}" ${DOCKERFILE}.work                             || {
            rm -f ${DOCKERFILE}.work
            print-red "FAILED: rebase of ${DOCKERFILE} onto ${QIMSDK_DBG_BASE_IMAGE} did not take`
            ` effect !!!"
            return -1
        }

        docker build                                                                               \
                --build-arg QIMSDK_ARG_MAX_JOBS=${QIMSDK_MAX_BUILD_JOBS}                           \
                --build-arg QIMSDK_ARG_GST_PLUGINS_TAG=${QIMSDK_GST_PLUGINS_TAG}                   \
                --target qimsdk_dev_builder                                                        \
                ${QIMSDK_DOCKER_DIR} -t ${IMAGE_NAME}                                              \
                -f ${DOCKERFILE}.work                                                           || {
            rm -f ${DOCKERFILE}.work
            print-red "Build qimsdk dev image failed !!!"
            return -1
        }

        rm -f ${DOCKERFILE}.work
    )
}

# Build dev docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function builder-docker-build-image() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH
    local QIMSDK_DEVICE_ID

    local QIMSDK_TMP_FOLDER="${QIMSDK_DOCKER_DIR}/tmp"
    mkdir -p ${QIMSDK_TMP_FOLDER}                                                               || {
        print-red "FAILED: mkdir -p ${QIMSDK_TMP_FOLDER} !!!"
        return -1
    }

    builder-docker-build-initialize ${PATH_TO_CONFIG_JSON}                                         \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                      \
            QIMSDK_TMP_FOLDER                                                                      \
            DOCKER_IMAGE_PATH                                                                      \
            QIMSDK_DEVICE_ID                                                                    || {
        print-red "FAILED: builder-docker-build-initialize !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return -1
    }

    local QIMSDK_DBG_BASE_IMAGE="${QIMSDK_IMAGE_NAME}-dbgbase"

    docker build                                                                                   \
            --target qimsdk_dbg_image -f ${QIMSDK_DOCKER_DIR}/Dockerfile.dbg                       \
            ${QIMSDK_DOCKER_DIR} -t ${QIMSDK_DBG_BASE_IMAGE}                                    || {
        print-red "Build image failed !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return -1
    }

    builder-docker-build-builder-dev-image ${QIMSDK_IMAGE_NAME} ${QIMSDK_DBG_BASE_IMAGE}           \
            ${PATH_TO_CONFIG_JSON}                                                              || {
        print-red "FAILED: builder-docker-build-builder-dev-image !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return -1
    }

    rm -rf ${QIMSDK_TMP_FOLDER}

    print-green "Build image completed successfully !!!"

    return 0
}

# Run dev container
#   $1 - (mandatory) path to target config json
function builder-docker-run-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID
    local QIMSDK_DEPLOY_CONTAINER_NAME
    local QIMSDK_DOCKER_IMAGE_PATH

    builder-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                    \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: builder-get-container-and-image-name !!!"
        return -1
    }

    builder-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                               || {
        print-red "FAILED: builder-get-device-id  !!!"
        return -1
    }

    builder-get-deploy-container-name ${PATH_TO_CONFIG_JSON} QIMSDK_DEPLOY_CONTAINER_NAME       || {
        print-red "FAILED: builder-get-deploy-container-name !!!"
        return -1
    }

    builder-get-docker-image-path ${PATH_TO_CONFIG_JSON} QIMSDK_DOCKER_IMAGE_PATH               || {
        print-red "FAILED: builder-get-docker-image-path !!!"
        return -1
    }

    # "localhost" means the dbg container runs directly on the target embedded
    # device (no remote device to control over adb/ssh); any other device ID
    # means the container runs on a build machine controlling a remote target.
    local QIMSDK_WORK_ENVIRONMENT="build_machine"
    [ "${QIMSDK_DEVICE_ID}" == "localhost" ] && QIMSDK_WORK_ENVIRONMENT="target_device"

    local USB_DEVICE=""
    [ -d /dev/bus/usb ] && USB_DEVICE="--device /dev/bus/usb"

    # Bridge the container's artifacts directory (QIMSDK_DOCKER_IMAGE_PATH,
    # written to by builder-save-artifacts-variant) directly onto the host's
    # configured Docker_image_path, so saved artifacts land on the host with
    # no extra copy step. Only possible when Docker_image_path is a local
    # directory - a remote rsync target (user@host:/path) can't be bind
    # mounted, so it keeps relying on rsync-over-ssh from inside the container.
    local -a QIMSDK_ARTIFACTS_MOUNT=()
    [[ "${QIMSDK_DOCKER_IMAGE_PATH}" != *":"* ]] && {
        [ -d "${QIMSDK_DOCKER_IMAGE_PATH}" ] || {
            mkdir -p ${QIMSDK_DOCKER_IMAGE_PATH}                                                || {
                print-red "FAILED: mkdir -p ${QIMSDK_DOCKER_IMAGE_PATH} !!!"
                return -1
            }
        }
        QIMSDK_ARTIFACTS_MOUNT=(-v ${QIMSDK_DOCKER_IMAGE_PATH}:${QIMSDK_DOCKER_IMAGE_PATH})
    }

    docker run -it -d --net host -h ${QIMSDK_CONTAINER_NAME}_builder                               \
            --env QIMSDK_DEVICE_ID=${QIMSDK_DEVICE_ID}                                             \
            --env QIMSDK_CONTAINER_NAME=${QIMSDK_CONTAINER_NAME}                                   \
            --env QIMSDK_DEPLOY_CONTAINER_NAME=${QIMSDK_DEPLOY_CONTAINER_NAME}                     \
            --env WORK_ENVIRONMENT=${QIMSDK_WORK_ENVIRONMENT}                                      \
            --env QIMSDK_DOCKER_IMAGE_PATH=${QIMSDK_DOCKER_IMAGE_PATH}                             \
            --name ${QIMSDK_CONTAINER_NAME}_builder                                                \
            ${USB_DEVICE}                                                                          \
            "${QIMSDK_ARTIFACTS_MOUNT[@]}"                                                         \
            ${QIMSDK_IMAGE_NAME} bash                                                           || {
        print-red "Run container failed !!!"
        return -1
    }

    # Propagate ssh and gitconfig to container
    docker exec --user root ${QIMSDK_CONTAINER_NAME}_builder mkdir -p /root/.ssh                || {
        print-red "docker mkdir ~/.ssh failed !!!"
        return -1
    }

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp ${f} ${QIMSDK_CONTAINER_NAME}_builder:/root/.ssh/${BASE_NAME}             || {
                print-red "Propagating .ssh/ to docker failed !!!"
                return -1
            }
        done
        docker exec --user root ${QIMSDK_CONTAINER_NAME}_builder chown -R root:root /root/.ssh  || {
            print-red "Propagating .ssh/ to docker failed !!!"
            return -1
        }
    fi

    if [ -f ~/.gitconfig ]; then
        docker cp ~/.gitconfig ${QIMSDK_CONTAINER_NAME}_builder:/root/.gitconfig                && \
            docker exec --user root ${QIMSDK_CONTAINER_NAME}_builder chown -R root:root            \
                /root/.gitconfig                                                                || {
                print-red "Propagating .gitconfig to docker failed !!!"
                return -1
            }
    fi

    if [ -f /etc/gitconfig ]; then
        docker cp /etc/gitconfig ${QIMSDK_CONTAINER_NAME}_builder:/etc/gitconfig                || {
            print-red "Propagating .gitconfig to docker failed !!!"
            return -1
        }
    fi

    print-green "Run container successful !!!"

    return 0
}

# Run the artifacts save step inside the running dbg container (only the
# container knows QIMSDK_INSTALL_DIR/QIMSDK_INSTALL_DEBUG_DIR). The save step
# rsyncs its tar to QIMSDK_DOCKER_IMAGE_PATH, which builder-docker-run-
# container bind mounts onto the host's Docker_image_path - so once the save
# step returns, the tar is already visible on the host at that same path, and
# just needs to be copied into a fresh staging directory - callers extract it
# locally (localhost) or push it as-is and extract it remotely (adb/ssh).
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) running dbg container name
#   $3 - (mandatory) artifacts variant - release or debug
#   $4 - (mandatory) variable to take the local staging directory path
function builder-fetch-saved-artifacts() {
    local QIMSDK_ARG_COUNT_EXPECTED=4
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_DBG_CONTAINER=${2}
    local VARIANT=${3}
    local -n OUT_STAGING_DIR=${4}

    local QIMSDK_DOCKER_IMAGE_PATH
    builder-get-docker-image-path ${PATH_TO_CONFIG_JSON} QIMSDK_DOCKER_IMAGE_PATH               || {
        print-red "FAILED: builder-get-docker-image-path !!!"
        return -1
    }

    [ "${VARIANT}" == "release" ]                                                               && {
        docker exec --user root ${QIMSDK_DBG_CONTAINER} bash -c                                    \
                    'source ${QIMSDK_SCRIPTS}/env_setup.sh builder-save-artifacts'              || {
            print-red "FAILED: builder-save-artifacts (in ${QIMSDK_DBG_CONTAINER}) !!!"
            print-yellow "NOTE: Need running container ${QIMSDK_DBG_CONTAINER} for`
                    ` function to work !!!"
            return -1
        }
    }

    [ "${VARIANT}" == "debug" ]                                                                 && {
        docker exec --user root ${QIMSDK_DBG_CONTAINER} bash -c                                    \
                    'source ${QIMSDK_SCRIPTS}/env_setup.sh builder-save-artifacts-dbg'          || {
            print-red "FAILED: builder-save-artifacts-dbg (in ${QIMSDK_DBG_CONTAINER}) !!!"
            print-yellow "NOTE: Need running container ${QIMSDK_DBG_CONTAINER} for`
                    ` function to work !!!"
            return -1
        }
    }

    OUT_STAGING_DIR="${QIMSDK_DOCKER_IMAGE_PATH}/tmp/push_${VARIANT}_$(date +%Y%m%d%H%M%S)"
    rm -rf ${OUT_STAGING_DIR}
    mkdir -p ${OUT_STAGING_DIR}

    cp ${QIMSDK_DOCKER_IMAGE_PATH}/qimsdk_dev_artifacts_${VARIANT}.tar ${OUT_STAGING_DIR}/      || {
        print-red "FAILED: copy artifacts tar !!!"
        rm -rf ${OUT_STAGING_DIR}
        return -1
    }

    return 0
}

# Push artifacts directly onto the target device's own root filesystem
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) artifacts variant - release or debug
function builder-push-artifacts-device-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local VARIANT=${2}

    [ "${VARIANT}" == "release" ] || [ "${VARIANT}" == "debug" ] || {
        print-red "Wrong variant provided: supported variants: release, debug !!!"
        return -1
    }

    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    builder-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                    \
            QIMSDK_CONTAINER_NAME QIMSDK_IMAGE_NAME                                             || {
        print-red "FAILED: builder-get-container-and-image-name !!!"
        return -1
    }

    builder-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                               || {
        print-red "FAILED: builder-get-device-id !!!"
        return -1
    }

    local QIMSDK_STAGING_DIR
    builder-fetch-saved-artifacts "${PATH_TO_CONFIG_JSON}" "${QIMSDK_CONTAINER_NAME}_builder"      \
            "${VARIANT}" QIMSDK_STAGING_DIR                                                     || \
        return -1

    [ "${QIMSDK_DEVICE_ID}" == "localhost" ] && {
        local TARGET_SU_REQUIRED=""
        [ "$(id -u)" -ne 0 ] && TARGET_SU_REQUIRED="sudo"

        tar -xf ${QIMSDK_STAGING_DIR}/qimsdk_dev_artifacts_${VARIANT}.tar                          \
                -C ${QIMSDK_STAGING_DIR}                                                        || {
            print-red "FAILED: extract artifacts tar !!!"
            rm -rf ${QIMSDK_STAGING_DIR}
            return -1
        }

        ${TARGET_SU_REQUIRED} cp -a ${QIMSDK_STAGING_DIR}/usr /                                 || {
            print-red "Artifacts copy to device root failed !!!"
            rm -rf ${QIMSDK_STAGING_DIR}
            return -1
        }

        rm -rf ${QIMSDK_STAGING_DIR}
        echo "${VARIANT} artifacts copied directly to device root filesystem !!!"
        return 0
    }

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        # Root filesystem writes need elevated privileges over the ssh
        # transport (unprivileged remote user); adb shell is already root, so
        # no prefix is needed there. Mirrors builder-device-prepare in common.sh.
        local TRANSPORT
        builder-device-transport "${QIMSDK_DEVICE_ID}" TRANSPORT                                || {
            print-red "FAILED: builder-device-transport !!!"
            return -1
        }
        local TARGET_SU_REQUIRED=""
        [ "${TRANSPORT}" = "ssh" ] && TARGET_SU_REQUIRED="sudo -S"

        builder-device-command "${QIMSDK_DEVICE_ID}" "mkdir -p /tmp/qti/development"            && \
        builder-cmd "${QIMSDK_DEVICE_ID}" push                                                     \
                ${QIMSDK_STAGING_DIR}/qimsdk_dev_artifacts_${VARIANT}.tar                          \
                /tmp/qti/development/                                                           && \
        builder-device-command "${QIMSDK_DEVICE_ID}" "cd /tmp/qti/development                   && \
        tar -xf /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar                        && \
        ${TARGET_SU_REQUIRED} cp -a usr /"                                                      && \
        builder-device-command "${QIMSDK_DEVICE_ID}" "rm -rf /tmp/qti/development/usr"          || {
            print-red "Artifacts push failed !!!"

            builder-device-command "${QIMSDK_DEVICE_ID}" "rm -rf /tmp/qti/development/usr"
            builder-device-command "${QIMSDK_DEVICE_ID}"                                           \
                    "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"

            return -1
        }

        builder-device-command "${QIMSDK_DEVICE_ID}"                                               \
                "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"
        return 0
    )
    local rc=$?
    rm -rf ${QIMSDK_STAGING_DIR}
    [ ${rc} -ne 0 ] && return -1

    echo "${VARIANT} artifacts pushed to ${QIMSDK_DEVICE_ID} root filesystem !!!"
}

# Push release variant directly to the device's root filesystem.
#   $1 - (mandatory) path to target config json
function builder-push-artifacts-device() {
    builder-push-artifacts-device-variant "${1}" release
}

# Push debug variant directly to the device's root filesystem.
#   $1 - (mandatory) path to target config json
function builder-push-artifacts-device-dbg() {
    builder-push-artifacts-device-variant "${1}" debug
}

# Push artifacts into the deploy docker container running on the target
# device, named by Target_deploy_container_name in the config json file
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) artifacts variant - release or debug
function builder-push-artifacts-docker-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local VARIANT=${2}

    [ "${VARIANT}" == "release" ] || [ "${VARIANT}" == "debug" ] || {
        print-red "Wrong variant provided: supported variants: release, debug !!!"
        return -1
    }

    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID
    local QIMSDK_DEPLOY_CONTAINER_NAME

    builder-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                    \
            QIMSDK_CONTAINER_NAME QIMSDK_IMAGE_NAME                                             || {
        print-red "FAILED: builder-get-container-and-image-name !!!"
        return -1
    }

    builder-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                               || {
        print-red "FAILED: builder-get-device-id !!!"
        return -1
    }

    builder-get-deploy-container-name ${PATH_TO_CONFIG_JSON} QIMSDK_DEPLOY_CONTAINER_NAME       || {
        print-red "FAILED: builder-get-deploy-container-name !!!"
        return -1
    }

    [ -z "${QIMSDK_DEPLOY_CONTAINER_NAME}" ] && {
        print-red "QIMSDK_DEPLOY_CONTAINER_NAME is not set !!!"
        print-red "Please set Target_deploy_container_name in the config json file !!!"
        return -1
    }

    local QIMSDK_STAGING_DIR
    builder-fetch-saved-artifacts "${PATH_TO_CONFIG_JSON}" "${QIMSDK_CONTAINER_NAME}_builder"      \
            "${VARIANT}" QIMSDK_STAGING_DIR                                                     || \
            return -1

    [ "${QIMSDK_DEVICE_ID}" == "localhost" ] && {
        tar -xf ${QIMSDK_STAGING_DIR}/qimsdk_dev_artifacts_${VARIANT}.tar                          \
                -C ${QIMSDK_STAGING_DIR}                                                        || {
            print-red "FAILED: extract artifacts tar !!!"
            rm -rf ${QIMSDK_STAGING_DIR}
            return -1
        }

        docker cp ${QIMSDK_STAGING_DIR}/usr ${QIMSDK_DEPLOY_CONTAINER_NAME}:/                   || {
            print-red "Artifacts copy to ${QIMSDK_DEPLOY_CONTAINER_NAME} failed !!!"
            rm -rf ${QIMSDK_STAGING_DIR}
            return -1
        }

        rm -rf ${QIMSDK_STAGING_DIR}
        echo "${VARIANT} artifacts copied directly to ${QIMSDK_DEPLOY_CONTAINER_NAME} !!!"
        return 0
    }

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        builder-device-command "${QIMSDK_DEVICE_ID}" "mkdir -p /tmp/qti/development"            && \
        builder-cmd "${QIMSDK_DEVICE_ID}" push                                                     \
                ${QIMSDK_STAGING_DIR}/qimsdk_dev_artifacts_${VARIANT}.tar                          \
                /tmp/qti/development/                                                           && \
        builder-device-command "${QIMSDK_DEVICE_ID}" "cd /tmp/qti/development                   && \
        tar -xf /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar                        && \
        docker cp usr ${QIMSDK_DEPLOY_CONTAINER_NAME}:/"                                        && \
        builder-device-command "${QIMSDK_DEVICE_ID}" "rm -rf /tmp/qti/development/usr"          || {
            print-red "Artifacts push failed !!!"

            builder-device-command "${QIMSDK_DEVICE_ID}" "rm -rf /tmp/qti/development/usr"
            builder-device-command "${QIMSDK_DEVICE_ID}"                                           \
                    "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"

            return -1
        }

        builder-device-command "${QIMSDK_DEVICE_ID}"                                               \
                "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"
        return 0
    )
    local rc=$?
    rm -rf ${QIMSDK_STAGING_DIR}
    [ ${rc} -ne 0 ] && return -1

    echo "${VARIANT} artifacts pushed to ${QIMSDK_DEPLOY_CONTAINER_NAME}`
            ` on ${QIMSDK_DEVICE_ID} !!!"
}

# Push release variant into the deploy docker container running on the device.
#   $1 - (mandatory) path to target config json
function builder-push-artifacts-docker() {
    builder-push-artifacts-docker-variant "${1}" release
}

# Push debug variant into the deploy docker container running on the device.
#   $1 - (mandatory) path to target config json
function builder-push-artifacts-docker-dbg() {
    builder-push-artifacts-docker-variant "${1}" debug
}

# Docker images clean up on the system, on which function is invoked
function builder-docker-images-cleanup() {
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

# Abosulute path to the Docker source directory
QIMSDK_DOCKER_DIR="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"/.. && pwd )"
source ${QIMSDK_DOCKER_DIR}/scripts-dbg/common.sh

print-green "Docker build environment setup"
echo "=============================="
print-yellow "Debug dev Docker Commands"
echo        "==================="
print-green "builder-docker-build-image                                       <path-to-config-json>"
echo "    Build debug dev Docker image"
print-blue "builder-docker-run-container                                      <path-to-config-json>"
echo "    Run debug dev Docker container"
print-blue "builder-push-artifacts-device                                     <path-to-config-json>"
echo "    Push release variant directly to the device's root filesystem"
print-yellow "builder-push-artifacts-device-dbg                               <path-to-config-json>"
echo "    Push debug variant directly to the device's root filesystem"
print-blue "builder-push-artifacts-docker                                     <path-to-config-json>"
echo "    Push release variant into the deploy docker container running on the device"
print-yellow "builder-push-artifacts-docker-dbg                               <path-to-config-json>"
echo "    Push debug variant into the deploy docker container running on the device"
print-red "builder-docker-images-cleanup"
echo "    Docker images clean up on the system, on which function is invoked"
