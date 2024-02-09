#!/bin/bash

# Copyright (c) 2023-2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Create essential directories
function qimsdk-create-dirs() {
    mkdir -p ${QIMSDK_SCRIPTS} ${QIMSDK_DOWNLOAD_DIR} ${QIMSDK_STATUS} ${QIMSDK_ESDK_BASE_DIR}     \
            ${QIMSDK_WORK_DIR} ${QIMSDK_ESDK_BASE_DIR}/downloads ${QIMSDK_BASE_DIR}/repo/src       \
            ${QIMSDK_BASE_DIR}/repo/poky ${QIMSDK_BASE_DIR}/repo/.repo/repo/hooks                  \
            ${QIMSDK_BASE_DIR}/repo/.repo/projects                                                 \
            ${QIMSDK_BASE_DIR}/repo/.repo/project-objects
}

# Install eSDK
function qimsdk-install-esdk() {
    local rc

    [ ! -f "${QIMSDK_STATUS}/${eSDK_NAME}" ] && {
        echo "Installing ${eSDK_NAME} eSDK..."

        chmod a+r ${eSDK_SHELL_FILE}
        # umask 022
        ${eSDK_SHELL_FILE} -y -d ${QIMSDK_ESDK_BASE_DIR}/

        rc=$?
        [ "${rc}" -ne 0 ] && {
            rm -rf ${QIMSDK_STATUS}/${eSDK_NAME}
            return ${rc}
        }

        touch ${QIMSDK_STATUS}/${eSDK_NAME}

    } || echo "The ${eSDK_NAME} eSDK: Already installed"

    return 0
}

# Uninstall eSDK
#   $1 - (mandatory) path to target config json
function qimsdk-uninstall-esdk() {
    local rc

    local PATH_TO_CONFIG_JSON=$1

    qimsdk-host-parse-json ${PATH_TO_CONFIG_JSON}
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-host-parse-json"
        return ${rc}
    }

    local BASE_DIR="${BASE_DIR_LOCATION}/base_dir"
    local COMMON_DIR="common"
    local eSDK_TO_REMOVE=${BASE_DIR}/esdk

    [ -f "${QIMSDK_STATUS}/${eSDK_NAME}" ]                                                      && \
    [ -d "${eSDK_TO_REMOVE}" ] && {

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
        { ln ${QIMSDK_ESDK_TFLITE_FILE} ${QIMSDK_ESDK_BASE_DIR}/downloads/ 2>/dev/null          || \
            rsync -a ${QIMSDK_ESDK_TFLITE_FILE} ${QIMSDK_ESDK_BASE_DIR}/downloads               || \
                {
                    print-red "Cannot add tflite dev archive to esdk base downloads directory !!!"
                    return -1
                }
        }                                                                                       || \
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

# Setup acceleration engines
function qimsdk-setup-acceleration-engines() {

    for ((i=0 ; i<${QIMSDK_ACCELERATION_ENGINE_COUNT} ; i++)); do
        local ACCELERATION_ENGINE=${QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES[${i}]}
        local ACCELERATION_ENGINE_DIR=${QIMSDK_ACCELERATION_ENGINE_PATHS[${i}]}
        local ENGINE_INDEX=$(( $i + 1 ))
        [ -d "${ACCELERATION_ENGINE_DIR}" ]                                                     && \
            QIMSDK_ESDK_ACCELERATION_ENGINE_DIR=${ACCELERATION_ENGINE}                          && \
                { rsync -a ${ACCELERATION_ENGINE_DIR}/* ${QIMSDK_ESDK_BASE_DIR}/downloads/${QIMSDK_ESDK_ACCELERATION_ENGINE_DIR}/ || \
                    {
                        print-red "Cannot add ${ACCELERATION_ENGINE} dir to downloads folder !!!"
                        return -1
                    }
                    rm -f ${QIMSDK_ESDK_BASE_DIR}/downloads/${QIMSDK_ESDK_ACCELERATION_ENGINE_DIR}/lib/aarch64-oe-linux-gcc8.2/libatomic.so.1
                }                                                                               || \
                    {
                        local ACCELERATION_ENGINE_TMP_PATH="no-acceleration-engine-${ENGINE_INDEX}-dir-available"
                        touch ${QIMSDK_ESDK_BASE_DIR}/downloads/${ACCELERATION_ENGINE_TMP_PATH}
                    }
    done

    return 0
}

# Remove acceleration engines
function qimsdk-remove-acceleration-engines() {
    for ((i=0 ; i<${QIMSDK_ACCELERATION_ENGINE_COUNT} ; i++)); do
        local ACCELERATION_ENGINE=${QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES[${i}]}
        local ACCELERATION_ENGINE_DIR=${QIMSDK_ACCELERATION_ENGINE_PATHS[${i}]}
        rm -rf ${QIMSDK_ESDK_BASE_DIR}/downloads/${ACCELERATION_ENGINE}
    done

    return 0
}

# Propagate scripts, src code and recipes to work folder
function qimsdk-fetch-scripts-src-poky() {
    mkdir -p ${QIMSDK_ESDK_BASE_DIR}/src
    local REPO_FILE_PATH
    if [ -d "${QIMSDK_TOOLS_DIR}/../.repo" ] ; then REPO_FILE_PATH="${QIMSDK_TOOLS_DIR}/.." ;      \
    else REPO_FILE_PATH="${QIMSDK_TOOLS_DIR}/../.."; fi
    rsync -a ${QIMSDK_TOOLS_DIR}/scripts/image/* ${QIMSDK_SCRIPTS}/                             && \
    rsync -a ${QIMSDK_TOOLS_DIR}/scripts/local ${QIMSDK_SCRIPTS}/                               && \
    rsync -a ${QIMSDK_TOOLS_DIR}/../src/* ${QIMSDK_BASE_DIR}/repo/src/                          && \
    rsync -a ${QIMSDK_TOOLS_DIR}/../poky/* ${QIMSDK_BASE_DIR}/repo/poky/                        && \
    rsync -a ${REPO_FILE_PATH}/.repo/projects/* ${QIMSDK_BASE_DIR}/repo/.repo/projects/         && \
    rsync -a ${REPO_FILE_PATH}/.repo/project-objects/*                                             \
	     ${QIMSDK_BASE_DIR}/repo/.repo/project-objects/                                     && \
    rsync -a ${REPO_FILE_PATH}/.repo/repo/hooks/* ${QIMSDK_BASE_DIR}/repo/.repo/repo/hooks/     && \
    ln -sf ${QIMSDK_BASE_DIR}/repo/src/* ${QIMSDK_ESDK_BASE_DIR}/src/                           && \
    ln -sf ${QIMSDK_BASE_DIR}/repo/poky ${QIMSDK_BASE_DIR}/poky
}
