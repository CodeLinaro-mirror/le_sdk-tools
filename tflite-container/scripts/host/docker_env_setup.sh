#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

echo "Docker build environment setup"
echo "=============================="

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

# Build specified docker image as first argument
#   $1 - (mandatory) path to target config json
function tflite-tools-host-build-image() {
    local PATH_TO_CONFIG_JSON=$1
    local IMAGE
    local DEVICE_OS
    local ADDITIONAL_TAG
    local TFLITE_VERSION
    local CONTAINER_NAME
    local TFLITE_RSYNC_DST
    local SDK_FULL_PATH
    local SDK_ENV_SETUP_SCRIPT
    local HEXAGON_DELEGATE
    local GPU_DELEGATE
    local XNNPACK_DELEGATE
    local TFLITE_DEVICE_INSTALL_PREFIX
    local TFLITE_TARGET_SYS
    local TFLITE_ARG_BASE_IMAGE

    tflite-tools-host-parse-json ${PATH_TO_CONFIG_JSON} IMAGE DEVICE_OS ADDITIONAL_TAG TFLITE_VERSION CONTAINER_NAME TFLITE_RSYNC_DST SDK_FULL_PATH SDK_ENV_SETUP_SCRIPT HEXAGON_DELEGATE GPU_DELEGATE XNNPACK_DELEGATE TFLITE_DEVICE_INSTALL_PREFIX TFLITE_TARGET_SYS

    local rc=$?
    [ $rc -ne 0 ] && print-red "parsing json failed !!!" && return -1

    local TFLITE_TOOLS_TMP_FOLDER=${TF_LITE_TOOLS_DOCKER_FOLDER}/tmp

    rm -rf ${TFLITE_TOOLS_TMP_FOLDER}
    mkdir -p ${TFLITE_TOOLS_TMP_FOLDER}

    [ "${SDK_FULL_PATH}" == "null/null" ] || {
        ln ${SDK_FULL_PATH} ${TFLITE_TOOLS_TMP_FOLDER}/sdk.sh 2>/dev/null                                           || \
            rsync -a ${SDK_FULL_PATH} ${TFLITE_TOOLS_TMP_FOLDER}/sdk.sh                                             || \
            {
                echo "rsync -a ${SDK_FULL_PATH} ${TFLITE_TOOLS_TMP_FOLDER}/sdk.sh"
                print-red "Cannot add sdk sh file to tmp folder !!!"
                rm -rf ${TFLITE_TOOLS_TMP_FOLDER}
                return -2
            }
    }

    local GROUP=$(getent group $(id -g ${USER}) | cut -d ':' -f 1)

    local TFLITE_ARG_BASE_DIR=/mnt/tflite

    local TFLITE_NUM_CPU
    tflite-tools-get-number-of-threads TFLITE_NUM_CPU

    DOCKER_BUILDKIT=1 docker build                                                                                     \
            --build-arg TFLITE_ARG_BASE_DIR=${TFLITE_ARG_BASE_DIR}                                                     \
            --build-arg TFLITE_ARG_OS=${DEVICE_OS}                                                                     \
            --build-arg TFLITE_ARG_VERSION=${TFLITE_VERSION}                                                           \
            --build-arg TFLITE_ARG_RSYNC_DST=${TFLITE_RSYNC_DST}                                                       \
            --build-arg TFLITE_ARG_SDK_ENV_SETUP_SCRIPT=${SDK_ENV_SETUP_SCRIPT}                                        \
            --build-arg TFLITE_ARG_HEXAGON=${HEXAGON_DELEGATE}                                                         \
            --build-arg TFLITE_ARG_GPU=${GPU_DELEGATE}                                                                 \
            --build-arg TFLITE_ARG_XNNPACK=${XNNPACK_DELEGATE}                                                         \
            --build-arg TFLITE_ARG_NUM_CPU=${TFLITE_NUM_CPU}                                                         \
            --build-arg TFLITE_ARG_DEVICE_INSTALL_PREFIX=${TFLITE_DEVICE_INSTALL_PREFIX}                              \
            --build-arg TFLITE_ARG_TARGET_SYS=${TFLITE_TARGET_SYS}                              \
            --progress=plain --target ${IMAGE} ${TF_LITE_TOOLS_DOCKER_FOLDER} -t ${CONTAINER_NAME}                  || \
        {
            print-red "Build image failed !!!"
            rm -rf ${TFLITE_TOOLS_TMP_FOLDER}
            return -3
        }

    rm -rf ${TFLITE_TOOLS_TMP_FOLDER}

    print-green "Build image completed successfully !!!"
}

