#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

echo "Docker build environment setup"
echo "=============================="

# Parse json configuraiton
function qairt-docker-parse-json() {
    local PATH_TO_CONFIG_JSON=$1
    local -n OUT_QAIRT_SDK_VERSION=$2
    local -n OUT_QAIRT_CONTAINER_NAME=$3
    local -n OUT_QAIRT_IMAGE_NAME=$4

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QAIRT_SDK_VERSION=$(echo ${JSON_CONTENT} | jq '.QAIRT_version' | tr -d '"')
    [ -z "${QAIRT_SDK_VERSION}" ] && {
        print-red "SNPE_version tag in json file must be set !!!"
        return -3
    }

    local ADDITIONAL_TAG_CONTAINER=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_container' | tr -d '"')

    [ ! -z "${ADDITIONAL_TAG_CONTAINER}" ] && {
        ADDITIONAL_TAG_CONTAINER="-${ADDITIONAL_TAG_CONTAINER}"
    }

    OUT_QAIRT_CONTAINER_NAME="qairt${ADDITIONAL_TAG_CONTAINER}"

    local ADDITIONAL_TAG_IMAGE=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_image' | tr -d '"')

    [ ! -z "${ADDITIONAL_TAG_IMAGE}" ] && {
        ADDITIONAL_TAG_IMAGE="-${ADDITIONAL_TAG_IMAGE}"
    }

    OUT_QAIRT_IMAGE_NAME="qairt${ADDITIONAL_TAG_IMAGE}"

    return 0
}

# Build docker image based on Dockerfile in $QAIRT_DOCKER_DIR directory
#   $1 - (mandatory) path to target config json
function qairt-docker-build-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QAIRT_SDK_VERSION
    local QAIRT_CONTAINER_NAME
    local QAIRT_IMAGE_NAME

    qairt-docker-parse-json ${PATH_TO_CONFIG_JSON}                                                 \
        QAIRT_SDK_VERSION                                                                          \
        QAIRT_CONTAINER_NAME                                                                       \
        QAIRT_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-docker-parse-json !!!"

        return $rc
    }

    local QAIRT_BASE_DIR=/mnt/work

    DOCKER_BUILDKIT=1 docker build                                                                 \
        --build-arg QAIRT_ARG_SDK_VERSION=${QAIRT_SDK_VERSION}                                     \
        --progress=plain --target qairt_deploy_arm64 ${QAIRT_DOCKER_DIR} -t ${QAIRT_IMAGE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Build image failed !!!"

        return $rc
    }

    print-green "Build image completed successfully !!!"

    return 0
}

# Update selected device image to the device
#   $1 - (mandatory) path to target config json
function qairt-docker-device-update-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QAIRT_CONTAINER_NAME
    local QAIRT_IMAGE_NAME
    local QAIRT_DEVICE_ID

    qairt-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QAIRT_CONTAINER_NAME QAIRT_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-get-container-and-image-name !!!"
        return $rc
    }

    qairt-get-device-id ${PATH_TO_CONFIG_JSON} QAIRT_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-get-device-id !!!"
        return $rc
    }

    local FILE_NAME="${QAIRT_IMAGE_NAME}.tar"

    docker save ${QAIRT_IMAGE_NAME} -o ${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device load image failed: docker save failed !!!"
        rm ${FILE_NAME}

        return $rc
    }

    (
        export ANDROID_SERIAL=${QAIRT_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qairt-device-command "mkdir -p /var/persist/docker_images" ${QAIRT_DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qairt-device-command !!!"
            rm ${FILE_NAME}

            return $rc
        }

        adb push ${FILE_NAME} /var/persist/docker_images

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: adb push ${FILE_NAME} /var/persist/docker_images !!!"
            rm ${FILE_NAME}

            return $rc
        }

        rm ${FILE_NAME}

        qairt-device-command "docker load -i /var/persist/docker_images/${FILE_NAME}" ${QAIRT_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return $rc
        }

        qairt-device-command "rm /var/persist/docker_images/${FILE_NAME}" ${QAIRT_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device failed to remove ${FILE_NAME} !!!"
            return $rc
        }

        return 0
    )

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: Device update image !!!"
        return $rc
    }

    print-green "Device update image successful !!!"

    return 0
}

