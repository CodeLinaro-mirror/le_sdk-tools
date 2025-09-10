#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# git am wrapper function
#   $1 - Path to patch file
function qimsdk-apply-patch() {
    local PATCH_FILE=${1}

    sed -i '1,/^[^+#]/ { /^[+]*#/d; }' ${PATCH_FILE}                                            && \
            git am ${PATCH_FILE}                                                                || {
        echo "Failed to apply patch ${PATCH_FILE}!"
        return -1
    }
}

# Wrapper function to apply qti patches to all needed opensource libs
function qimsdk-apply-patches() {
    qimsdk-apply-patches-wayland-protocols-1-33                                                 && \
            qimsdk-apply-patches-gstreamer-1-24-2                                               && \
            qimsdk-apply-patches-gst-plugins-base-1-24-2                                        && \
            qimsdk-apply-patches-gst-plugins-good-1-24-2                                        && \
            qimsdk-apply-patches-gst-plugins-bad-1-24-2                                         && \
            qimsdk-apply-patches-pulseaudio                                                     && \
            qimsdk-apply-patches-gstd
}

# Apply patches to gstreamer-1-24-2
function qimsdk-apply-patches-gstreamer-1-24-2() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2" ] && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2 !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GSTREAMER_PATCHES}"

        local GSTREAMER_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.gstreamer[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2

        for PATCH in ${GSTREAMER_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH} || return -1
        done
    )
}

# Apply patches to wayland-protocols-1.33
function qimsdk-apply-patches-wayland-protocols-1-33() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33" ] && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33 !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_WAYLAND_PATCHES}"

        local WAYLAND_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.wayland[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33

        for PATCH in ${WAYLAND_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH} || return -1
        done
    )
}

# Apply patches to gst-plugins-base-1.24.2
function qimsdk-apply-patches-gst-plugins-base-1-24-2() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2" ] && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2 !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GST_PLUGINS_BASE_PATCHES}"

        local PLUGINS_BASE_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.plugins_base[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2

        for PATCH in ${PLUGINS_BASE_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH} || return -1
        done
    )
}

# Apply patches to gst-plugins-good-1.24.2
function qimsdk-apply-patches-gst-plugins-good-1-24-2() {

    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2" ] && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2 !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_PATCHES}"

        local PLUGINS_GOOD_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.plugins_good[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2

        for PATCH in ${PLUGINS_GOOD_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH} || return -1
        done
    )
}

# Apply patches to gst-plugins-bad-1.24.2
function qimsdk-apply-patches-gst-plugins-bad-1-24-2() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2" ] && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2 !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GST_PLUGINS_BAD_PATCHES}"

        local PLUGINS_BAD_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.plugins_bad[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2

        for PATCH in ${PLUGINS_BAD_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH} || return -1
        done
    )
}

# Apply patches to pulseaudio
function qimsdk-apply-patches-pulseaudio() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0" ] && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0 !"
        return -1
    }

    (
        local PULSEAUDIO_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.pulseaudio[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0

        for PATCH in ${PULSEAUDIO_PATCHES}; do
            qimsdk-apply-patch ${QIMSDK_PATH_TO_PULSEAUDIO}/${PATCH}                            || \
            qimsdk-apply-patch ${QIMSDK_PATH_TO_PULSEAUDIO_META}/${PATCH}                       || \
                return -1
        done
    )
}

# Apply patches to gstd
function qimsdk-apply-patches-gstd() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gstd-1.x" ] && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gstd-1.x !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GSTD_PATCHES}"

        local GSTD_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.gstd[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gstd-1.x

        for PATCH in ${GSTD_PATCHES}; do
            qimsdk-apply-patch ${PATH_TO_PATCHES}/${PATCH} || return -1
        done
    )
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

