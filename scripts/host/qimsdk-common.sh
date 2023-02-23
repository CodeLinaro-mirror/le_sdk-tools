#!/bin/bash

# Copyright (c) 2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Create essential directories
function qimsdk-create-dirs() {
    local rc

    local BASE_DIR="${BASE_DIR_LOCATION}/base_dir"
    local COMMON_DIR="common"

    export QIMSDK_BASE_DIR="${BASE_DIR_LOCATION}"
    export QIMSDK_DOWNLOAD_DIR=${BASE_DIR}/${COMMON_DIR}/download
    export QIMSDK_STATUS=${BASE_DIR}/${COMMON_DIR}/.status
    export QIMSDK_ESDK_BASE_DIR=${BASE_DIR}/esdk/${eSDK_NAME}
    export QIMSDK_SRC_DIR=${QIMSDK_ESDK_BASE_DIR}/src
    export QIMSDK_ESDK_DOWNLOAD_DIR=${QIMSDK_ESDK_BASE_DIR}/downloads
    export QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/sdk-tools/scripts/image
    export QIMSDK_WORK_DIR=${QIMSDK_BASE_DIR}/work

    mkdir -p ${QIMSDK_BASE_DIR}
    mkdir -p ${QIMSDK_DOWNLOAD_DIR}
    mkdir -p ${QIMSDK_STATUS}
    mkdir -p ${QIMSDK_ESDK_BASE_DIR}
    mkdir -p ${QIMSDK_SRC_DIR}
    mkdir -p ${QIMSDK_ESDK_DOWNLOAD_DIR}
    mkdir -p ${QIMSDK_WORK_DIR}

    return 0
}

# Install eSDK
function qimsdk-install-esdk() {
    local rc

    [ ! -f ${QIMSDK_STATUS}/${eSDK_NAME} ] && {
        echo "Installing ${eSDK_NAME} eSDK..."

        chmod a+r ${eSDK_PATH}/${eSDK_NAME}
        # umask 022
        ${eSDK_PATH}/${eSDK_NAME} -y -d ${QIMSDK_ESDK_BASE_DIR}/

        rc=$?
        [ $rc -ne 0 ] && {
            rm -rf ${QIMSDK_STATUS}/${eSDK_NAME}
            return $rc
        }

        touch ${QIMSDK_STATUS}/${eSDK_NAME}

    } || echo "The ${eSDK_NAME} eSDK: Already installed"

    export QIMSDK_SETUP="source ${QIMSDK_ESDK_BASE_DIR}/environment-setup-armv8a-oe-linux-sdllvm 2>/dev/null"

    return 0
}

# Uninstall eSDK
#   $1 - (mandatory) path to target config json
function qimsdk-uninstall-esdk() {
    local rc

    local PATH_TO_CONFIG_JSON=$1

    qimsdk-host-parse-json ${PATH_TO_CONFIG_JSON}
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-host-parse-json"
        return $rc
    }

    local BASE_DIR="${BASE_DIR_LOCATION}/base_dir"
    local COMMON_DIR="common"
    local eSDK_TO_REMOVE=${BASE_DIR}/esdk

    [ -f ${QIMSDK_STATUS}/${eSDK_NAME} ]                                                        && \
    [ -d ${eSDK_TO_REMOVE} ] && {

        pushd ${eSDK_TO_REMOVE} 1>/dev/null

        rm -rf ${eSDK_NAME}
        rm -rf ${QIMSDK_STATUS}/${eSDK_NAME}

        popd 1>/dev/null
    } || echo "eSDK ${eSDK_NAME}: Already removed"

    return 0
}

# Setup tflite
function qimsdk-setup-tflite() {
    [ "${QIMSDK_ESDK_TFLITE_FILENAME}" != "no-tflite-dev-archive-available" ]                   && \
        ( ln ${QIMSDK_ESDK_TFLITE_FILE} ${QIMSDK_ESDK_BASE_DIR}/downloads/ 2>/dev/null          || \
            rsync -a ${QIMSDK_ESDK_TFLITE_FILE} ${QIMSDK_ESDK_BASE_DIR}/downloads               || \
                {
                    print-red "Cannot add tflite dev archive to esdk base downloads folder !!!"
                    return -1
                }
        )                                                                                       || \
            {
                local QIMSDK_ESDK_TFLITE_FILENAME=no-tflite-dev-archive-available
                touch ${QIMSDK_ESDK_BASE_DIR}/${QIMSDK_ESDK_TFLITE_FILENAME}
            }

    return 0
}

# Remove tflite
function qimsdk-remove-tflite() {
    [ -f "${TFLITE_FILE}" ]                                                                     && \
        rm -rf ${QIMSDK_ESDK_BASE_DIR}/downloads/${QIMSDK_ESDK_TFLITE_FILE}

    return 0
}

# Setup acceleration engine
function qimsdk-setup-acceleration-engine() {

    [ -d "${ACCELERATION_ENGINE_DIR}" ]                                                         && \
        QIMSDK_ESDK_ACCELERATION_ENGINE_DIR=${QIMSDK_ESDK_ACCELERATION_ENGINE}            && \
            ( rsync -a ${ACCELERATION_ENGINE_DIR}/* ${QIMSDK_ESDK_BASE_DIR}/downloads/${QIMSDK_ESDK_ACCELERATION_ENGINE_DIR}/ || \
                {
                    print-red "Cannot add ${QIMSDK_ESDK_ACCELERATION_ENGINE} dir to esdk base folder !!!"
                    rm -rf ${QIMSDK_TMP_FOLDER}
                    return -1
                }
              rm -f ${QIMSDK_ESDK_BASE_DIR}/downloads/${QIMSDK_ESDK_ACCELERATION_ENGINE_DIR}/lib/aarch64-oe-linux-gcc8.2/libatomic.so.1
            )                                                                                   || \
                {
                    QIMSDK_ESDK_ACCELERATION_ENGINE_DIR=no-acceleration-engine-dir-available
                    touch ${QIMSDK_TMP_FOLDER}/${QIMSDK_ESDK_ACCELERATION_ENGINE_DIR}
                }

    return 0
}

# Remove acceleration engine
function qimsdk-remove-acceleration-engine() {
    [ -d "${ACCELERATION_ENGINE_DIR}" ]                                                         && \
        rm -rf ${QIMSDK_ESDK_BASE_DIR}/downloads/${QIMSDK_ESDK_ACCELERATION_ENGINE_DIR}

    return 0
}