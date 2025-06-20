#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

echo "Docker build environment setup"
echo "=============================="

# Parse json configuraiton
#   ${1} - (mandatory) path to container config json
#   ${2} - out base image name
#   ${3} - out sdk version
#   ${4} - out target platform
#   ${5} - out container name
#   ${6} - out container image name
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

    [ -z "${OUT_QML_TARGET_PLATFORM}" ] && {
        print-red "Target_platform attribute is not set in json file !!!"
        print-yellow "Target_platform attribute can be any of these: kalama, qcm6490, qcs6490, qcs8300, qrb5165 or qcs9100."

        return -4
    }

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return -5
    }

    return 0
}

# Build docker image based on Dockerfile in $QML_DOCKER_DIR directory
#   ${1} - (mandatory) path to target config json
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
        --build-arg QML_ARG_SDK_VER=${QML_SDK_VERS_STRING}                                         \
        --progress=plain --target qml ${QML_DOCKER_DIR} -t ${QML_IMAGE_NAME} --load

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

        qml-device-command "mkdir -p /var/docker_images" ${QML_DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qml-device-command !!!"
            rm ${FILE_NAME}

            return $rc
        }

        adb push ${FILE_NAME} /var/docker_images

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: adb push ${FILE_NAME} /var/docker_images !!!"
            rm ${FILE_NAME}

            return $rc
        }

        rm ${FILE_NAME}

        qml-device-command "docker load -i /var/docker_images/${FILE_NAME}" ${QML_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return $rc
        }

        qml-device-command "rm /var/docker_images/${FILE_NAME}" ${QML_DEVICE_ID}

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

    qml-device-command "docker run --rm -it -d --device=/dev/fastrpc-cdsp-secure                   \
            --device /dev/kgsl-3d0 --device /dev/dma_heap/system                                   \
            --device /dev/dma_heap/qcom,system                                                     \
            -v /usr/lib/libCB.so:/usr/lib/libCB.so                                                 \
            -v /usr/lib/libOpenCL.so:/usr/lib/libOpenCL.so                                         \
            -v /usr/lib/libOpenCL_adreno.so.1:/usr/lib/libOpenCL_adreno.so.1                       \
            -v /usr/lib/libdmabufheap.so.0:/usr/lib/libdmabufheap.so.0                             \
            -v /usr/lib/libgsl.so:/usr/lib/libgsl.so                                               \
            -v /usr/lib/libllvm-qcom.so:/usr/lib/libllvm-qcom.so                                   \
            -v /usr/lib/libpropertyvault.so.0:/usr/lib/libpropertyvault.so.0                       \
            -v /usr/lib/libadreno_utils.so:/usr/lib/libadreno_utils.so                             \
            -v /usr/lib/libcdsprpc.so:/usr/lib/libcdsprpc.so                                       \
            -h ${QML_CONTAINER_NAME} --name ${QML_CONTAINER_NAME} ${QML_IMAGE_NAME}"               \
        ${QML_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device run container failed !!!"
        return $rc
    }

    print-green "Device run container successful !!!"

    return 0
}

# Save docker image on the host
#   $1 - (mandatory) path to target config json
function qml-docker-host-save-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME
    local QML_URL

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    qml-get-url ${PATH_TO_CONFIG_JSON} QML_URL
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-url !!!"
        return $rc
    }

    [ ! -d "${QML_URL}" ]                               && {
        mkdir -p ${QML_URL}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: mkdir -p ${QML_URL} !!!"
            return ${rc}
        }
    }

    local FILE_NAME="${QML_IMAGE_NAME}.tar"

    docker save ${QML_IMAGE_NAME} -o ${QML_URL}/${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device save image failed: docker save failed !!!"
        rm ${QML_URL}/${FILE_NAME}

        return $rc
    }

    print-green "Device save image successful !!!"

    return 0
}

QML_DOCKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

source ${QML_DOCKER_DIR}/scripts/host/common.sh

print-green "qml-docker-build-image                                           <path-to-config-json>"
echo "    Build docker image based on Dockerfile in $QML_DOCKER_DIR"
print-blue "qml-docker-device-update-image                                    <path-to-config-json>"
echo "    Update selected device image to the device"
print-blue "qml-docker-device-run-container                                   <path-to-config-json>"
echo "    Run device container"
print-blue "qml-docker-host-save-image                                        <path-to-config-json>"
echo "    Save docker image on host"
