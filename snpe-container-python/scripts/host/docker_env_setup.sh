#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

echo "Docker build environment setup"
echo "=============================="

# Parse json configuraiton
function qml-docker-parse-json() {
    local PATH_TO_CONFIG_JSON=$1
    local -n OUT_QML_BASE_IMAGE=$2
    local -n OUT_QML_SDK_VERSION=$3
    local -n OUT_QML_TARGET_PLATFORM=$4
    local -n OUT_QML_CONTAINER_NAME=$5
    local -n OUT_QML_IMAGE_NAME=$6

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QML_BASE_IMAGE=$(echo ${JSON_CONTENT} | jq '.Base_Image' | tr -d '"')
    [ -z "${QML_BASE_IMAGE}" ] && {
        print-red "Base_Image tag in json file must be set !!!"
        return -2
    }

    OUT_QML_SDK_VERSION=$(echo ${JSON_CONTENT} | jq '.SNPE_version' | tr -d '"')
    [ -z "${QML_SDK_VERSION}" ] && {
        print-red "SNPE_version tag in json file must be set !!!"
        return -3
    }

    OUT_QML_TARGET_PLATFORM=$(echo ${JSON_CONTENT} | jq '.Target_platform' | tr -d '"')
    [ -z "${QML_TARGET_PLATFORM}" ] && {
        print-red "Target_platform attribute is not set in json file !!!"
        print-yellow "Target_platform attribute can be any of these: kalama, qcm6490, qcs6490, qrb5165 or qcs9100 or klm."

        return -4
    }

    local ADDITIONAL_TAG_CONTAINER=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_container' | tr -d '"')

    [ ! -z "${ADDITIONAL_TAG_CONTAINER}" ] && {
        ADDITIONAL_TAG_CONTAINER="-${ADDITIONAL_TAG_CONTAINER}"
    }

    OUT_QML_CONTAINER_NAME="qml${ADDITIONAL_TAG_CONTAINER}"

    local ADDITIONAL_TAG_IMAGE=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_image' | tr -d '"')

    [ ! -z "${ADDITIONAL_TAG_IMAGE}" ] && {
        ADDITIONAL_TAG_IMAGE="-${ADDITIONAL_TAG_IMAGE}"
    }

    OUT_QML_IMAGE_NAME="qml${ADDITIONAL_TAG_IMAGE}"

    return 0
}

# Build docker image based on Dockerfile in $QML_DOCKER_DIR directory
#   $1 - (mandatory) path to target config json
function qml-docker-build-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_BASE_IMAGE
    local QML_SDK_VERSION
    local QML_TARGET_PLATFORM
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME

    qml-docker-parse-json ${PATH_TO_CONFIG_JSON}                                                   \
        QML_BASE_IMAGE                                                                             \
        QML_SDK_VERSION                                                                            \
        QML_TARGET_PLATFORM                                                                        \
        QML_CONTAINER_NAME                                                                         \
        QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-docker-parse-json !!!"

        return $rc
    }

    local QML_ARG_BASE_DIR=/mnt/qml

    DOCKER_BUILDKIT=1 docker build                                                                 \
        --build-arg QML_ARG_BASE_IMAGE=${QML_BASE_IMAGE}                                           \
        --build-arg QML_ARG_BASE_DIR=${QML_ARG_BASE_DIR}                                           \
        --build-arg QML_ARG_SDK_VERSION=${QML_SDK_VERSION}                                         \
        --build-arg QML_ARG_TARGET_PLATFORM=${QML_TARGET_PLATFORM}                                 \
        --progress=plain --target qml_arm64 ${QML_DOCKER_DIR} -t ${QML_IMAGE_NAME}

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
function qml-docker-device-update-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local QML_DEVICE_ID

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-device-id ${PATH_TO_CONFIG_JSON} QML_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-device-id !!!"
        return $rc
    }

    local FILE_NAME="${QML_IMAGE_NAME}.tar"

    docker save ${QML_IMAGE_NAME} -o ${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device load image failed: docker save failed !!!"
        rm ${FILE_NAME}

        return $rc
    }

    (
        export ANDROID_SERIAL=${QML_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qml-device-command "mkdir -p /var/persist/docker_images" ${QML_DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qml-device-command !!!"
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

        qml-device-command "docker load -i /var/persist/docker_images/${FILE_NAME}" ${QML_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return $rc
        }

        qml-device-command "rm /var/persist/docker_images/${FILE_NAME}" ${QML_DEVICE_ID}

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
function qml-docker-device-save-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local URL

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-url ${PATH_TO_CONFIG_JSON} URL

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-url !!!"
        return $rc
    }

    local FILE_NAME="${QML_IMAGE_NAME}.tar"

    docker save ${QML_IMAGE_NAME} -o ${FILE_NAME}

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
function qml-docker-device-load-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local URL
    local QML_DEVICE_ID

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-url ${PATH_TO_CONFIG_JSON} URL

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-url !!!"
        return $rc
    }

    qml-get-device-id ${PATH_TO_CONFIG_JSON} QML_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-device-id !!!"
        return $rc
    }

    local FILE_NAME="${QML_IMAGE_NAME}.tar"

    rsync -aP ${URL}/${FILE_NAME} ${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: rsync -aP ${URL}/${FILE_NAME} ${FILE_NAME}"
        rm ${FILE_NAME}

        return $rc
    }

    (
        export ANDROID_SERIAL=${QML_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qml-device-command "mkdir -p /var/persist/docker_images" ${QML_DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qml-device-command !!!"
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

        qml-device-command "docker load -i /var/persist/docker_images/${FILE_NAME}" ${QML_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return $rc
        }

        qml-device-command "rm /var/persist/docker_images/${FILE_NAME}" ${QML_DEVICE_ID}

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
function qml-docker-device-run-container() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local QML_DEVICE_ID

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-device-id ${PATH_TO_CONFIG_JSON} QML_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-device-id  !!!"
        return $rc
    }

    qml-device-command "docker run -it --device qualcomm.com/device=snpe_python \
            -h ${QML_CONTAINER_NAME} --name ${QML_CONTAINER_NAME} ${QML_IMAGE_NAME}" ${QML_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device run container failed !!!"
        return $rc
    }

    print-green "Device run container successful !!!"

    return 0
}

# Remove selected device container
#   $1 - (mandatory) path to target config json
function qml-docker-device-rm-container() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local QML_DEVICE_ID

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-device-id ${PATH_TO_CONFIG_JSON} QML_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-device-id  !!!"
        return $rc
    }

    qml-device-command "docker rm ${QML_CONTAINER_NAME}" ${QML_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device rm container failed !!!"
        return $rc
    }

    print-green "Device rm container successful !!!"

    return 0
}

