#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# git am wrapper function
#   $1 - Path to patch file
function qimsdk-apply-patch() {
    local PATCH_FILE=${1}

    git am ${PATCH_FILE} || {
        echo "Failed to apply patch ${PATCH_FILE}!" && return -1
    }
}

# Wrapper function to apply qti patches to all needed opensource libs
function qimsdk-apply-patches() {
    qimsdk-apply-patches-wayland-protocols-1-33                                                 && \
            qimsdk-apply-patches-gst-plugins-base-1-24-9                                        && \
            qimsdk-apply-patches-gst-plugins-good-1-24-9                                        && \
            qimsdk-apply-patches-gst-plugins-bad-1-24-9                                         && \
            qimsdk-apply-patches-pulseaudio                                                     && \
            qimsdk-apply-patches-gstd
}

# Apply patches to wayland-protocols-1.33
function qimsdk-apply-patches-wayland-protocols-1-33() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33" ] && (
        local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/wayland-protocols-1.33"
        local WAYLAND_PATCHES=$(cat ${QIMSDK_RECIPES_JSON} | jq '.wayland[]' | tr -d '"')

        cd ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33

        for PATCH in ${WAYLAND_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH}
        done
    ) || {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33 !"
        return -1
    }
}

# Apply patches to gst-plugins-base-1.24.9
function qimsdk-apply-patches-gst-plugins-base-1-24-9() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.9" ] && (
        local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/gst-plugins-base-1.24.9"

        local PLUGINS_BASE_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.plugins_base[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.9

        for PATCH in ${PLUGINS_BASE_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH}
        done
    ) || {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.9 !"
        return -1
    }
}

# Apply patches to gst-plugins-good-1.24.9
function qimsdk-apply-patches-gst-plugins-good-1-24-9() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.9" ] && (
        local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/gst-plugins-good-1.24.9"

        local PLUGINS_GOOD_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.plugins_good[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.9

        for PATCH in ${PLUGINS_GOOD_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH}
        done
    ) || {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.9 !"
        return -1
    }
}

# Apply patches to gst-plugins-bad-1.24.9
function qimsdk-apply-patches-gst-plugins-bad-1-24-9() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.9" ] && (
        local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/gst-plugins-bad-1.24.9"

        local PLUGINS_BAD_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.plugins_bad[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.9

        for PATCH in ${PLUGINS_BAD_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH}
        done
    ) || {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.9 !"
        return -1
    }
}

# Apply patches to pulseaudio
function qimsdk-apply-patches-pulseaudio() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0" ] && (
        local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/pulseaudio"

        local PULSEAUDIO_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.pulseaudio[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0

        for PATCH in ${PULSEAUDIO_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH}
        done
    ) || {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0 !"
        return -1
    }
}

# Apply patches to gstd
function qimsdk-apply-patches-gstd() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/gstd-1.x" ] && (
        local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/gstd"

        local GSTD_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.gstd[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gstd-1.x

        for PATCH in ${GSTD_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH}
        done
    ) || {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gstd-1.x !"
        return -1
    }
}

# Copy the Tensorflow Lite's headers and dependent headers to the sysroot
function qimsdk-copy-tf-lite-headers-to-sysroot() {
    local SRC_DIR=${QIMSDK_TF_SRC_DIR}
    local DST_INC_DIR="/usr/include/"

    local PENDING_LIST_INIT=""

    local ML_TFLITE_ENGINE_CC="${QIMSDK_SRC_DIR}/`
        `gst-plugins-qti-oss/gst-plugin-mltflite/ml-tflite-engine-c-api.cc"
    local ML_TFLITE_ENGINE_H="${QIMSDK_SRC_DIR}/`
        `gst-plugins-qti-oss/gst-plugin-mltflite/ml-tflite-engine.h"

    local ML_TFLITE_ENGINE_CC_INCS=""

    ML_TFLITE_ENGINE_CC_INCS=$(
        cat ${ML_TFLITE_ENGINE_CC}                                                                 |
            grep "include.*.tensorflow"                                                            |
            cut -f2 -d "<" | rev | cut -f2 -d ">" | rev
    )

    PENDING_LIST_INIT+="${ML_TFLITE_ENGINE_CC_INCS}"
    PENDING_LIST_INIT+=$'\n'

    local ML_TFLITE_ENGINE_H_INCS=""

    ML_TFLITE_ENGINE_H_INCS=$(
        cat ${ML_TFLITE_ENGINE_H}                                                                  |
            grep "include.*.tensorflow"                                                            |
            cut -f2 -d "<" | rev | cut -f2 -d ">" | rev
    )

    PENDING_LIST_INIT+="${ML_TFLITE_ENGINE_H_INCS}"
    PENDING_LIST_INIT+=$'\n'

    local PENDING_LIST=()

    for i in ${PENDING_LIST_INIT}; do
        PENDING_LIST+=($i)
    done

    # Remove the header from pending_list if it doesn't exist
    for HEADER in "${!PENDING_LIST[@]}"; do
        [ ! -f "${QIMSDK_TF_SRC_DIR}/${PENDING_LIST[${HEADER}]}" ] && {
            unset 'PENDING_LIST[HEADER]'
        }
    done

    local PROCESSED_LIST=()

    while [ ${#PENDING_LIST[@]} -gt 0 ]; do
        # Get next file to be processed
        local H_FILE=${PENDING_LIST[0]}

        [ -z ${H_FILE} ] && {
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
