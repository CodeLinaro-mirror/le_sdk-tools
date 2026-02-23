#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Parse json configuraiton
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) variable to take container name value
#   $3 - (mandatory) variable to take image name value
#   $4 - (mandatory) variable to take camera-service sources of SP
#   $5 - (mandatory) variable to take Gstreamer sources of SP
#   $6 - (mandatory) variable to take Gstreamer meta of SP
#   $7 - (mandatory) variable to take QAIRT SDK version
function qimsdk-docker-parse-json() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_CONTAINER_NAME=${2}
    local -n OUT_QIMSDK_IMAGE_NAME=${3}
    local -n OUT_QIMSDK_CAMERA_SERVICE_SOURCES=${4}
    local -n OUT_QIMSDK_GST_SOURCES=${5}
    local -n OUT_QIMSDK_GST_META=${6}
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

    OUT_QIMSDK_GST_META=$(echo ${JSON_CONTENT} | jq '.IM_SDK_Meta_Dir' | tr -d '"')
    OUT_QIMSDK_GST_META=${OUT_QIMSDK_GST_META%/}

    qimsdk-expand-tilde OUT_QIMSDK_GST_META

    [ -d "${OUT_QIMSDK_GST_META}/.git" ]                                                        || \
            [ -d "${OUT_QIMSDK_GST_META}/recipes-gst/gstreamer" ]                               || {
        print-red "Please provide path to meta-qti-gst directory in config json!!!"
        print-red "Directory currently provided: ${IM_SDK_Meta_Dir}"
        return -1
    }

    OUT_QIMSDK_QAIRT_SDK_VERSION=$(echo ${JSON_CONTENT} |  jq '.QAIRT_SDK_version' | tr -d '"')

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
    local PATH_TO_CONFIG_JSON=${1}

    local -n QIMSDK_CONTAINER_NAME_PTR=${2}
    local -n QIMSDK_IMAGE_NAME_PTR=${3}
    local -n QIMSDK_TMP_FOLDER_PTR=${4}
    local -n DOCKER_IMAGE_PATH_PTR=${5}
    local -n QIMSDK_DEVICE_ID_PTR=${6}
    local -n QIMSDK_QAIRT_SDK_VERSION_PTR=${7}

    local QIMSDK_CAMERA_SERVICE_SOURCES
    local QIMSDK_GST_SOURCES
    local QIMSDK_GST_META

    qimsdk-docker-parse-json ${PATH_TO_CONFIG_JSON}                                                \
            QIMSDK_CONTAINER_NAME_PTR                                                              \
            QIMSDK_IMAGE_NAME_PTR                                                                  \
            QIMSDK_CAMERA_SERVICE_SOURCES                                                          \
            QIMSDK_GST_SOURCES                                                                     \
            QIMSDK_GST_META                                                                        \
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

    git -C ${QIMSDK_GST_META} branch | grep -q "imsdk.lnx.2.0.0"                                || {
        print-red "ERROR: ${QIMSDK_GST_META} does not contain local branch: imsdk.lnx.2.0.0 !!!"
        return -1
    }

    rsync -aL ${QIMSDK_CAMERA_SERVICE_SOURCES}/ ${QIMSDK_TMP_FOLDER_PTR}/camera-service         && \
            rsync -aL ${QIMSDK_GST_SOURCES}/ ${QIMSDK_TMP_FOLDER_PTR}/gst-plugins-imsdk         && \
            rsync -aL ${QIMSDK_GST_META}/ ${QIMSDK_TMP_FOLDER_PTR}/meta-qti-gst
}

# Qimsdk build qimsdk-debian deploy docker image
#   $1 - (mandatory) image name
function qimsdk-docker-build-qimsdk-debian-deploy-image() {
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
        sed -E "s/--from=qimsdk-build/--from=${IMAGE_NAME}-debian/g"                               \
                ${DOCKERFILE} > ${DOCKERFILE}.work_deploy                                       || {
            rm -f ${DOCKERFILE}.work_deploy
            print-red "Modify Dockerfile to import artifacts from debug build container failed!"
            return -1
        }

        DOCKER_BUILDKIT=1 docker build                                                             \
                --progress=plain --target qimsdk-deploy                                            \
                ${PATH_TO_QIMSDK_DEBIAN_DOCKERFILE} -t ${IMAGE_NAME}-debian-deploy                 \
                -f ${DOCKERFILE}.work_deploy                                                    || {
            rm -f ${DOCKERFILE}.work_deploy
            print-red "Build ${IMAGE_NAME}-debian-deploy image failed !!!"
            return -1
        }

        rm -f ${DOCKERFILE}.work_deploy
    )
}

