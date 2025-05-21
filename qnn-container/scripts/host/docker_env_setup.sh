#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
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
function qnn-tools-build-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QNN_BASE_IMAGE
    local QNN_TARGET_PLATFORM
    local QNN_CONTAINER_NAME
    local QNN_IMAGE_NAME
    local QNN_VERSION

    qnn-tools-parse-json ${PATH_TO_CONFIG_JSON} QNN_BASE_IMAGE QNN_TARGET_PLATFORM QNN_CONTAINER_NAME QNN_IMAGE_NAME QNN_VERSION

    local rc=$?
    [ $rc -ne 0 ] && print-red "parsing json failed !!!" && return -1

    local GROUP=$(getent group $(id -g ${USER}) | cut -d ':' -f 1)
    local QNN_ARG_BASE_DIR=/mnt/qnn

    local QNN_TOOLS_TMP_FOLDER=${QNN_DOCKER_BASE_DIR}/tmp

    DOCKER_BUILDKIT=1 docker build \
            --build-arg QNN_ARG_BASE_DIR=${QNN_ARG_BASE_DIR} \
            --build-arg QNN_ARG_VERSION=${QNN_VERSION} \
            --build-arg QNN_ARG_TARGET_PLATFORM=${QNN_TARGET_PLATFORM} \
            --build-arg QNN_ARG_BASE_IMAGE=${QNN_BASE_IMAGE} \
            --progress=plain --target qnn ${QNN_DOCKER_BASE_DIR} -t ${QNN_IMAGE_NAME}    || \
        {
            print-red "Build image failed !!!"
            rm -rf ${QNN_TOOLS_TMP_FOLDER}
            return -3
        }

    rm -rf ${QNN_TOOLS_TMP_FOLDER}

    print-green "Build image completed successfully !!!"
}

# Save selected device image
#   $1 - (mandatory) path to target config json
function qnn-tools-save-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QNN_CONTAINER_NAME
    local QNN_IMAGE_NAME
    local QNN_URL

    qnn-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} QNN_CONTAINER_NAME QNN_IMAGE_NAME
    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-container-and-image-name !!!"
        return $rc
    }

    qnn-get-url ${PATH_TO_CONFIG_JSON} QNN_URL
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-url !!!"
        return $rc
    }

    [ ! -d "${QNN_URL}" ]                               && {
        mkdir -p ${QNN_URL}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: mkdir -p ${QNN_URL} !!!"
            return ${rc}
        }
    }

    local FILE_NAME="${QNN_IMAGE_NAME}.tar"

    print-green "Saving qnn-tools-image : ${FILE_NAME}"
    docker save ${QNN_IMAGE_NAME}:latest -o ${QNN_URL}/${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device save image failed: docker save failed !!!"
        rm ${QNN_URL}/${FILE_NAME}

        return $rc
    }

    return 0
}


