#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Parse json configuraiton
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) variable to take container name value
#   $3 - (mandatory) variable to take image name value
#   $4 - (mandatory) variable to take Gstreamer sources of SP
#   $5 - (mandatory) variable to take Gstreamer meta of SP
#   $6 - (mandatory) variable to take path to microservices
#   $7 - (mandatory) variable to take path to le services source
#   $8 - (mandatory) variable to take path to eSDK
#   $9 - (mandatory) variable to take supported targets
function qimsdk-docker-parse-json() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_CONTAINER_NAME=${2}
    local -n OUT_QIMSDK_IMAGE_NAME=${3}
    local -n OUT_QIMSDK_GST_SOURCES=${4}
    local -n OUT_QIMSDK_GST_META=${5}
    local -n OUT_QIMSDK_PATH_MICROSERVICES=${6}
    local -n OUT_QIMSDK_LE_SERVICES_SOURCES=${7}
    local -n OUT_QIMSDK_PATH_TO_eSDK_DIR=${8}
    local -n OUT_QIMSDK_SUPPORTED_TARGETS=${9}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local ADDITIONAL_TAG_CONTAINER=$(
        echo ${JSON_CONTENT} |  jq '.Additional_tag_container' | tr -d '"'
    )

    [ ! -z "${ADDITIONAL_TAG_CONTAINER}" ] && {
        ADDITIONAL_TAG_CONTAINER="-${ADDITIONAL_TAG_CONTAINER}"
    }

    OUT_QIMSDK_CONTAINER_NAME="qimsdk${ADDITIONAL_TAG_CONTAINER}"

    local ADDITIONAL_TAG_IMAGE=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_image' | tr -d '"')

    [ ! -z "${ADDITIONAL_TAG_IMAGE}" ] && {
        ADDITIONAL_TAG_IMAGE="-${ADDITIONAL_TAG_IMAGE}"
    }

    OUT_QIMSDK_IMAGE_NAME="qimsdk${ADDITIONAL_TAG_IMAGE}"

    OUT_QIMSDK_GST_SOURCES=$(echo ${JSON_CONTENT} | jq '.IM_SDK_Source_Dir' | tr -d '"')
    OUT_QIMSDK_GST_SOURCES=${OUT_QIMSDK_GST_SOURCES%/}

    qimsdk-expand-tilde OUT_QIMSDK_GST_SOURCES

    [ -d "${OUT_QIMSDK_GST_SOURCES}/.git" ]                                                     || \
            [ -d "${OUT_QIMSDK_GST_SOURCES}/gst-plugin-base" ]                                  || {
        print-red "Please provide path to gst-plugins-qti-oss directory in config json!!!"
        print-red "Directory currently provided: ${OUT_QIMSDK_GST_SOURCES}"
        return -1
    }

    OUT_QIMSDK_GST_META=$(echo ${JSON_CONTENT} | jq '.IM_SDK_Meta_Dir' | tr -d '"')
    OUT_QIMSDK_GST_META=${OUT_QIMSDK_GST_META%/}

    qimsdk-expand-tilde OUT_QIMSDK_GST_META

    [ -d "${OUT_QIMSDK_GST_META}/.git" ]                                                        || \
            [ -d "${OUT_QIMSDK_GST_META}/recipes-gst/gstreamer" ]                               || {
        print-red "Please provide path to meta-qti-gst directory in config json!!!"
        print-red "Directory currently provided: ${IM_SDK_Meta_Dir}"
        return -1
    }

    OUT_QIMSDK_PATH_MICROSERVICES=$(
        echo ${JSON_CONTENT} | jq '.Solution_Microservices_Dir' | tr -d '"'
    )
    OUT_QIMSDK_PATH_MICROSERVICES=${OUT_QIMSDK_PATH_MICROSERVICES%/}

    qimsdk-expand-tilde OUT_QIMSDK_PATH_MICROSERVICES

    [ -d "${OUT_QIMSDK_PATH_MICROSERVICES}/.git" ]                                              || \
            [ -d "${OUT_QIMSDK_PATH_MICROSERVICES}/ai" ]                                        || {
        print-red "Please provide path to solutions-microservices directory in config json!!!"
        print-red "Directory currently provided: ${Solution_Microservices_Dir}"
        return -1
    }

    OUT_QIMSDK_LE_SERVICES_SOURCES=$(echo ${JSON_CONTENT} | jq '.LE_Services_Source_Dir' | tr -d '"')
    OUT_QIMSDK_LE_SERVICES_SOURCES=${OUT_QIMSDK_LE_SERVICES_SOURCES%/}

    qimsdk-expand-tilde OUT_QIMSDK_LE_SERVICES_SOURCES

    [ -d "${OUT_QIMSDK_LE_SERVICES_SOURCES}/.git" ]                                             || \
            [ -d "${OUT_QIMSDK_LE_SERVICES_SOURCES}/recorder" ]                                 || {
        print-red "Please provide path to le-services directory in config json!!!"
        print-red "Directory currently provided: ${OUT_QIMSDK_LE_SERVICES_SOURCES}"
        return -1
    }

    OUT_QIMSDK_PATH_TO_eSDK_DIR=$(
        echo ${JSON_CONTENT} | jq '.Path_to_eSDK_dir' | tr -d '"'
    )

    qimsdk-expand-tilde OUT_QIMSDK_PATH_TO_eSDK_DIR

    [ ! -d "${OUT_QIMSDK_PATH_TO_eSDK_DIR}" ] && {
        OUT_QIMSDK_PATH_TO_eSDK_DIR="no-eSDK-provided"

        print-yellow "The Path_to_eSDK_dir attribute is filled wrong in config json!"
        print-red "Please provide path to unarchived eSDK directory in config json!!!"

        return -1
    }

    OUT_QIMSDK_SUPPORTED_TARGETS=( $(
        echo ${JSON_CONTENT} | jq '.Supported_targets[]' | tr -d '"'
    ) )

    [ ${#OUT_QIMSDK_SUPPORTED_TARGETS[@]} -eq 0 ]                                               && {
        print-red "Supported_targets attribute is empty in config json !!!"
        return -1
    }

    return 0
}