# Qimsdk build qimsdk-debian docker image
#   $1 - (mandatory) image name
function qimsdk-docker-build-qimsdk-debian-image() {
    local IMAGE_NAME=${1}
    local QIMSDK_QAIRT_SDK_VERSION=${2}

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

        # Modify Dockerfile to use debug container as base
        sed -E                                                                                     \
            "s|^(FROM[[:space:]]+)debian:trixie-slim([[:space:]]+AS[[:space:]]+qimsdk-build)|\1${IMAGE_NAME}\2|"  \
            ${DOCKERFILE} > ${DOCKERFILE}.work

        DOCKER_BUILDKIT=1 docker build                                                             \
                --build-arg QIMSDK_ARG_QNP_VERSION=${QIMSDK_QAIRT_SDK_VERSION}                     \
                --progress=plain --target qimsdk-build                                             \
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
function qimsdk-docker-build-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME

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

    qimsdk-docker-build-qimsdk-debian-deploy-image ${QIMSDK_IMAGE_NAME}                         || {
        print-red "FAILED: qimsdk-docker-build-qimsdk-debian-deploy-image !!!"
        return -1
    }

    print-green "Build image completed successfully !!!"

    return 0
}

# Build dbg dev docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-docker-build-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH
    local QIMSDK_DEVICE_ID
    local QIMSDK_QAIRT_SDK_VERSION

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

    DOCKER_BUILDKIT=1 docker build                                                                 \
            --build-arg QIMSDK_ARG_DOCKER_IMAGE_PATH=${DOCKER_IMAGE_PATH}                          \
            --build-arg QIMSDK_ARG_DEVICE_ID=${QIMSDK_DEVICE_ID}                                   \
            --build-arg QIMSDK_ARG_CONTAINER_NAME=${QIMSDK_CONTAINER_NAME}                         \
            --progress=plain --target qimsdk_dbg_image -f Dockerfile.dbg                           \
            ${QIMSDK_DOCKER_DIR} -t ${QIMSDK_IMAGE_NAME}                                        || {
        print-red "Build image failed !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return -1
    }

    qimsdk-docker-build-qimsdk-debian-image ${QIMSDK_IMAGE_NAME} ${QIMSDK_QAIRT_SDK_VERSION}    || {
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
function qimsdk-docker-device-update-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

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

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    docker save ${QIMSDK_IMAGE_NAME}-debian-deploy:latest -o ${FILE_NAME}                       || {
        print-red "Device load image failed: docker save failed !!!"
        rm ${FILE_NAME}
        return -1
    }

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ]                                                                && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qimsdk-device-command "mkdir -p /tmp/data/docker_images" ${QIMSDK_DEVICE_ID}            || {
            print-red "FAILED: qimsdk-device-command !!!"
            rm ${FILE_NAME}

            return -1
        }

        adb push ${FILE_NAME} /tmp/data/docker_images                                           || {
            print-red "FAILED: adb push ${FILE_NAME} /tmp/data/docker_images !!!"
            rm ${FILE_NAME}

            return -1
        }

        rm ${FILE_NAME}

        qimsdk-device-command "docker load -i /tmp/data/docker_images/${FILE_NAME}"                \
                ${QIMSDK_DEVICE_ID}                                                             || {
            print-red "Device load image failed: docker load failed !!!"
            return -1
        }

        qimsdk-device-command "rm /tmp/data/docker_images/${FILE_NAME}" ${QIMSDK_DEVICE_ID}     || {
            print-red "Device failed to remove ${FILE_NAME} !!!"
            return -1
        }
    )                                                                                           || {
        print-red "FAILED: Device update image !!!"
        return -1
    }

    print-green "Device update image successful !!!"

    return 0
}