# Save selected device image
#   $1 - (mandatory) path to target config json
function tflite-tools-host-save-image() {
    local PATH_TO_CONFIG_JSON=$1
    local TFLITE_CONTAINER_NAME
    local TFLITE_IMAGE_NAME

    tflite-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} TFLITE_CONTAINER_NAME TFLITE_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-container-and-image-name !!!"
        return $rc
    }

    local FILE_NAME="${TFLITE_IMAGE_NAME}.tar"

    print-green "Saving tflite-tools-image : ${FILE_NAME}"
    docker save ${TFLITE_CONTAINER_NAME} -o ${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device load image failed: docker save failed !!!"
        rm ${FILE_NAME}

        return $rc
    }

    return 0
}


# Load selected device image
#   $1 - (mandatory) path to target config json
function tflite-tools-device-load-image() {
    local PATH_TO_CONFIG_JSON=$1
    local TFLITE_CONTAINER_NAME
    local TFLITE_IMAGE_NAME
    local URL
    local TFLITE_DEVICE_ID

    tflite-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} TFLITE_CONTAINER_NAME TFLITE_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-container-and-image-name !!!"
        return $rc
    }

    tflite-get-device-id ${PATH_TO_CONFIG_JSON} TFLITE_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-device-id !!!"
        return $rc
    }

    local FILE_NAME="${TFLITE_IMAGE_NAME}.tar"

    (
        export ANDROID_SERIAL=${TFLITE_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            return -1
        }

        tflite-tools-device-command "mkdir -p /data/docker_images" ${TFLITE_DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: tflite-tools-device-command !!!"
            rm ${FILE_NAME}

            return $rc
        }

        adb push ${FILE_NAME} /data/docker_images

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: adb push ${FILE_NAME} /data/docker_images !!!"
            return $rc
        }

        tflite-tools-device-command "docker load -i /data/docker_images/${FILE_NAME}" ${TFLITE_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return $rc
        }

        tflite-tools-device-command "rm /data/docker_images/${FILE_NAME}" ${TFLITE_DEVICE_ID}

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

# Docker run container based on compiled docker image
#   $1 - (mandatory) path to target config json
function tflite-tools-device-run-container() {
    local PATH_TO_CONFIG_JSON=$1
    local TFLITE_CONTAINER_NAME
    local TFLITE_IMAGE_NAME
    local TFLITE_DEVICE_ID

    tflite-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} TFLITE_CONTAINER_NAME TFLITE_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-container-and-image-name !!!"
        return $rc
    }

    tflite-get-device-id ${PATH_TO_CONFIG_JSON} TFLITE_DEVICE_ID

    print-blue "Start the container : ${TFLITE_CONTAINER_NAME} on device: ${TFLITE_DEVICE_ID}"

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-device-id  !!!"
        return $rc
    }

    tflite-tools-device-command "docker run -it -d --device /dev/kgsl-3d0 \
            -v /usr/lib/libCB.so:/usr/lib/libCB.so \
            -v /usr/lib/libOpenCL.so:/usr/lib/libOpenCL.so \
            -v /usr/lib/libOpenCL_adreno.so:/usr/lib/libOpenCL_adreno.so \
            -v /usr/lib/libcdsprpc.so:/usr/lib/libcdsprpc.so \
            -v /usr/lib/libcutils.so.0:/usr/lib/libcutils.so.0 \
            -v /usr/lib/libadreno_utils.so:/usr/lib/libadreno_utils.so \
            -v /usr/lib/libdmabufheap.so.0:/usr/lib/libdmabufheap.so.0 \
            -v /usr/lib/libglib-2.0.so.0:/usr/lib/libglib-2.0.so.0 \
            -v /usr/lib/libgsl.so:/usr/lib/libgsl.so \
            -v /usr/lib/libgthread-2.0.so.0:/usr/lib/libgthread-2.0.so.0 \
            -v /usr/lib/libion.so.0:/usr/lib/libion.so.0 \
            -v /usr/lib/libllvm-qcom.so:/usr/lib/libllvm-qcom.so \
            -v /usr/lib/liblog.so.0:/usr/lib/liblog.so.0 \
            -v /usr/lib/libpcre.so.1:/usr/lib/libpcre.so.1 \
            -v /usr/lib/libsync.so.0:/usr/lib/libsync.so.0 \
            -v /usr/lib/libvmmem.so.0:/usr/lib/libvmmem.so.0 \
            -v /usr/lib/libpropertyvault.so.0:/usr/lib/libpropertyvault.so.0 \
            -h ${TFLITE_CONTAINER_NAME} --name ${TFLITE_CONTAINER_NAME} ${TFLITE_CONTAINER_NAME}" ${TFLITE_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device run container failed !!!"
        return $rc
    }

    print-green "Docker run successful !!!"
    print-green "docker attach to ${CONTAINER_NAME} !!!"

    return 0
}