# Save selected device image
#   $1 - (mandatory) path to target config json
function qairt-docker-device-save-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QAIRT_CONTAINER_NAME
    local QAIRT_IMAGE_NAME
    local URL

    qairt-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QAIRT_CONTAINER_NAME QAIRT_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-get-container-and-image-name !!!"
        return $rc
    }

    qairt-get-url ${PATH_TO_CONFIG_JSON} URL

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-get-url !!!"
        return $rc
    }

    local FILE_NAME="${QAIRT_IMAGE_NAME}.tar"

    docker save ${QAIRT_IMAGE_NAME} -o ${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device load image failed: docker save failed !!!"
        rm ${FILE_NAME}

        return $rc
    }

    rsync -aP ${FILE_NAME} ${URL}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: rsync -aP ${FILE_NAME} ${URL}"
        rm ${FILE_NAME}

        return $rc
    }

    rm ${FILE_NAME}

    return 0
}

# Load selected device image
#   $1 - (mandatory) path to target config json
function qairt-docker-device-load-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QAIRT_CONTAINER_NAME
    local QAIRT_IMAGE_NAME
    local URL
    local QAIRT_DEVICE_ID

    qairt-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QAIRT_CONTAINER_NAME QAIRT_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-get-container-and-image-name !!!"
        return $rc
    }

    qairt-get-url ${PATH_TO_CONFIG_JSON} URL

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-get-url !!!"
        return $rc
    }

    qairt-get-device-id ${PATH_TO_CONFIG_JSON} QAIRT_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-get-device-id !!!"
        return $rc
    }

    local FILE_NAME="${QAIRT_IMAGE_NAME}.tar"

    rsync -aP ${URL}/${FILE_NAME} ${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: rsync -aP ${URL}/${FILE_NAME} ${FILE_NAME}"
        rm ${FILE_NAME}

        return $rc
    }

    (
        export ANDROID_SERIAL=${QAIRT_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qairt-device-command "mkdir -p /var/persist/docker_images" ${QAIRT_DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qairt-device-command !!!"
            rm ${FILE_NAME}

            return $rc
        }

        adb push ${FILE_NAME} /var/persist/docker_images

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: adb push ${FILE_NAME} /var/persist/docker_images !!!"
            rm ${FILE_NAME}

            return $rc
        }

        rm ${FILE_NAME}

        qairt-device-command "docker load -i /var/persist/docker_images/${FILE_NAME}" ${QAIRT_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return $rc
        }

        qairt-device-command "rm /var/persist/docker_images/${FILE_NAME}" ${QAIRT_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device failed to remove ${FILE_NAME} !!!"
            return $rc
        }

        return 0
    )

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: Device load image !!!"
        return $rc
    }

    print-green "Device load image successful !!!"

    return 0
}

# Run selected device container
#   $1 - (mandatory) path to target config json
function qairt-docker-device-run-container() {
    local PATH_TO_CONFIG_JSON=$1
    local QAIRT_CONTAINER_NAME
    local QAIRT_IMAGE_NAME
    local QAIRT_DEVICE_ID

    qairt-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QAIRT_CONTAINER_NAME QAIRT_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-get-container-and-image-name !!!"
        return $rc
    }

    qairt-get-device-id ${PATH_TO_CONFIG_JSON} QAIRT_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qairt-get-device-id  !!!"
        return $rc
    }

    qairt-device-command "docker run -it --device qualcomm.com/device=snpe_python \
            -h ${QAIRT_CONTAINER_NAME} --name ${QAIRT_CONTAINER_NAME} ${QAIRT_IMAGE_NAME}" ${QAIRT_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device run container failed !!!"
        return $rc
    }

    print-green "Device run container successful !!!"

    return 0
}

QAIRT_DOCKER_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"

source ${QAIRT_DOCKER_DIR}/scripts/common.sh

print-green "qairt-docker-build-image                                           <path-to-config-json>"
echo "    Build docker image based on Dockerfile in $QAIRT_DOCKER_DIR"
print-blue "qairt-docker-device-update-image                                    <path-to-config-json>"
echo "    Update selected device image to the device"
print-blue "qairt-docker-device-save-image                                      <path-to-config-json>"
echo "    Save selected device image"
print-blue "qairt-docker-device-load-image                                      <path-to-config-json>"
echo "    Loads device image on the device"
print-blue "qairt-docker-device-run-container                                   <path-to-config-json>"
echo "    Run device container"