# Save selected device image
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-save-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH

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

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    local COMMON_PATH=""

    [ -d ${DOCKER_IMAGE_PATH} ]                                                                 && {
        COMMON_PATH=${DOCKER_IMAGE_PATH}
    }                                                                                           || {
        COMMON_PATH=$(mktemp -d)
    }

    docker save ${QIMSDK_IMAGE_NAME}-debian-deploy:latest -o ${COMMON_PATH}/${FILE_NAME}        || {
        print-red "Device save image failed: docker save failed !!!"
        rm -f ${COMMON_PATH}/${FILE_NAME}

        return -1
    }

    qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/${FILE_NAME} ${DOCKER_IMAGE_PATH}            || {
        print-red "FAILED: qimsdk-sync-to-remote-and-clean"
        rm -f ${COMMON_PATH}/${FILE_NAME}

        return -1
    }

    for DEVICE_JSON in ${QIMSDK_DOCKER_DIR}/targets/target_*.json; do

        local SUFFIX_NAME="$(basename "${DEVICE_JSON%.json}")"
        SUFFIX_NAME="${SUFFIX_NAME#target_}"

        qimsdk-generate-docker-run-cmd ${DEVICE_JSON}                                              \
                ${COMMON_PATH}/docker_run_${SUFFIX_NAME}.sh                                        \
                ${QIMSDK_CONTAINER_NAME}                                                           \
                ${QIMSDK_IMAGE_NAME}-debian-deploy                                              || {
            print-red "Generate ${COMMON_PATH}/docker_run_${SUFFIX_NAME}.sh file failed !!!"
            rm -f ${COMMON_PATH}/docker_run_${SUFFIX_NAME}.sh

            return -1
        }

        qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/docker_run_${SUFFIX_NAME}.sh                \
                ${DOCKER_IMAGE_PATH}                                                            || {
            print-red "FAILED: qimsdk-sync-to-remote-and-clean"
            rm -f ${COMMON_PATH}/docker_run_${SUFFIX_NAME}.sh

            return -1
        }

        qimsdk-generate-docker-compose-cdi-yaml ${DEVICE_JSON}                                     \
                ${COMMON_PATH}/docker-compose-cdi-${SUFFIX_NAME}.yml                               \
                ${QIMSDK_CONTAINER_NAME}                                                           \
                ${QIMSDK_IMAGE_NAME}-debian-deploy                                              || {
            print-red "Generate qimsdk docker compose CDI file failed !!!"
            rm -f ${COMMON_PATH}/docker-compose-cdi-${SUFFIX_NAME}.yml

            return -1
        }

        qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/docker-compose-cdi-${SUFFIX_NAME}.yml       \
                ${DOCKER_IMAGE_PATH}                                                            || {
            print-red "FAILED: qimsdk-sync-to-remote-and-clean"
            rm -f ${COMMON_PATH}/docker-compose-cdi-${SUFFIX_NAME}.yml

            return -1
        }
    done

    print-green "Device save image successful !!!"

    return 0
}

# Load selected device image
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-load-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH
    local QIMSDK_DEVICE_ID

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

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    local LOCAL_DOCKER_IMAGE="${DOCKER_IMAGE_PATH}/${FILE_NAME}"

    [ ! -d ${DOCKER_IMAGE_PATH} ]                                                               && {
        local TMP_DOCKER_IMAGE_PATH=$(mktemp -d)

        rsync -aP ${DOCKER_IMAGE_PATH}/${FILE_NAME} ${TMP_DOCKER_IMAGE_PATH}/${FILE_NAME}       || {
            print-red "FAILED: rsync -aP ${DOCKER_IMAGE_PATH}/${FILE_NAME}                         \
                    ${TMP_DOCKER_IMAGE_PATH}/${FILE_NAME}"

            return -1
        }

        LOCAL_DOCKER_IMAGE="${TMP_DOCKER_IMAGE_PATH}/${FILE_NAME}"
    }

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ]                                                                && {
            print-red "Android serial is not set !!!"
            qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

            return -1
        }

        qimsdk-device-command "mkdir -p /tmp/data/docker_images" ${QIMSDK_DEVICE_ID}            || {
            print-red "FAILED: qimsdk-device-command !!!"
            qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

            return -1
        }

        adb push ${LOCAL_DOCKER_IMAGE} /tmp/data/docker_images                                  || {
            print-red "FAILED: adb push ${LOCAL_DOCKER_IMAGE}                                      \
                    /tmp/data/docker_images !!!"

            qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}
            return -1
        }

        qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

        qimsdk-device-command "docker load -i /tmp/data/docker_images/${FILE_NAME}"                \
                ${QIMSDK_DEVICE_ID}                                                             || {
            print-red "Device load image failed: docker load failed !!!"
            return -1
        }

        qimsdk-device-command "rm /tmp/data/docker_images/${FILE_NAME}" ${QIMSDK_DEVICE_ID}     || {
            print-red "Device failed to remove ${FILE_NAME} !!!"
            return -1
        }

        return 0
    )                                                                                           || {
        print-red "FAILED: Device load image !!!"
        return -1
    }

    print-green "Device load image successful !!!"

    return 0
}

