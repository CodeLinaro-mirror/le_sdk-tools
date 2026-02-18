#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# git am wrapper function
#   $1 - Path to patch file
function qimsdk-apply-patch() {
    local PATCH_FILE=${1}

    # Legal notices are present in QTI specific .patch files, so they could gain legal approval
    # They need to be removed to avoid trouble with git am
    # This is done by removing all leading comment lines from the patch file and then applying it
    sed -i '1,/^[^+#]/ { /^[+]*#/d; }' ${PATCH_FILE}                                            && \
            git am ${PATCH_FILE}                                                                || {
        echo "Failed to apply patch ${PATCH_FILE}!"
        return -1
    }
}

# Wrapper function to apply qti patches to all needed opensource libs
function qimsdk-apply-patches() {
    qimsdk-apply-patches-gst-plugins-base                                                       && \
            qimsdk-apply-patches-gst-plugins-good
}

# Apply patches to gst-plugins-base
function qimsdk-apply-patches-gst-plugins-base() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}" ]           && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/`
                `gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION} !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GST_META}/`
                `recipes-gst/gstreamer/gstreamer1.0-plugins-base/${GST_PLUGINS_BASE_VERSION}/"

        [ ! -d ${PATH_TO_PATCHES} ]                                                             && {
            print-red "gstreamer-plugins-base's patches NOT found in  ${PATH_TO_PATCHES} !!!"
            return -1
        }

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}

        for PATCH in ${PATH_TO_PATCHES}*.patch; do
            qimsdk-apply-patch ${PATCH} || return -1
        done
    )
}

# Apply patches to gst-plugins-good
function qimsdk-apply-patches-gst-plugins-good() {

    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}" ]           && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/`
                `gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION} !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GST_META}/`
                `recipes-gst/gstreamer/gstreamer1.0-plugins-good/${GST_PLUGINS_GOOD_VERSION}/"

        [ ! -d ${PATH_TO_PATCHES} ]                                                             && {
            print-red "gstreamer-plugins-good's patches NOT found in ${PATH_TO_PATCHES}!!!"
            return -1
        }

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}

        for PATCH in ${PATH_TO_PATCHES}*.patch; do
            qimsdk-apply-patch ${PATCH} || return -1
        done
    )
}

# Copy the Tensorflow Lite's headers and dependent headers to the sysroot
function qimsdk-copy-tf-lite-headers-to-sysroot() {
    local SRC_DIR=${QIMSDK_TF_SRC_DIR}
    local DST_INC_DIR="/usr/include/"

    local PENDING_LIST_INIT=""

    local ML_TFLITE_ENGINE_CC="${QIMSDK_SRC_DIR}/`
            `gst-plugins-imsdk/gst-plugin-mltflite/ml-tflite-engine-c-api.cc"
    local ML_TFLITE_ENGINE_H="${QIMSDK_SRC_DIR}/`
            `gst-plugins-imsdk/gst-plugin-mltflite/ml-tflite-engine.h"

    local ML_TFLITE_ENGINE_CC_INCS=""

    ML_TFLITE_ENGINE_CC_INCS=$(
        cat ${ML_TFLITE_ENGINE_CC} |grep "include.*.tensorflow" | cut -f2 -d "<" | rev |
                cut -f2 -d ">" | rev
    )

    PENDING_LIST_INIT+="${ML_TFLITE_ENGINE_CC_INCS}"
    PENDING_LIST_INIT+=$'\n'

    local ML_TFLITE_ENGINE_H_INCS=""

    ML_TFLITE_ENGINE_H_INCS=$(
        cat ${ML_TFLITE_ENGINE_H} | grep "include.*.tensorflow" | cut -f2 -d "<" | rev |
                cut -f2 -d ">" | rev
    )

    PENDING_LIST_INIT+="${ML_TFLITE_ENGINE_H_INCS}"
    PENDING_LIST_INIT+=$'\n'

    local PENDING_LIST=()

    for i in ${PENDING_LIST_INIT}; do
        PENDING_LIST+=($i)
    done

    # Remove the header from pending_list if it doesn't exist
    for HEADER in "${!PENDING_LIST[@]}"; do
        [ ! -f "${QIMSDK_TF_SRC_DIR}/${PENDING_LIST[${HEADER}]}" ]                              && {
            unset 'PENDING_LIST[HEADER]'
        }
    done

    local PROCESSED_LIST=()

    while [ ${#PENDING_LIST[@]} -gt 0 ]; do
        # Get next file to be processed
        local H_FILE=${PENDING_LIST[0]}

        [ -z ${H_FILE} ]                                                                        && {
            # Remove file from pending list
            PENDING_LIST=( "${PENDING_LIST[@]:1}" )
            continue
        }

        local H_FILE_PATH_tensorflow="${SRC_DIR}"
        local H_FILE_LIB=$(echo ${H_FILE} | cut -d '/' -f 1)
        local H_FILE_PATH=H_FILE_PATH_${H_FILE_LIB}
        local H_FILE_SRC="${!H_FILE_PATH}/${H_FILE}"

        # Find next set of included files
        local NEXT_H_FILES=(
            $(grep "#include" ${H_FILE_SRC} | grep -E 'tensorflow' | cut -d "\"" -f 2)
        )

        # Append file to processed list
        PROCESSED_LIST+=("${H_FILE}")

        # Remove file from pending list
        PENDING_LIST=( "${PENDING_LIST[@]:1}" )

        # Check whether next files needs to be appended to pending list
        for NEXT_H_FILE in "${NEXT_H_FILES[@]}"; do
            if [[ ! " ${PENDING_LIST[*]} " =~ " ${NEXT_H_FILE} " ]]; then
                if [[ ! " ${PROCESSED_LIST[*]} " =~ " ${NEXT_H_FILE} " ]]; then
                    PENDING_LIST+=( "${NEXT_H_FILE}" )
                fi
            fi
        done

        # Copy file from src to destination
        local H_FILE_SRC="${!H_FILE_PATH}/./${H_FILE}"

        rsync -a --relative "${H_FILE_SRC}" "${DST_INC_DIR}"
    done
}