# Remove specified docker container as first argument
#   $1 - (mandatory) path to target config json
function tflite-tools-device-rm-container() {
    local PATH_TO_CONFIG_JSON=$1
    local TFLITE_CONTAINER_NAME
    local TFLITE_IMAGE_NAME
    local TFLITE_DEVICE_ID

    tflite-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} TFLITE_CONTAINER_NAME TFLITE_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-container-and-image-name !!!"
        return $rc
    }

    tflite-get-device-id ${PATH_TO_CONFIG_JSON} TFLITE_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-device-id  !!!"
        return $rc
    }

    tflite-tools-device-command "docker rm ${TFLITE_CONTAINER_NAME}" ${TFLITE_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device rm container failed !!!"
        return $rc
    }

    print-green "Device rm container successful !!!"

    return 0
}

# Start specified docker container as first argument
#   $1 - (mandatory) path to target config json
function tflite-tools-device-start-container() {
    local PATH_TO_CONFIG_JSON=$1
    local TFLITE_CONTAINER_NAME
    local TFLITE_IMAGE_NAME
    local TFLITE_DEVICE_ID

    tflite-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} TFLITE_CONTAINER_NAME TFLITE_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-container-and-image-name !!!"
        return $rc
    }

    tflite-get-device-id ${PATH_TO_CONFIG_JSON} TFLITE_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-device-id  !!!"
        return $rc
    }

    tflite-tools-device-command "docker start ${TFLITE_CONTAINER_NAME}" ${TFLITE_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device start container failed !!!"
        return $rc
    }

    print-green "Device start container successful !!!"

    return 0
}

# Stop specified docker container as first argument
#   $1 - (mandatory) path to target config json
function tflite-tools-device-stop-container() {
    local PATH_TO_CONFIG_JSON=$1
    local TFLITE_CONTAINER_NAME
    local TFLITE_IMAGE_NAME
    local TFLITE_DEVICE_ID

    tflite-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} TFLITE_CONTAINER_NAME TFLITE_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-container-and-image-name !!!"
        return $rc
    }

    tflite-get-device-id ${PATH_TO_CONFIG_JSON} TFLITE_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-device-id  !!!"
        return $rc
    }

    tflite-tools-device-command "docker stop ${TFLITE_CONTAINER_NAME}" ${TFLITE_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device stop container failed !!!"
        return $rc
    }

    print-green "Device stop container successful !!!"

    return 0
}

# Docker device images clean up
#   $1 - (mandatory) path to target config json
function tflite-tools-device-images-cleanup() {
    local PATH_TO_CONFIG_JSON=$1
    local TFLITE_DEVICE_ID

    tflite-get-device-id ${PATH_TO_CONFIG_JSON} TFLITE_DEVICE_ID

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-get-device-id  !!!"
        return $rc
    }

    local DEVICE_DOCKER_IMAGES=$(tflite-tools-device-command "docker images -f 'dangling=true' -q" ${TFLITE_DEVICE_ID})

    tflite-tools-device-command "docker rmi ${DEVICE_DOCKER_IMAGES}" ${TFLITE_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-tools-device-command !!!"
        return $rc
    }

    print-green "Device docker images cleanup complete !!!"

    return 0
}


TF_LITE_TOOLS_DOCKER_FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/../.. && pwd )"

source ${TF_LITE_TOOLS_DOCKER_FOLDER}/scripts/host/common.sh

echo    "=================================="
echo -e "Docker environment setup ready !!!\n"

print-green "tflite-tools-host-build-image                                          <targets/.json>"
echo "    Build tflite-tools docker image on host"
print-green "tflite-tools-device-run-container                                          <targets/.json>"
echo "    Run tflite container on device"
print-green "tflite-tools-device-start-container                                        <targets/.json>"
echo "    ONce image is loaded, start the container"
print-blue "tflite-tools-host-save-image                                        <targets/.json>"
echo "    Save selected docker image on host"
print-blue "tflite-tools-device-load-image                                        <targets/.json>"
echo "    Load selected docker image image on device"
print-red "tflite-tools-device-rm-container                                        <targets/.json>"
echo "    Remove the container from device"
print-red "tflite-tools-device-stop-container                                        <targets/.json>"
echo "    Stop the container on device"
print-red "tflite-tools-device-images-cleanup                                        <targets/.json>"
echo "    Remove docker images from device"