# Run dbg dev container
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-docker-run-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    local DEVELOPMENT_MAP

    qimsdk-get-map-for-dbg-container ${PATH_TO_CONFIG_JSON}                                        \
            DEVELOPMENT_MAP

    local USB_DEVICE=""
    [ -d /dev/bus/usbd ] && USB_DEVICE="--device /dev/bus/usb"

    docker run -it -d --net host -h ${QIMSDK_CONTAINER_NAME}_dbg                                   \
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
function qimsdk-device-docker-run-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                   || {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return -1
    }

    docker run -it -d --net host -h ${QIMSDK_CONTAINER_NAME} --user qimsdk                         \
            --name ${QIMSDK_CONTAINER_NAME} ${QIMSDK_IMAGE_NAME}-debian-deploy bash             || {
        print-red "Run device container failed on pc emulator !!!"
        return -1
    }

    # Propagate ssh and gitconfig to container
    docker exec --user root ${QIMSDK_CONTAINER_NAME} mkdir /root/.ssh                           || {
        print-red "docker mkdir ~/.ssh failed !!!"
        return -1
    }

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp ${f} ${QIMSDK_CONTAINER_NAME}:/root/.ssh/${BASE_NAME}                     || {
                print-red "Propagating .ssh/ to docker failed !!!"
                return -1
            }
        done
        docker exec --user root ${QIMSDK_CONTAINER_NAME} chown -R root:root /root/.ssh          || {
            print-red "Propagating .ssh/ to docker failed !!!"
            return -1
        }
    fi

    print-green "Run device container successful on pc emulator !!!"

    return 0
}