# Start selected device container
#   $1 - (mandatory) path to target config json
function qml-docker-device-start-container() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local QML_DEVICE_ID

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-device-id ${PATH_TO_CONFIG_JSON} QML_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-device-id  !!!"
        return $rc
    }

    qml-device-command "docker start ${QML_CONTAINER_NAME}" ${QML_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device start container failed !!!"
        return $rc
    }

    print-green "Device start container successful !!!"

    return 0
}

# Stop selected device container
#   $1 - (mandatory) path to target config json
function qml-docker-device-stop-container() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local QML_DEVICE_ID

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-device-id ${PATH_TO_CONFIG_JSON} QML_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-device-id  !!!"
        return $rc
    }

    qml-device-command "docker stop ${QML_CONTAINER_NAME}" ${QML_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device stop container failed !!!"
        return $rc
    }

    print-green "Device stop container successful !!!"

    return 0
}

# Execute CMD in device container
#   $1 - (mandatory) path to target config json
#   $2 - (optional) command to execute
function qml-docker-device-command() {
    local PATH_TO_CONFIG_JSON=$1
    local CMD=$2
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local QML_DEVICE_ID

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME
    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-device-id ${PATH_TO_CONFIG_JSON} QML_DEVICE_ID
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-device-id  !!!"
        return $rc
    }

    qml-device-command "docker exec ${QML_CONTAINER_NAME} bash -c ${CMD}" ${QML_DEVICE_ID}
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-device-command !!!"
        return $rc
    }

    return 0
}

# Start shell in the docker container on the device
#   $1 - (mandatory) path to target config json
function qml-docker-device-shell() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local QML_DEVICE_ID

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME
    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-device-id ${PATH_TO_CONFIG_JSON} QML_DEVICE_ID
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-device-id  !!!"
        return $rc
    }

    adb -s ${QML_DEVICE_ID} shell -t "docker exec -it ${QML_CONTAINER_NAME} bash"
}

# Docker device images clean up
#   $1 - (mandatory) path to target config json
function qml-docker-device-images-cleanup() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_DEVICE_ID

    qml-get-device-id ${PATH_TO_CONFIG_JSON} QML_DEVICE_ID

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-device-id  !!!"
        return $rc
    }

    local DEVICE_DOCKER_IMAGES=$(qml-device-command "docker images -f 'dangling=true' -q" ${QML_DEVICE_ID})

    qml-device-command "docker rmi ${DEVICE_DOCKER_IMAGES}" ${QML_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-device-command !!!"
        return $rc
    }

    print-green "Device docker images cleanup complete !!!"

    return 0
}

# Docker host images clean up
function qml-docker-host-images-cleanup() {
    local HOST_DOCKER_IMAGES=$(docker images -f "dangling=true" -q)

    docker rmi ${HOST_DOCKER_IMAGES}

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: docker rmi of all !!!"
        return $rc
    }

    docker builder prune -a -f

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: docker builder prune -a -f !!!"
        return $rc
    }

    print-green "Host docker images cleanup complete !!!"

    return 0
}

QML_DOCKER_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/../.. && pwd )"

source ${QML_DOCKER_DIR}/scripts/host/common.sh

print-green "qml-docker-build-image                                           <path-to-config-json>"
echo "    Build docker image based on Dockerfile in $QML_DOCKER_DIR"
print-blue "qml-docker-device-update-image                                    <path-to-config-json>"
echo "    Update selected device image to the device"
print-blue "qml-docker-device-save-image                                      <path-to-config-json>"
echo "    Save selected device image"
print-blue "qml-docker-device-load-image                                      <path-to-config-json>"
echo "    Loads device image on the device"
print-blue "qml-docker-device-run-container                                   <path-to-config-json>"
echo "    Run device container"
print-blue "qml-docker-device-rm-container                                    <path-to-config-json>"
echo "    Remove device container"
print-blue "qml-docker-device-start-container                                 <path-to-config-json>"
echo "    Start device container"
print-blue "qml-docker-device-stop-container                                  <path-to-config-json>"
echo "    Stop device container"
print-blue "qml-docker-device-command                                   <path-to-config-json> <CMD>"
echo "    Execute CMD in device container"
print-blue "qml-docker-device-shell                                           <path-to-config-json>"
echo "    Start shell in the docker container on the device"
print-red "qml-docker-device-images-cleanup                                   <path-to-config-json>"
echo "    Docker device images clean up"
print-red "qml-docker-host-images-cleanup"
echo "    Docker host images clean up"