# Qimsdk initialize docker build
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) variable to take container name value
#   $3 - (mandatory) variable to take image name value
#   $4 - (mandatory) docker base dir
#   $5 - (mandatory) temp folder
#   $6 - (mandatory) docker image path
#   $7 - (mandatory) device ID
function qimsdk-docker-build-initialize() {
    local PATH_TO_CONFIG_JSON=${1}

    local -n QIMSDK_CONTAINER_NAME_PTR=${2}
    local -n QIMSDK_IMAGE_NAME_PTR=${3}
    local -n QIMSDK_BASE_DIR_PTR=${4}
    local -n QIMSDK_TMP_FOLDER_PTR=${5}
    local -n DOCKER_IMAGE_PATH_PTR=${6}
    local -n QIMSDK_DEVICE_ID_PTR=${7}

    local QIMSDK_GST_SOURCES
    local QIMSDK_GST_META
    local QIMSDK_PATH_MICROSERVICES
    local QIMSDK_LE_SERVICES_SOURCES
    local QIMSDK_PATH_TO_eSDK_DIR
    local QIMSDK_SUPPORTED_TARGETS

    qimsdk-docker-parse-json ${PATH_TO_CONFIG_JSON}                                                \
            QIMSDK_CONTAINER_NAME_PTR                                                              \
            QIMSDK_IMAGE_NAME_PTR                                                                  \
            QIMSDK_GST_SOURCES                                                                     \
            QIMSDK_GST_META                                                                        \
            QIMSDK_PATH_MICROSERVICES                                                              \
            QIMSDK_LE_SERVICES_SOURCES                                                             \
            QIMSDK_PATH_TO_eSDK_DIR                                                                \
            QIMSDK_SUPPORTED_TARGETS

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-docker-parse-json !!!"
        return ${rc}
    }

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH_PTR

    rc=$?
    [ ${rc} -ne 0 ]                                                                             && {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return ${rc}
    }

    [[ "${DOCKER_IMAGE_PATH_PTR}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH_PTR}" ]            && {
        mkdir -p ${DOCKER_IMAGE_PATH_PTR}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH_PTR} !!!"
            return ${rc}
        }
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID_PTR

    rc=$?
    [ ${rc} -ne 0 ]                                                                             && {
        print-red "FAILED: qimsdk-get-device-id !!!"
        return ${rc}
    }

    QIMSDK_TMP_FOLDER_PTR="${QIMSDK_DOCKER_DIR}/tmp"
    mkdir -p ${QIMSDK_TMP_FOLDER_PTR}

    rsync -aL ${QIMSDK_GST_SOURCES}/ ${QIMSDK_TMP_FOLDER_PTR}/gst-plugins-qti-oss

    QIMSDK_PATH_TO_eSDK_DIR=${QIMSDK_PATH_TO_eSDK_DIR%/}

    local PATH_TO_GSTREAMER_PATCHES="${QIMSDK_GST_META}/`
        `recipes-gst/gstreamer/gstreamer1.0/1.24/"

    [ ! -d ${PATH_TO_GSTREAMER_PATCHES} ] && {
        print-red "gstreamer's patches NOT found !!!"
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    local PATH_TO_GST_PLUGINS_BASE_PATCHES="${QIMSDK_GST_META}/`
        `recipes-gst/gstreamer/gstreamer1.0-plugins-base/1.24/"

    [ ! -d ${PATH_TO_GST_PLUGINS_BASE_PATCHES} ] && {
        print-red "gstreamer-plugins-base's patches NOT found !!!"
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    local PATH_TO_GST_PLUGINS_GOOD_PATCHES="${QIMSDK_GST_META}/`
        `recipes-gst/gstreamer/gstreamer1.0-plugins-good/1.24.2/"

    [ ! -d ${PATH_TO_GST_PLUGINS_GOOD_PATCHES} ] && {
        print-red "gstreamer-plugins-good's patches NOT found !!!"
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    local PATH_TO_GST_PLUGINS_BAD_PATCHES="${QIMSDK_GST_META}/`
        `recipes-gst/gstreamer/gstreamer1.0-plugins-bad/1.24.2/"

    [ ! -d ${PATH_TO_GST_PLUGINS_BAD_PATCHES} ] && {
        print-red "gstreamer-plugins-bad's patches NOT found !!!"
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    local PATH_TO_WAYLAND_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
            `meta-qti-display/recipes-graphics/wayland/wayland-protocols/"

    [ ! -d ${PATH_TO_WAYLAND_PATCHES} ]                                                         && \
            PATH_TO_WAYLAND_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
            `meta-qcom-hwe/recipes-graphics/wayland/wayland-protocols/"

    [ ! -d ${PATH_TO_WAYLAND_PATCHES} ] && {
        print-red "wayland-protocol's patches NOT found !!!"
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    local PATH_TO_GSTD_PATCHES="${QIMSDK_GST_META}/recipes-gst/gstreamer/gstd/"

    [ ! -d ${PATH_TO_GSTD_PATCHES} ] && {
        print-red "gstd's patches NOT found !!!"
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    local PATH_TO_PULSEAUDIO_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
        `poky/meta/recipes-multimedia/pulseaudio/pulseaudio/"

    [ ! -d ${PATH_TO_PULSEAUDIO_PATCHES} ] && {
        print-red "pulseaudio's patches NOT found !!!"
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    local QIMSDK_PATH_TO_PULSEAUDIO_META="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
            `meta-qti-pulseaudio-plugins"
    [ -d "${QIMSDK_PATH_TO_PULSEAUDIO_META}" ]                                                  || {
        QIMSDK_PATH_TO_PULSEAUDIO_META="${QIMSDK_PATH_TO_eSDK_DIR}/layers/meta-qcom-hwe"
        [ -d "${QIMSDK_PATH_TO_PULSEAUDIO_META}" ]                                              || {
            echo "Cannot find path to pulseaudio meta !!!"
            return -1
        }
    }

    local TARGET_SYSROOT=$(find ${QIMSDK_PATH_TO_eSDK_DIR}/tmp/sysroots -name fastcv.h | head -n 1)
    TARGET_SYSROOT=${TARGET_SYSROOT%"/usr/include/fastcv/fastcv.h"}

    [ -d "${TARGET_SYSROOT}" ]                                                                  || {
        print-red "Could not find target sysroot in ${QIMSDK_PATH_TO_eSDK_DIR}"
        return -1
    }

    pushd ${TARGET_SYSROOT} 1>/dev/null || {
        print-red "FAILED: pushd to Path_to_eSDK_dir"
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    [ -f "./usr/include/display/media/mmm_color_fmt.h" ] && {
        rsync -aR ./usr/include/display/media/mmm_color_fmt.h                                      \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/
    }

    rsync -aR ./usr/include/fastcv/fastcv.h                                                        \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/iot-core-algs/ib2c.h                                                   \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/CL/cl_ext_qcom.h                                                       \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/properties.h                                                           \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/properties_def.h                                                       \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/log.h                                                                  \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/system/camera_metadata.h                                               \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/system/camera_metadata_tags.h                                          \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/system/camera_vendor_tags.h                                            \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/hardware/graphics.h                                                    \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/iot-core-algs/videoctrl.h                                              \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   && \
    rsync -aR ./usr/include/hardware/native_handle.h                                               \
            ${QIMSDK_TMP_FOLDER_PTR}/headers/                                                   || {
        echo "Cannot get headers from eSDK !!!"
        popd 1>/dev/null
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    # Skip building dfs in case dependencies are not met
    [ -f ./usr/include/dfs_factory.h ] && {
        rsync -aR ./usr/include/dfs_factory.h                                                      \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/mv.h                                                               \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/mvSRW.h                                                            \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/mvVM.h                                                             \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/mvVSLAM.h                                                          \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rv.h                                                               \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvAE.h                                                             \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvCamera.h                                                         \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvDFS.h                                                            \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvGoalDetection.h                                                  \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvLog.h                                                            \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvNAVMAP.h                                                         \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvPLANNER.h                                                        \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvQueue.h                                                          \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvVIO.h                                                            \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvVM.h                                                             \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvVSLAM.h                                                          \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvVWSLAM.h                                                         \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rvWOD.h                                                            \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rv_dfs_base.h                                                      \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               && \
        rsync -aR ./usr/include/rv_multi_dfs_base.h                                                \
                ${QIMSDK_TMP_FOLDER_PTR}/headers/                                               || {
            echo "Cannot get headers from eSDK !!!"
            popd 1>/dev/null
            rm -rf ${QIMSDK_TMP_FOLDER_PTR}
            return -1
        }
    }

    local PKG_CONFIG_FILES_DIR="./usr/lib/pkgconfig/"

    [ -d ${PKG_CONFIG_FILES_DIR} ] && {
        mkdir -p ${QIMSDK_TMP_FOLDER_PTR}/lib/pkgconfig
        declare -a PLATFORM_LIBS="msm_gbm libgbm libatomic libgsl libib2C libegl_adreno `
                                 `libglesv2_adreno libpropertyvault libwayland-client `
                                 `libwayland-egl libadreno_utils libcb libegl libdmabufheap `
                                 `libeglsubdriverwayland libglesv1_cm libglesv1_cm_adreno `
                                 `libglesv2 libllvm-glnext libllvm-qcom libllvm-qgl libopencl `
                                 `libopencl_adreno libq3dtools_adreno libq3dtools_esx `
                                 `libvulkan_adreno libadsprpc libcdsprpc libfastcvopt `
                                 `libfastcvdsp_stub libc++ libc++abi libproperty-vault `
                                 `tensorflow-lite"

        for LIB_NAME in ${PLATFORM_LIBS[@]}; do
            local PREFIX=`echo ${LIB_NAME} | cut -c1-3`

            [ "${PREFIX}" == "lib" ] && {
                local NO_PREFIX_LIB_NAME=${LIB_NAME#*lib}
                [ -f "${PKG_CONFIG_FILES_DIR}/${NO_PREFIX_LIB_NAME}.pc" ] && {
                    rsync -a "${PKG_CONFIG_FILES_DIR}/${NO_PREFIX_LIB_NAME}.pc" \
                        ${QIMSDK_TMP_FOLDER_PTR}/lib/pkgconfig/ || {
                        echo "Failed to copy pkg-config file ${LIB_NAME}.pc !!!"
                        popd 1>/dev/null
                        return -1
                    }
                }
            }

            [ -f "${PKG_CONFIG_FILES_DIR}/${LIB_NAME}.pc" ] && {
                rsync -a "${PKG_CONFIG_FILES_DIR}/${LIB_NAME}.pc" \
                    ${QIMSDK_TMP_FOLDER_PTR}/lib/pkgconfig/ || {
                    echo "Failed to copy pkg-config file ${LIB_NAME}.pc !!!"
                    popd 1>/dev/null
                    return -1
                }
            }
            continue
        done

    } || {
        echo "Cannot get pkg-config files from eSDK !!!"
        popd 1>/dev/null
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    popd 1>/dev/null                                                                            && \

    mkdir -p ${QIMSDK_TMP_FOLDER_PTR}/patches/wayland-protocols-1.33/                           && \
    mkdir -p ${QIMSDK_TMP_FOLDER_PTR}/patches/gstreamer-1.24.2/                                 && \
    mkdir -p ${QIMSDK_TMP_FOLDER_PTR}/patches/gst-plugins-base-1.24.2/                          && \
    mkdir -p ${QIMSDK_TMP_FOLDER_PTR}/patches/gst-plugins-good-1.24.2/                          && \
    mkdir -p ${QIMSDK_TMP_FOLDER_PTR}/patches/gst-plugins-bad-1.24.2/                           && \
    mkdir -p ${QIMSDK_TMP_FOLDER_PTR}/patches/gstd/                                             && \
    mkdir -p ${QIMSDK_TMP_FOLDER_PTR}/patches/pulseaudio/                                       && \

    rsync -a ${PATH_TO_WAYLAND_PATCHES}/*.patch                                                    \
            ${QIMSDK_TMP_FOLDER_PTR}/patches/wayland-protocols-1.33/                            && \

    rsync -a ${PATH_TO_GSTREAMER_PATCHES}/*.patch                                                  \
            ${QIMSDK_TMP_FOLDER_PTR}/patches/gstreamer-1.24.2/                                  && \

    rsync -a ${PATH_TO_GST_PLUGINS_BASE_PATCHES}/*.patch                                           \
            ${QIMSDK_TMP_FOLDER_PTR}/patches/gst-plugins-base-1.24.2/                           && \

    rsync -a ${PATH_TO_GST_PLUGINS_GOOD_PATCHES}/*.patch                                           \
            ${QIMSDK_TMP_FOLDER_PTR}/patches/gst-plugins-good-1.24.2/                           && \

    rsync -a ${PATH_TO_GST_PLUGINS_BAD_PATCHES}/*.patch                                            \
            ${QIMSDK_TMP_FOLDER_PTR}/patches/gst-plugins-bad-1.24.2/                            && \

    rsync -a ${QIMSDK_PATH_TO_PULSEAUDIO_META}/recipes-multimedia/audio/pulseaudio/*.patch         \
            ${QIMSDK_TMP_FOLDER_PTR}/patches/pulseaudio/                                        && \

    rsync -a ${PATH_TO_PULSEAUDIO_PATCHES}/*.patch                                                 \
            ${QIMSDK_TMP_FOLDER_PTR}/patches/pulseaudio/                                        && \

    rsync -a ${PATH_TO_GSTD_PATCHES}/*.patch                                                       \
            ${QIMSDK_TMP_FOLDER_PTR}/patches/gstd/                                              || {
        print-red "Cannot get patches from eSDK !!!"
        rm -rf ${QIMSDK_TMP_FOLDER_PTR}
        return -1
    }

    local QIMSDK_SUPPORTED_TARGETS_COUNT=${#QIMSDK_SUPPORTED_TARGETS[@]}

    for ((INDEX=0 ; INDEX<${QIMSDK_SUPPORTED_TARGETS_COUNT} ; INDEX++)); do

        # Skipping ubuntu targets
        [[ "${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}" == *_ubun ]]                                 && {
            continue
        }

        python3 ${QIMSDK_DOCKER_DIR}/scripts/tools/RecipeParser.py                                 \
                -l ${QIMSDK_PATH_TO_eSDK_DIR}/layers/                                              \
                -m ${QIMSDK_GST_META}                                                              \
                -p ${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}                                           \
                -t ${QIMSDK_TMP_FOLDER_PTR}                                                        \
                BuildCodeGenerator                                                              || {
            print-red "Python Parser returns error, mode BuildCodeGenerator !!!"
            rm -rf ${QIMSDK_TMP_FOLDER_PTR}
            return -1
        }

        python3 ${QIMSDK_DOCKER_DIR}/scripts/tools/RecipeParser.py                                 \
                -l ${QIMSDK_PATH_TO_eSDK_DIR}/layers/                                              \
                -m ${QIMSDK_GST_META}                                                              \
                -p ${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}                                           \
                -t ${QIMSDK_TMP_FOLDER_PTR}                                                        \
                RuntimeFlagsGenerator                                                           || {
            print-red "Python Parser Crashed, mode RuntimeFlagsGenerator !!!"
            rm -rf ${QIMSDK_TMP_FOLDER_PTR}
            return -1
        }

        python3 ${QIMSDK_DOCKER_DIR}/scripts/tools/RecipeParser.py                                 \
                -l ${QIMSDK_PATH_TO_eSDK_DIR}/layers/                                              \
                -m ${QIMSDK_GST_META}                                                              \
                -p ${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}                                           \
                -t ${QIMSDK_TMP_FOLDER_PTR}                                                        \
                -v "1.24.2"                                                                        \
                BBPatchParser                                                                   || {
            print-red "Python Parser returns error, mode BBPatchParser !!!"
            rm -rf ${QIMSDK_TMP_FOLDER_PTR}
            return -1
        }

        # Skipping a comparison with index zero
        [ ${INDEX} -eq 0 ]                                                                      && {
            continue
        }

        diff ${QIMSDK_TMP_FOLDER_PTR}/${QIMSDK_SUPPORTED_TARGETS[0]}_recipes_patches.json          \
            ${QIMSDK_TMP_FOLDER_PTR}/${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}_recipes_patches.json || {
            print-yellow "Patches of supported targets differ !!!"
        }

        diff ${QIMSDK_TMP_FOLDER_PTR}/${QIMSDK_SUPPORTED_TARGETS[0]}_build_plugins.sh              \
            ${QIMSDK_TMP_FOLDER_PTR}/${QIMSDK_SUPPORTED_TARGETS[${INDEX}]}_build_plugins.sh     || {
            print-yellow "Build flags of supported targets differ !!!"
        }
    done

    mv ${QIMSDK_TMP_FOLDER_PTR}/${QIMSDK_SUPPORTED_TARGETS[0]}_build_plugins.sh                    \
        ${QIMSDK_TMP_FOLDER_PTR}/build_plugins.sh

    mv ${QIMSDK_TMP_FOLDER_PTR}/${QIMSDK_SUPPORTED_TARGETS[0]}_recipes_patches.json                \
        ${QIMSDK_TMP_FOLDER_PTR}/recipes_patches.json

    rsync -aL ${QIMSDK_PATH_MICROSERVICES}/ ${QIMSDK_TMP_FOLDER_PTR}/solutions-microservices

    rsync -aL ${QIMSDK_LE_SERVICES_SOURCES}/ ${QIMSDK_TMP_FOLDER_PTR}/le-services

    QIMSDK_BASE_DIR_PTR="/mnt/work"
}

# Build dev docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function qimsdk-dev-docker-build-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH
    local QIMSDK_DEVICE_ID
    local QIMSDK_BASE_DIR
    local QIMSDK_TMP_FOLDER

    qimsdk-docker-build-initialize ${PATH_TO_CONFIG_JSON}                                          \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                      \
            QIMSDK_BASE_DIR                                                                        \
            QIMSDK_TMP_FOLDER                                                                      \
            DOCKER_IMAGE_PATH                                                                      \
            QIMSDK_DEVICE_ID

    local rc=$?
    [ ${rc} -ne 0 ]                                                                             && {
        print-red "FAILED: qimsdk-docker-build-initialize !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return ${rc}
    }

    DOCKER_BUILDKIT=1 docker build                                                                 \
            --build-arg QIMSDK_ARG_BASE_DIR=${QIMSDK_BASE_DIR}                                     \
            --build-arg QIMSDK_ARG_DOCKER_IMAGE_PATH=${DOCKER_IMAGE_PATH}                          \
            --build-arg QIMSDK_ARG_DEVICE_ID=${QIMSDK_DEVICE_ID}                                   \
            --build-arg QIMSDK_ARG_CONTAINER_NAME=${QIMSDK_CONTAINER_NAME}                         \
            --build-arg QIMSDK_ARG_HTTP_PROXY=${http_proxy}                                        \
            --build-arg QIMSDK_ARG_HTTPS_PROXY=${https_proxy}                                      \
            --build-arg QIMSDK_ARG_NO_PROXY=${no_proxy}                                            \
            --progress=plain --target QIMSDK_dev_image                                             \
            ${QIMSDK_DOCKER_DIR} -t ${QIMSDK_IMAGE_NAME}_dev

    rc=$?
    [ ${rc} -ne 0 ]                                                                             && {
        print-red "Build image failed !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return ${rc}
    }

    rm -rf ${QIMSDK_TMP_FOLDER}

    print-green "Build image completed successfully !!!"

    return 0
}

# Build docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function qimsdk-docker-build-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH
    local QIMSDK_DEVICE_ID
    local QIMSDK_BASE_DIR
    local QIMSDK_TMP_FOLDER

    qimsdk-docker-build-initialize ${PATH_TO_CONFIG_JSON}                                          \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                      \
            QIMSDK_BASE_DIR                                                                        \
            QIMSDK_TMP_FOLDER                                                                      \
            DOCKER_IMAGE_PATH                                                                      \
            QIMSDK_DEVICE_ID

    local rc=$?
    [ ${rc} -ne 0 ]                                                                             && {
        print-red "FAILED: qimsdk-docker-build-initialize !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return ${rc}
    }

    DOCKER_BUILDKIT=1 docker build                                                                 \
            --build-arg QIMSDK_ARG_BASE_DIR=${QIMSDK_BASE_DIR}                                     \
            --build-arg QIMSDK_ARG_HTTP_PROXY=${http_proxy}                                        \
            --build-arg QIMSDK_ARG_HTTPS_PROXY=${https_proxy}                                      \
            --build-arg QIMSDK_ARG_NO_PROXY=${no_proxy}                                            \
            --progress=plain --target QIMSDK_device_image                                          \
            ${QIMSDK_DOCKER_DIR} -t ${QIMSDK_IMAGE_NAME}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Build image failed !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return ${rc}
    }

    rm -rf ${QIMSDK_TMP_FOLDER}

    print-green "Build image completed successfully !!!"

    return 0
}

# Update selected device image to the device
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-update-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id !!!"
        return ${rc}
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    docker save ${QIMSDK_IMAGE_NAME}:latest -o ${FILE_NAME}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Device load image failed: docker save failed !!!"
        rm ${FILE_NAME}
        return ${rc}
    }

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qimsdk-device-command "mkdir -p /tmp/data/docker_images" ${QIMSDK_DEVICE_ID}

        local rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: qimsdk-device-command !!!"
            rm ${FILE_NAME}

            return ${rc}
        }

        adb push ${FILE_NAME} /tmp/data/docker_images

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: adb push ${FILE_NAME} /tmp/data/docker_images !!!"
            rm ${FILE_NAME}

            return ${rc}
        }

        rm ${FILE_NAME}

        qimsdk-device-command "docker load -i /tmp/data/docker_images/${FILE_NAME}" ${QIMSDK_DEVICE_ID}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return ${rc}
        }

        qimsdk-device-command "rm /tmp/data/docker_images/${FILE_NAME}" ${QIMSDK_DEVICE_ID}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "Device failed to remove ${FILE_NAME} !!!"
            return ${rc}
        }

        return 0
    )

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: Device update image !!!"
        return ${rc}
    }

    print-green "Device update image successful !!!"

    return 0
}

# Save selected device image
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-save-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return ${rc}
    }

    [[ "${DOCKER_IMAGE_PATH}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH}" ]                    && {
        mkdir -p ${DOCKER_IMAGE_PATH}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH} !!!"
            return ${rc}
        }
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    local COMMON_PATH=""

    [ -d ${DOCKER_IMAGE_PATH} ] && {
        COMMON_PATH=${DOCKER_IMAGE_PATH}
    } || {
        COMMON_PATH=$(mktemp -d)
    }

    docker save ${QIMSDK_IMAGE_NAME}:latest -o ${COMMON_PATH}/${FILE_NAME}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Device save image failed: docker save failed !!!"
        rm -f ${COMMON_PATH}/${FILE_NAME}

        return ${rc}
    }

    qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/${FILE_NAME} ${DOCKER_IMAGE_PATH}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-sync-to-remote-and-clean"
        rm -f ${COMMON_PATH}/${FILE_NAME}

        return ${rc}
    }

    local PLATFORMS=(
        $(cat ${PATH_TO_CONFIG_JSON} | jq '.Supported_targets[]' | tr -d '"')
    )

    for SUFFIX_NAME in ${PLATFORMS[@]}; do
        local DEVICE_JSON="${QIMSDK_DOCKER_DIR}/targets/${SUFFIX_NAME}.json"

        qimsdk-generate-docker-run-cdi-cmd ${DEVICE_JSON}                                          \
                ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh                                    \
                ${QIMSDK_CONTAINER_NAME}                                                           \
                ${QIMSDK_IMAGE_NAME}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "Generate ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh file failed !!!"
            rm -f ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh

            return ${rc}
        }

        qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh            \
                ${DOCKER_IMAGE_PATH}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: qimsdk-sync-to-remote-and-clean"
            rm -f ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh

            return ${rc}
        }

        qimsdk-generate-docker-compose-cdi-yaml ${DEVICE_JSON}                                     \
                ${COMMON_PATH}/docker-compose-cdi-${SUFFIX_NAME}.yml                               \
                ${QIMSDK_CONTAINER_NAME}                                                           \
                ${QIMSDK_IMAGE_NAME}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "Generate qimsdk docker compose CDI file failed !!!"
            rm -f ${COMMON_PATH}/docker-compose-cdi-${SUFFIX_NAME}.yml

            return ${rc}
        }

        qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/docker-compose-cdi-${SUFFIX_NAME}.yml       \
                ${DOCKER_IMAGE_PATH}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: qimsdk-sync-to-remote-and-clean"
            rm -f ${COMMON_PATH}/docker-compose-cdi-${SUFFIX_NAME}.yml

            return ${rc}
        }
    done

    print-green "Device save image successful !!!"

    return 0
}

# Load selected device image
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-load-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return ${rc}
    }

    [[ "${DOCKER_IMAGE_PATH}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH}" ]                    && {
        mkdir -p ${DOCKER_IMAGE_PATH}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH} !!!"
            return ${rc}
        }
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id !!!"
        return ${rc}
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    local LOCAL_DOCKER_IMAGE="${DOCKER_IMAGE_PATH}/${FILE_NAME}"

    [ ! -d ${DOCKER_IMAGE_PATH} ] && {
        local TMP_DOCKER_IMAGE_PATH=$(mktemp -d)

        rsync -aP ${DOCKER_IMAGE_PATH}/${FILE_NAME} ${TMP_DOCKER_IMAGE_PATH}/${FILE_NAME}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: rsync -aP ${DOCKER_IMAGE_PATH}/${FILE_NAME}                         \
                    ${TMP_DOCKER_IMAGE_PATH}/${FILE_NAME}"

            return ${rc}
        }

        LOCAL_DOCKER_IMAGE="${TMP_DOCKER_IMAGE_PATH}/${FILE_NAME}"
    }

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

            return -1
        }

        qimsdk-device-command "mkdir -p /tmp/data/docker_images" ${QIMSDK_DEVICE_ID}

        local rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: qimsdk-device-command !!!"
            qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

            return ${rc}
        }

        adb push ${LOCAL_DOCKER_IMAGE} /tmp/data/docker_images

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: adb push ${LOCAL_DOCKER_IMAGE}                                      \
                    /tmp/data/docker_images !!!"

            qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

            return ${rc}
        }

        qimsdk-remove-if-temp ${LOCAL_DOCKER_IMAGE}

        qimsdk-device-command "docker load -i /tmp/data/docker_images/${FILE_NAME}"               \
            ${QIMSDK_DEVICE_ID}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return ${rc}
        }

        qimsdk-device-command "rm /tmp/data/docker_images/${FILE_NAME}" ${QIMSDK_DEVICE_ID}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "Device failed to remove ${FILE_NAME} !!!"
            return ${rc}
        }

        return 0
    )

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: Device load image !!!"
        return ${rc}
    }

    print-green "Device load image successful !!!"

    return 0
}

# Run selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-dev-docker-run-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    local DEVELOPMENT_MAP

    qimsdk-get-map-for-dev-container ${PATH_TO_CONFIG_JSON}                                        \
            DEVELOPMENT_MAP

    local USB_DEVICE=""
    [ -d /dev/bus/usb ] && USB_DEVICE="--device /dev/bus/usb"

    docker run -it -d --net host -h ${QIMSDK_CONTAINER_NAME}_dev                                   \
            --name ${QIMSDK_CONTAINER_NAME}_dev                                                    \
            ${USB_DEVICE} ${DEVELOPMENT_MAP}                                                       \
            ${QIMSDK_IMAGE_NAME}_dev bash

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Run dev container failed !!!"
        return ${rc}
    }

    # Propagate ssh and gitconfig to container
    docker exec --user root ${QIMSDK_CONTAINER_NAME}_dev mkdir -p /root/.ssh || {
        print-red "docker mkdir ~/.ssh failed !!!"
        return -1
    }

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp ${f} ${QIMSDK_CONTAINER_NAME}_dev:/root/.ssh/${BASE_NAME} || {
                print-red "Propagating .ssh/ to docker failed !!!"
                return -1
            }
        done
        docker exec --user root ${QIMSDK_CONTAINER_NAME}_dev chown -R root:root /root/.ssh || {
            print-red "Propagating .ssh/ to docker failed !!!"
            return -1
        }
    fi

    if [ -f ~/.gitconfig ]; then
        docker cp ~/.gitconfig ${QIMSDK_CONTAINER_NAME}_dev:/root/.gitconfig                    && \
            docker exec --user root ${QIMSDK_CONTAINER_NAME}_dev chown -R root:root                \
                /root/.gitconfig                                                                || {
                print-red "Propagating .gitconfig to docker failed !!!"
                return -1
            }
    fi

    if [ -f /etc/gitconfig ]; then
        docker cp /etc/gitconfig ${QIMSDK_CONTAINER_NAME}_dev:/etc/gitconfig                    || {
            print-red "Propagating .gitconfig to docker failed !!!"
            return -1
        }
    fi

    print-green "Run dev container successful !!!"

    return 0
}

# Run selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-device-docker-run-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    docker run -it -d --net host -h ${QIMSDK_CONTAINER_NAME} --user qimsdk                         \
            --name ${QIMSDK_CONTAINER_NAME} ${QIMSDK_IMAGE_NAME} bash

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Run device container failed on pc emulator !!!"
        return ${rc}
    }

    # Propagate ssh and gitconfig to container
    docker exec --user root ${QIMSDK_CONTAINER_NAME} mkdir /root/.ssh || {
        print-red "docker mkdir ~/.ssh failed !!!"
        return -1
    }

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp ${f} ${QIMSDK_CONTAINER_NAME}:/root/.ssh/${BASE_NAME} || {
                print-red "Propagating .ssh/ to docker failed !!!"
                return -1
            }
        done
        docker exec --user root ${QIMSDK_CONTAINER_NAME} chown -R root:root /root/.ssh || {
            print-red "Propagating .ssh/ to docker failed !!!"
            return -1
        }
    fi

    print-green "Run device container successful on pc emulator !!!"

    return 0
}

# Run selected device container in cdi mode
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-run-cdi-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return ${rc}
    }

    (
        local PLATFORMS=(
            $(cat ${PATH_TO_CONFIG_JSON} | jq '.Supported_targets[]' | tr -d '"')
        )

        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        local MACHINE=$(adb shell "cat /sys/devices/soc0/machine" | tr -d '\r')

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: adb shell "cat /sys/devices/soc0/machine"  !!!"
            return ${rc}
        }

        local MEDIA_DIRS=("labels" "media" "models")

        for idx in ${!MEDIA_DIRS[@]}; do
            qimsdk-device-command "mkdir -m 777 -p /etc/${MEDIA_DIRS[$idx]}"                    || {
                print-red "FAILED: /etc/${MEDIA_DIRS[$idx]} can not be created in device !!!"
                return -1
            }
        done

        local TARGET_PLATFORM=""

        local TMP_RUN_CMD_DIR=$(mktemp -d)

        for SUFFIX_NAME in ${PLATFORMS[@]}; do
            local DEVICE_JSON="${QIMSDK_DOCKER_DIR}/targets/${SUFFIX_NAME}.json"

            qimsdk-generate-docker-run-cdi-cmd ${DEVICE_JSON}                                      \
                    ${TMP_RUN_CMD_DIR}/docker_run_cdi_${SUFFIX_NAME}.sh                            \
                    ${QIMSDK_CONTAINER_NAME}                                                       \
                    ${QIMSDK_IMAGE_NAME}

            rc=$?
            [ ${rc} -ne 0 ] && {
                print-red "Generate ${TMP_RUN_CMD_DIR}/docker_run_cdi_${SUFFIX_NAME}.sh file failed !!!"
                rm -rf ${TMP_RUN_CMD_DIR}

                return ${rc}
            }

            declare -A SOC_LIST=$(cat ${DEVICE_JSON} | jq '.Soc[]' | tr -d '"')

            for SOC in ${SOC_LIST[@]}; do
                [[ ${MACHINE} == ${SOC} ]] && {
                    TARGET_PLATFORM="${SUFFIX_NAME}"
                    break
                }
            done
        done

        [ -z ${TARGET_PLATFORM} ] && {
            print-red "Target platform is not set !!!"
            return -1
        }

        adb push ${TMP_RUN_CMD_DIR}/docker_run_cdi_${TARGET_PLATFORM}.sh /tmp/                  && \
        qimsdk-device-command "source /tmp/docker_run_cdi_${TARGET_PLATFORM}.sh"                || {
            rm -rf ${TMP_RUN_CMD_DIR}
            qimsdk-device-command "rm -rf /tmp/docker_run_cdi_${TARGET_PLATFORM}.sh"
            echo "qimsdk-docker-device-run-container failed !!!"
            return -1
        }

        rm -rf ${TMP_RUN_CMD_DIR}
        qimsdk-device-command "rm -rf /tmp/docker_run_cdi_${TARGET_PLATFORM}.sh"
    )

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Device run container in CDI mode failed !!!"
        return ${rc}
    }

    print-green "Device run container in CDI mode successful !!!"

    return 0
}

# Remove selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-rm-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return ${rc}
    }

    qimsdk-device-command "docker rm ${QIMSDK_CONTAINER_NAME}" ${QIMSDK_DEVICE_ID}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Device rm container failed !!!"
        return ${rc}
    }

    print-green "Device rm container successful !!!"

    return 0
}

# Start selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-start-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return ${rc}
    }

    qimsdk-device-command "docker start ${QIMSDK_CONTAINER_NAME}" ${QIMSDK_DEVICE_ID}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Device start container failed !!!"
        return ${rc}
    }

    print-green "Device start container successful !!!"

    return 0
}

# Stop selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-stop-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return ${rc}
    }

    qimsdk-device-command "docker stop ${QIMSDK_CONTAINER_NAME}" ${QIMSDK_DEVICE_ID}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Device stop container failed !!!"
        return ${rc}
    }

    print-green "Device stop container successful !!!"

    return 0
}

# Execute CMD in device container
#   $1 - (mandatory) path to target config json
#   $2 - (optional) command to execute
function qimsdk-docker-device-command() {
    local PATH_TO_CONFIG_JSON=${1}
    local CMD=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID
    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return ${rc}
    }

    qimsdk-device-command "docker exec ${QIMSDK_CONTAINER_NAME} bash -c ${CMD}" ${QIMSDK_DEVICE_ID}
    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-device-command !!!"
        return ${rc}
    }

    return 0
}

# Start shell in the docker container on the device
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-shell() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID
    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return ${rc}
    }

    adb -s ${QIMSDK_DEVICE_ID} shell -t "docker exec -it ${QIMSDK_CONTAINER_NAME} bash"
}

# Docker device images clean up
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-images-cleanup() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_DEVICE_ID

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return ${rc}
    }

    local DEVICE_DOCKER_IMAGES=$(
        qimsdk-device-command "docker images -f 'dangling=true' -q" ${QIMSDK_DEVICE_ID}
    )

    qimsdk-device-command "docker rmi ${DEVICE_DOCKER_IMAGES}" ${QIMSDK_DEVICE_ID}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-device-command !!!"
        return ${rc}
    }

    print-green "Device docker images cleanup complete !!!"

    return 0
}

# Docker host images clean up
function qimsdk-docker-host-images-cleanup() {
    local HOST_DOCKER_IMAGES=$(docker images -f "dangling=true" -q)

    docker rmi ${HOST_DOCKER_IMAGES}

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: docker rmi of all !!!"
        return ${rc}
    }

    docker builder prune -a -f

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: docker builder prune -a -f !!!"
        return ${rc}
    }

    print-green "Host docker images cleanup complete !!!"

    return 0
}

# Load artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) artifacts variant - release or debug
function qimsdk-dev-load-artifacts-variant() {
    local PATH_TO_CONFIG_JSON=${1}
    local VARIANT=${2}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID
    local DOCKER_IMAGE_PATH

    [ "${VARIANT}" == "release" ] || [ "${VARIANT}" == "debug" ] || {
        print-red "Failed to load ${VARIANT} packages !!!"
        print-red "Wrong variant provided: supported variants: release, debug !!!"
        return -1
    }

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return ${rc}
    }

    [[ "${DOCKER_IMAGE_PATH}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH}" ]                    && {
        mkdir -p ${DOCKER_IMAGE_PATH}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH} !!!"
            return ${rc}
        }
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        rsync -aP ${DOCKER_IMAGE_PATH}/qimsdk_dev_artifacts_${VARIANT}.tar .                    && \
                qimsdk-device-command "mkdir -p /tmp/qti/development" ${QIMSDK_DEVICE_ID}       && \
                adb push qimsdk_dev_artifacts_${VARIANT}.tar /tmp/qti/development/              && \
                qimsdk-device-command "cd /tmp/qti/development                                  && \
                        tar -xf /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar        && \
                        docker cp usr ${QIMSDK_CONTAINER_NAME}:/" ${QIMSDK_DEVICE_ID}           && \
                qimsdk-device-command "rm -rf /tmp/qti/development/usr"                            \
                        ${QIMSDK_DEVICE_ID}                                                     || {
            print-red "Artifacts load failed !!!"

            qimsdk-device-command "rm -rf /tmp/qti/development/usr"
            qimsdk-device-command "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"

            rm -f qimsdk_dev_artifacts_${VARIANT}.tar

            return -1
        }

        qimsdk-device-command "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"
        rm -f qimsdk_dev_artifacts_${VARIANT}.tar
    )

    echo "Dev ${VARIANT} artifacts loaded from ${DOCKER_IMAGE_PATH}"
}

# Load release artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dev-load-artifacts() {
    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-dev-load-artifacts-variant ${PATH_TO_CONFIG_JSON} release
}

# Load debug artifacts from Docker_image_path provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dev-load-artifacts-dbg() {
    local PATH_TO_CONFIG_JSON=${1}
    qimsdk-dev-load-artifacts-variant ${PATH_TO_CONFIG_JSON} debug
}

QIMSDK_DOCKER_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"

source ${QIMSDK_DOCKER_DIR}/scripts/common.sh

print-green "Docker build environment setup"
echo "=============================="
print-yellow "Device Docker Commands"
echo        "======================"
print-green "qimsdk-docker-build-image                                        <path-to-config-json>"
echo "    Build docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR}"
print-blue "qimsdk-docker-device-update-image                                 <path-to-config-json>"
echo "    Update selected device image to the device"
print-blue "qimsdk-docker-device-save-image                                   <path-to-config-json>"
echo "    Save selected device image, compose file and run command"
print-blue "qimsdk-docker-device-load-image                                   <path-to-config-json>"
echo "    Loads device image on the device"
print-blue "qimsdk-docker-device-run-cdi-container                            <path-to-config-json>"
echo "    Run device container in CDI mode"
print-blue "qimsdk-docker-device-rm-container                                 <path-to-config-json>"
echo "    Remove device container"
print-blue "qimsdk-docker-device-start-container                              <path-to-config-json>"
echo "    Start device container"
print-blue "qimsdk-docker-device-stop-container                               <path-to-config-json>"
echo "    Stop device container"
print-blue "qimsdk-docker-device-command                                <path-to-config-json> <CMD>"
echo "    Execute CMD in device container"
print-blue "qimsdk-docker-device-shell                                        <path-to-config-json>"
echo "    Start shell in the docker container on the device"
print-red "qimsdk-docker-device-images-cleanup                                <path-to-config-json>"
echo "    Docker device images clean up"
print-red "qimsdk-docker-host-images-cleanup"
echo "    Docker host images clean up"
echo        "==================="
print-yellow "Dev Docker Commands"
echo        "==================="
print-green "qimsdk-dev-docker-build-image                                    <path-to-config-json>"
echo "    Build dev Docker image"
print-blue "qimsdk-dev-docker-run-container                                   <path-to-config-json>"
echo "    Run dev Docker container"
print-blue "qimsdk-dev-send-artifacts-to-device                               <path-to-config-json>"
echo "    Copy artifacts directly to /tmp/qti/development/ path in device"
print-blue "qimsdk-dev-save-artifacts                                         <path-to-config-json>"
echo "    Save artifacts to Docker_image_path provided in config json file."
print-blue "qimsdk-dev-save-artifacts-dbg                                     <path-to-config-json>"
echo "    Save debug artifacts to Docker_image_path provided in config json file."
print-blue "qimsdk-dev-load-artifacts                                         <path-to-config-json>"
echo "    Load artifacts from Docker_image_path provided in config json file."
print-blue "qimsdk-dev-load-artifacts-dbg                                     <path-to-config-json>"
echo "    Load debug artifacts from Docker_image_path provided in config json file."