# Run selected device container in cdi mode
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-run-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

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
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        local MACHINE=$(adb shell "cat /sys/devices/soc0/machine" | tr -d '\r')                 || {
            print-red "FAILED: adb shell "cat /sys/devices/soc0/machine"  !!!"
            return -1
        }

        local MEDIA_DIRS=("labels" "media" "models")

        for idx in ${!MEDIA_DIRS[@]}; do
            qimsdk-device-command "mkdir -m 777 -p /etc/${MEDIA_DIRS[$idx]}"                    || {
                print-red "FAILED: /etc/${MEDIA_DIRS[$idx]} can not be created in device !!!"
                return -1
            }
        done

        local TARGET_PLATFORM=""

        local TMP_RUN_CMD_DIR=$(mktemp -d)

        for DEVICE_JSON in ${QIMSDK_DOCKER_DIR}/targets/target_*.json; do

            local SUFFIX_NAME="$(basename "${DEVICE_JSON%.json}")"
            SUFFIX_NAME="${SUFFIX_NAME#target_}"

            qimsdk-generate-docker-run-cmd ${DEVICE_JSON}                                          \
                    ${TMP_RUN_CMD_DIR}/docker_run_${SUFFIX_NAME}.sh                                \
                    ${QIMSDK_CONTAINER_NAME}                                                       \
                    ${QIMSDK_IMAGE_NAME}-debian-deploy                                          || {
                print-red "Generate ${TMP_RUN_CMD_DIR}/docker_run_${SUFFIX_NAME}.sh `
                    `file failed !!!"
                rm -rf ${TMP_RUN_CMD_DIR}

                return -1
            }

            declare -A SOC_LIST=$(cat ${DEVICE_JSON} | jq '.Soc[]' | tr -d '"')

            for SOC in ${SOC_LIST[@]}; do
                [[ ${MACHINE} == ${SOC} ]]                                                      && {
                    TARGET_PLATFORM="${SUFFIX_NAME}"
                    # Break out of both loops
                    break 2
                }
            done
        done

        [ -z ${TARGET_PLATFORM} ]                                                               && {
            print-red "Target platform is not set !!!"
            return -1
        }

        adb push ${TMP_RUN_CMD_DIR}/docker_run_${TARGET_PLATFORM}.sh /tmp/                      && \
        qimsdk-device-command "source /tmp/docker_run_${TARGET_PLATFORM}.sh"                    || {
            rm -rf ${TMP_RUN_CMD_DIR}
            qimsdk-device-command "rm -rf /tmp/docker_run_${TARGET_PLATFORM}.sh"
            echo "qimsdk-docker-device-run-container failed !!!"
            return -1
        }

        rm -rf ${TMP_RUN_CMD_DIR}
        qimsdk-device-command "rm -rf /tmp/docker_run_${TARGET_PLATFORM}.sh"
    )                                                                                           || {
        print-red "Device run container failed !!!"
        return -1
    }

    print-green "Device run container successful !!!"

    return 0
}

# Remove selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-rm-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

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

    qimsdk-device-command "docker rm ${QIMSDK_CONTAINER_NAME}" ${QIMSDK_DEVICE_ID}              || {
        print-red "Device rm container failed !!!"
        return -1
    }

    print-green "Device rm container successful !!!"

    return 0
}

# Start selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-start-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

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

    qimsdk-device-command "docker start ${QIMSDK_CONTAINER_NAME}" ${QIMSDK_DEVICE_ID}           || {
        print-red "Device start container failed !!!"
        return -1
    }

    print-green "Device start container successful !!!"

    return 0
}

# Stop selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-stop-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

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

    qimsdk-device-command "docker stop ${QIMSDK_CONTAINER_NAME}" ${QIMSDK_DEVICE_ID}            || {
        print-red "Device stop container failed !!!"
        return -1
    }

    print-green "Device stop container successful !!!"

    return 0
}

# Execute CMD in device container
#   $1 - (mandatory) path to target config json
#   $2 - (optional) command to execute
function qimsdk-docker-device-command() {
    local PATH_TO_CONFIG_JSON=${1}
    local CMD=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

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

    qimsdk-device-command "docker exec ${QIMSDK_CONTAINER_NAME} bash -c ${CMD}"                    \
            ${QIMSDK_DEVICE_ID}                                                                 || {
        print-red "FAILED: qimsdk-device-command !!!"
        return -1
    }

    return 0
}

# Start shell in the docker container on the device
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-shell() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

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

    adb -s ${QIMSDK_DEVICE_ID} shell -t "docker exec -it ${QIMSDK_CONTAINER_NAME} bash"
}

# Docker device images clean up
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-images-cleanup() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_DEVICE_ID

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID                                || {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return -1
    }

    local DEVICE_DOCKER_IMAGES=$(
        qimsdk-device-command "docker images -f 'dangling=true' -q" ${QIMSDK_DEVICE_ID}
    )

    qimsdk-device-command "docker rmi ${DEVICE_DOCKER_IMAGES}" ${QIMSDK_DEVICE_ID}              || {
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
    local PATH_TO_CONFIG_JSON=${1}
    local VARIANT=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID
    local DOCKER_IMAGE_PATH

    [ "${VARIANT}" == "release" ] || [ "${VARIANT}" == "debug" ]                                || {
        print-red "Failed to load ${VARIANT} packages !!!"
        print-red "Wrong variant provided: supported variants: release, debug !!!"
        return -1
    }

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

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
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ]                                                                && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        rsync -aP ${DOCKER_IMAGE_PATH}/qimsdk_dev_artifacts_${VARIANT}.tar .                    && \
                qimsdk-device-command "mkdir -p /tmp/qti/development" ${QIMSDK_DEVICE_ID}       && \
                adb push qimsdk_dev_artifacts_${VARIANT}.tar /tmp/qti/development/              && \
                qimsdk-device-command "cd /tmp/qti/development && `
                        `tar -xf /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar && `
                        `docker cp usr ${QIMSDK_CONTAINER_NAME}:/" ${QIMSDK_DEVICE_ID}          && \
                qimsdk-device-command "rm -rf /tmp/qti/development/usr"                            \
                        ${QIMSDK_DEVICE_ID}                                                     || {
            print-red "Artifacts load failed !!!"

            qimsdk-device-command "rm -rf /tmp/qti/development/usr"
            qimsdk-device-command "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"

            rm -f qimsdk_dev_artifacts_${VARIANT}.tar

            return -1
        }

        qimsdk-device-command "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"
        rm -f qimsdk_dev_artifacts_${VARIANT}.tar
    )

    echo "dbg ${VARIANT} artifacts loaded from ${DOCKER_IMAGE_PATH}"
}

# Load release artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-load-artifacts() {
    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-dbg-load-artifacts-variant ${PATH_TO_CONFIG_JSON} release
}

# Load debug artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dbg-load-artifacts-dbg() {
    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-dbg-load-artifacts-variant ${PATH_TO_CONFIG_JSON} debug
}

QIMSDK_DOCKER_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"

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