# Load selected device image
#   $1 - (mandatory) path to target config json
function qnn-tools-device-load-image() {
    local PATH_TO_CONFIG_JSON=$1
    local QNN_CONTAINER_NAME
    local QNN_IMAGE_NAME
    local QNN_DEVICE_ID

    qnn-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} QNN_CONTAINER_NAME QNN_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-container-and-image-name !!!"
        return $rc
    }

    qnn-get-device-id ${PATH_TO_CONFIG_JSON} QNN_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-device-id !!!"
        return $rc
    }

    local FILE_NAME="${QNN_IMAGE_NAME}.tar"

    (
        export ANDROID_SERIAL=${QNN_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            return -1
        }

        qnn-tools-device-command "mkdir -p /tmp/docker_images" ${QNN_DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qnn-tools-device-command !!!"
            rm ${FILE_NAME}

            return $rc
        }

        adb push ${FILE_NAME} /tmp/docker_images

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: adb push ${FILE_NAME} /tmp/docker_images !!!"
            return $rc
        }

        qnn-tools-device-command "docker load -i /tmp/docker_images/${FILE_NAME}" ${QNN_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return $rc
        }

        qnn-tools-device-command "rm /tmp/docker_images/${FILE_NAME}" ${QNN_DEVICE_ID}

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
function qnn-tools-device-run-container() {
    local PATH_TO_CONFIG_JSON=$1
    local QNN_CONTAINER_NAME
    local QNN_IMAGE_NAME
    local QNN_DEVICE_ID

    qnn-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} QNN_CONTAINER_NAME QNN_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-container-and-image-name !!!"
        return $rc
    }

    qnn-get-device-id ${PATH_TO_CONFIG_JSON} QNN_DEVICE_ID

    print-blue "Start the container : ${QNN_CONTAINER_NAME} on device: ${QNN_DEVICE_ID}"

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-device-id  !!!"
        return $rc
    }

    qnn-tools-device-command "docker run -it -d --device /dev/kgsl-3d0 \
            --device=/dev/dma_heap/system --device=/dev/fastrpc-cdsp-secure \
            -v /usr/lib/libCB.so:/usr/lib/libCB.so \
            -v /usr/lib/libOpenCL.so:/usr/lib/libOpenCL.so \
            -v /usr/lib/libOpenCL_adreno.so:/usr/lib/libOpenCL_adreno.so \
            -v /usr/lib/libadreno_utils.so.1:/usr/lib/libadreno_utils.so.1 \
            -v /usr/lib/libdmabufheap.so.0:/usr/lib/libdmabufheap.so.0 \
            -v /usr/lib/libgsl.so:/usr/lib/libgsl.so \
            -v /usr/lib/libllvm-qcom.so:/usr/lib/libllvm-qcom.so \
            -v /usr/lib/libvmmem.so.0:/usr/lib/libvmmem.so.0 \
            -v /usr/lib/libpropertyvault.so.0:/usr/lib/libpropertyvault.so.0 \
            -v /usr/lib/libatomic.so.1:/usr/lib/libatomic.so.1 \
            -v /usr/lib/libcdsprpc.so:/usr/lib/libcdsprpc.so \
            -v /usr/lib/dsp/cdsp/fastrpc_shell_unsigned_3:/usr/lib/dsp/cdsp/fastrpc_shell_unsigned_3 \
            -h ${QNN_CONTAINER_NAME} --name ${QNN_CONTAINER_NAME} ${QNN_CONTAINER_NAME}" ${QNN_DEVICE_ID}

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
function qnn-tools-device-rm-container() {
    local PATH_TO_CONFIG_JSON=$1
    local QNN_CONTAINER_NAME
    local QNN_IMAGE_NAME
    local QNN_DEVICE_ID

    qnn-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} QNN_CONTAINER_NAME QNN_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-container-and-image-name !!!"
        return $rc
    }

    qnn-get-device-id ${PATH_TO_CONFIG_JSON} QNN_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-device-id  !!!"
        return $rc
    }

    qnn-tools-device-command "docker rm ${QNN_CONTAINER_NAME}" ${QNN_DEVICE_ID}

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
function qnn-tools-device-start-container() {
    local PATH_TO_CONFIG_JSON=$1
    local QNN_CONTAINER_NAME
    local QNN_IMAGE_NAME
    local QNN_DEVICE_ID

    qnn-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} QNN_CONTAINER_NAME QNN_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-container-and-image-name !!!"
        return $rc
    }

    qnn-get-device-id ${PATH_TO_CONFIG_JSON} QNN_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-device-id  !!!"
        return $rc
    }

    qnn-tools-device-command "docker start ${QNN_CONTAINER_NAME}" ${QNN_DEVICE_ID}

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
function qnn-tools-device-stop-container() {
    local PATH_TO_CONFIG_JSON=$1
    local QNN_CONTAINER_NAME
    local QNN_IMAGE_NAME
    local QNN_DEVICE_ID

    qnn-tools-get-container-image-name ${PATH_TO_CONFIG_JSON} QNN_CONTAINER_NAME QNN_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-container-and-image-name !!!"
        return $rc
    }

    qnn-get-device-id ${PATH_TO_CONFIG_JSON} QNN_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-device-id  !!!"
        return $rc
    }

    qnn-tools-device-command "docker stop ${QNN_CONTAINER_NAME}" ${QNN_DEVICE_ID}

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
function qnn-tools-device-images-cleanup() {
    local PATH_TO_CONFIG_JSON=$1
    local QNN_DEVICE_ID

    qnn-get-device-id ${PATH_TO_CONFIG_JSON} QNN_DEVICE_ID

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-get-device-id  !!!"
        return $rc
    }

    local DEVICE_DOCKER_IMAGES=$(qnn-tools-device-command "docker images -f 'dangling=true' -q" ${QNN_DEVICE_ID})

    qnn-tools-device-command "docker rmi ${DEVICE_DOCKER_IMAGES}" ${QNN_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qnn-tools-device-command !!!"
        return $rc
    }

    print-green "Device docker images cleanup complete !!!"

    return 0
}


QNN_DOCKER_BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/../.. && pwd )"

source ${QNN_DOCKER_BASE_DIR}/scripts/host/common.sh

echo    "=================================="
echo -e "Docker environment setup ready !!!\n"

print-green "qnn-tools-build-image <targets/.json>"
echo "    Build qnn-tools docker image on host"
print-green "qnn-tools-device-run-container <targets/.json>"
echo "    Run tflite container on device"
print-green "qnn-tools-device-start-container <targets/.json>"
echo "    Once image is loaded, start the container"
print-blue "qnn-tools-save-image <targets/.json>"
echo "    Save selected docker image on host"
print-blue "qnn-tools-device-load-image <targets/.json>"
echo "    Load selected docker image image on device"
print-red "qnn-tools-device-rm-container <targets/.json>"
echo "    Remove the container from device"
print-red "qnn-tools-device-stop-container <targets/.json>"
echo "    Stop the container on device"
print-red "qnn-tools-device-images-cleanup <targets/.json>"
echo "    Remove docker images from device"