# Propagate packages and sources to proper locations from temporary directory of qimsdk docker
function qimsdk-propagate-packages-and-sources() {
    # Add private headers needed compiletime from headers dir
    rsync -a ${QIMSDK_TMP_DIR}/headers/usr/* /usr/ || return -1

    # Setup pkg-config dir
    rsync -a ${QIMSDK_TMP_DIR}/lib/pkgconfig/*.pc ${QIMSDK_PKGCONFIG_DIR}/ || return -1

    mkdir -p ${QIMSDK_SRC_DIR}/le-services
    mkdir -p ${QIMSDK_SRC_DIR}/solutions-microservices

    # Add Source Code
    rsync -a ${QIMSDK_TMP_DIR}/le-services/* ${QIMSDK_SRC_DIR}/le-services/                     && \
    rsync -a ${QIMSDK_TMP_DIR}/solutions-microservices/microservices/qimsdk/*                      \
            ${QIMSDK_SRC_DIR}/solutions-microservices/ || return -1

    mkdir -p ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss

    # Add Source Code
    rsync -a ${QIMSDK_TMP_DIR}/gst-plugins-qti-oss/* ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/     && \
    rsync -a ${QIMSDK_TMP_DIR}/build_plugins.sh ${QIMSDK_SCRIPTS}/ || return -1

    # Add json file with content of cmake flags
    mkdir -p ${QIMSDK_RECIPES_PATCHES_DIR}
    rsync -a ${QIMSDK_TMP_DIR}/recipes_patches.json ${QIMSDK_RECIPES_PATCHES_DIR}/ || return -1

    return 0
}

# Propagate paths to patch files
function qimsdk-propagate-path-to-patches() {

    QIMSDK_PATH_TO_GSTREAMER_PATCHES="${QIMSDK_PATH_TO_GST_META}/`
        `recipes-gst/gstreamer/gstreamer1.0/1.24/"

    [ ! -d ${QIMSDK_PATH_TO_GSTREAMER_PATCHES} ]                                                && {
        print-red "gstreamer's patches NOT found !!!"
        return -1
    }

    QIMSDK_PATH_TO_GST_PLUGINS_BASE_PATCHES="${QIMSDK_PATH_TO_GST_META}/`
        `recipes-gst/gstreamer/gstreamer1.0-plugins-base/1.24/"

    [ ! -d ${QIMSDK_PATH_TO_GST_PLUGINS_BASE_PATCHES} ]                                         && {
        print-red "gstreamer-plugins-base's patches NOT found !!!"
        return -1
    }

    QIMSDK_PATH_TO_GST_PLUGINS_GOOD_PATCHES="${QIMSDK_PATH_TO_GST_META}/`
        `recipes-gst/gstreamer/gstreamer1.0-plugins-good/1.24.2/"

    [ ! -d ${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_PATCHES} ]                                         && {
        print-red "gstreamer-plugins-good's patches NOT found !!!"
        return -1
    }

    QIMSDK_PATH_TO_GST_PLUGINS_BAD_PATCHES="${QIMSDK_PATH_TO_GST_META}/`
        `recipes-gst/gstreamer/gstreamer1.0-plugins-bad/1.24.2/"

    [ ! -d ${QIMSDK_PATH_TO_GST_PLUGINS_BAD_PATCHES} ]                                          && {
        print-red "gstreamer-plugins-bad's patches NOT found !!!"
        return -1
    }

    QIMSDK_PATH_TO_GSTD_PATCHES="${QIMSDK_PATH_TO_GST_META}/recipes-gst/gstreamer/gstd/"

    [ ! -d ${QIMSDK_PATH_TO_GSTD_PATCHES} ]                                                     && {
        print-red "gstd's patches NOT found !!!"
        return -1
    }

    QIMSDK_PATH_TO_WAYLAND_PATCHES="${QIMSDK_TMP_DIR}/`
            `meta-qcom-hwe/recipes-graphics/wayland/wayland-protocols/"
    [ ! -d ${QIMSDK_PATH_TO_WAYLAND_PATCHES} ]                                                  && {
        print-red "wayland-protocol's patches NOT found !!!"
        return -1
    }

    QIMSDK_PATH_TO_PULSEAUDIO_META="${QIMSDK_TMP_DIR}/`
            `meta-qcom-hwe/recipes-multimedia/audio/pulseaudio/"
    [ -d "${QIMSDK_PATH_TO_PULSEAUDIO_META}" ]                                                  || {
        echo "Cannot find path to pulseaudio meta !!!"
        return -1
    }

    QIMSDK_PATH_TO_PULSEAUDIO="${QIMSDK_TMP_DIR}/`
            `poky/meta/recipes-multimedia/pulseaudio/pulseaudio"
    [ -d "${QIMSDK_PATH_TO_PULSEAUDIO}" ]                                                       || {
        echo "Cannot find path to pulseaudio !!!"
        return -1
    }

    return 0
}

# Invoke Recipe Parser script
function qimsdk-invoke-recipe-parser() {
    local PYTHON_ARG_FOR_LAYERS="${QIMSDK_TMP_DIR}"
    local PYTHON_ARG_FOR_CODE_GENERATOR="BuildCodeGenerator"

    local QIMSDK_SUPPORTED_TARGETS_COUNT=${#QIMSDK_SUPPORTED_TARGETS[@]}

    for ((INDEX=0 ; INDEX<${QIMSDK_SUPPORTED_TARGETS_COUNT} ; INDEX++)); do

        # Skipping ubuntu targets
        [[ "${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}" == *_ubun ]]                                 && {
            continue
        }

        python3 ${QIMSDK_TOOLS}/RecipeParser.py                                                    \
                -l ${PYTHON_ARG_FOR_LAYERS}                                                        \
                -m ${QIMSDK_PATH_TO_GST_META}                                                      \
                -p ${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}                                           \
                -t ${QIMSDK_TMP_DIR}                                                               \
                ${PYTHON_ARG_FOR_CODE_GENERATOR}                                                || {
            print-red "Python Parser returns error, mode ${PYTHON_ARG_FOR_CODE_GENERATOR} !!!"
            return -1
        }

        python3 ${QIMSDK_TOOLS}/RecipeParser.py                                                    \
                -l ${PYTHON_ARG_FOR_LAYERS}                                                        \
                -m ${QIMSDK_PATH_TO_GST_META}                                                      \
                -p ${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}                                           \
                -t ${QIMSDK_TMP_DIR}                                                               \
                RuntimeFlagsGenerator                                                           || {
            print-red "Python Parser returns error, mode RuntimeFlagsGenerator !!!"
            return -1
        }

        python3 ${QIMSDK_TOOLS}/RecipeParser.py                                                    \
                -l ${PYTHON_ARG_FOR_LAYERS}                                                        \
                -m ${QIMSDK_PATH_TO_GST_META}                                                      \
                -p ${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}                                           \
                -t ${QIMSDK_TMP_DIR}                                                               \
                -v "1.24.2"                                                                        \
                BBPatchParser                                                                   || {
            print-red "Python Parser returns error, mode BBPatchParser !!!"
            return -1
        }

        diff ${QIMSDK_TMP_DIR}/${QIMSDK_SUPPORTED_TARGETS[0]}_recipes_patches.json                 \
            ${QIMSDK_TMP_DIR}/${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}_recipes_patches.json        || {
            print-yellow "Patches of supported targets differ !!!"
        }

        diff ${QIMSDK_TMP_DIR}/${QIMSDK_SUPPORTED_TARGETS[0]}_build_plugins.sh                     \
            ${QIMSDK_TMP_DIR}/${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}_build_plugins.sh            || {
            print-yellow "Build flags of supported targets differ !!!"
        }
    done

    mv ${QIMSDK_TMP_DIR}/${QIMSDK_SUPPORTED_TARGETS[0]}_build_plugins.sh                           \
        ${QIMSDK_TMP_DIR}/build_plugins.sh

    mv ${QIMSDK_TMP_DIR}/${QIMSDK_SUPPORTED_TARGETS[0]}_recipes_patches.json                       \
        ${QIMSDK_TMP_DIR}/recipes_patches.json

    return 0
}
