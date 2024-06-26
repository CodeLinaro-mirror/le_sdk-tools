#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

echo "Docker build environment setup"
echo "=============================="

# Parse json configuraiton
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) variable to take base image value
#   $3 - (mandatory) variable to take container name value
#   $4 - (mandatory) variable to take image name value
#   $5 - (mandatory) variable to take Gstreamer sources of SP
#   $6 - (mandatory) variable to take path to snpe sdk
#   $7 - (mandatory) variable to take path to qnn sdk
#   $8 - (mandatory) variable to take path to tflite dev package
#   $9 - (mandatory) variable to take path to wayland protocols
#   $10 - (mandatory) variable to take path to gst plugins bad
#   $11 - (mandatory) variable to take path to gst plugins good
#   $12 - (mandatory) variable to take path to eSDK
function qimsdk-docker-parse-json() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_BASE_IMAGE=${2}
    local -n OUT_QIMSDK_CONTAINER_NAME=${3}
    local -n OUT_QIMSDK_IMAGE_NAME=${4}
    local -n OUT_QIMSDK_GST_SOURCES=${5}
    local -n OUT_QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK=${6}
    local -n OUT_QIMSDK_PATH_TO_UNZIPPED_QNN_SDK=${7}
    local -n OUT_QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE=${8}
    local -n OUT_QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR=${9}
    local -n OUT_QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR=${10}
    local -n OUT_QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR=${11}
    local -n OUT_QIMSDK_PATH_TO_eSDK_DIR=${12}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QIMSDK_BASE_IMAGE=$(echo ${JSON_CONTENT} | jq '.Base_Image' | tr -d '"')

    [ -z "${QIMSDK_BASE_IMAGE}" ] && {
        print-red "Base_Image tag in json file must be set !!!"
        return -2
    }

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

    OUT_QIMSDK_GST_SOURCES=$(echo ${JSON_CONTENT} | jq '.Gst_Source_Dir' | tr -d '"')
    OUT_QIMSDK_GST_SOURCES=${OUT_QIMSDK_GST_SOURCES%/}

    [ -d "${OUT_QIMSDK_GST_SOURCES}/.git" ]                                                     || \
        [ -d "${OUT_QIMSDK_GST_SOURCES}/gst-plugin-base" ]                                      || \
            {
                print-red "Please provide path to gst-plugins-qti-oss directory in config json!!!"
                print-red "Directory currently provided: ${OUT_QIMSDK_GST_SOURCES}"
                return -3
            }

    OUT_QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK=$(
        echo ${JSON_CONTENT} | jq '.Path_to_unzipped_snpe_sdk_dir' | tr -d '"'
    )

    [ -z "${OUT_QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK}" ] && {
        OUT_QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK="no-snpe-sdk-provided"
    }

    OUT_QIMSDK_PATH_TO_UNZIPPED_QNN_SDK=$(
        echo ${JSON_CONTENT} | jq '.Path_to_unzipped_qnn_sdk_dir' | tr -d '"'
    )

    [ -z "${OUT_QIMSDK_PATH_TO_UNZIPPED_QNN_SDK}" ] && {
        OUT_QIMSDK_PATH_TO_UNZIPPED_QNN_SDK="no-qnn-sdk-provided"
    }

    OUT_QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE=$(
        echo ${JSON_CONTENT} | jq '.Path_to_tflite_dev_package' | tr -d '"'
    )

    [ -z "${OUT_QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE}" ] && {
        OUT_QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE="no-tflite-provided"
    }

    OUT_QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR=$(
        echo ${JSON_CONTENT} | jq '.Path_to_wayland_protocols_dir' | tr -d '"'
    )

    [ ! -d "${OUT_QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR}" ] && {
        OUT_QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR="no-wayland-protocols-provided"
    }

    OUT_QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR=$(
        echo ${JSON_CONTENT} | jq '.Path_to_gst_plugins_bad_dir' | tr -d '"'
    )

    [ ! -d "${OUT_QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR}" ] && {
        OUT_QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR="no-gst-plugins-bad-provided"
    }

    OUT_QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR=$(
        echo ${JSON_CONTENT} | jq '.Path_to_gst_plugins_good_dir' | tr -d '"'
    )

    [ ! -d "${OUT_QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR}" ] && {
        OUT_QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR="no-gst-plugins-good-provided"
    }

    OUT_QIMSDK_PATH_TO_eSDK_DIR=$(
        echo ${JSON_CONTENT} | jq '.Path_to_eSDK_dir' | tr -d '"'
    )

    [ ! -d "${OUT_QIMSDK_PATH_TO_eSDK_DIR}" ] && {
        OUT_QIMSDK_PATH_TO_eSDK_DIR="no-eSDK-provided"

        print-yellow "The Path_to_eSDK_dir attribute is filled wrong in config json!"
        print-red "Please provide path to unarchived eSDK directory in config json!!!"

        return -4
    }

    return 0
}

# Build dev docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function qimsdk-dev-docker-build-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_BASE_IMAGE
    local QIMSDK_PACKAGES_TMP_DIR
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_GST_SOURCES
    local QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK
    local QIMSDK_PATH_TO_UNZIPPED_QNN_SDK
    local QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE
    local QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR
    local QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR
    local QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR
    local QIMSDK_PATH_TO_eSDK_DIR
    local URL

    qimsdk-docker-parse-json ${PATH_TO_CONFIG_JSON}                                                \
            QIMSDK_BASE_IMAGE                                                                      \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                      \
            QIMSDK_GST_SOURCES                                                                     \
            QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK                                                       \
            QIMSDK_PATH_TO_UNZIPPED_QNN_SDK                                                        \
            QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE                                                      \
            QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR                                                   \
            QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR                                                     \
            QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR                                                    \
            QIMSDK_PATH_TO_eSDK_DIR

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-docker-parse-json !!!"
        rm -rf ${QIMSDK_PACKAGES_TMP_DIR}
        return $rc
    }

    qimsdk-get-url ${PATH_TO_CONFIG_JSON} URL

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-url !!!"
        return $rc
    }

    local QIMSDK_TMP_FOLDER="${QIMSDK_DOCKER_DIR}/tmp"
    mkdir -p ${QIMSDK_TMP_FOLDER}

    rsync -a ${QIMSDK_GST_SOURCES} ${QIMSDK_TMP_FOLDER}/gst-plugins-qti-oss

    QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK=${QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK%/}
    [ "${QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK}" == "no-snpe-sdk-provided" ]                         && \
        {
            touch ${QIMSDK_TMP_FOLDER}/${QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK}
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK}/include/SNPE ${QIMSDK_TMP_FOLDER}/
        }

    QIMSDK_PATH_TO_UNZIPPED_QNN_SDK=${QIMSDK_PATH_TO_UNZIPPED_QNN_SDK%/}
    [ "${QIMSDK_PATH_TO_UNZIPPED_QNN_SDK}" == "no-qnn-sdk-provided" ]                           && \
        {
            touch ${QIMSDK_TMP_FOLDER}/${QIMSDK_PATH_TO_UNZIPPED_QNN_SDK}
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_PATH_TO_UNZIPPED_QNN_SDK}/include/QNN ${QIMSDK_TMP_FOLDER}/
        }

    [ "${QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE}" == "no-tflite-provided" ]                          && \
        {
            touch ${QIMSDK_TMP_FOLDER}/${QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE}
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE} ${QIMSDK_TMP_FOLDER}/tflite-dev.deb
        }

    local QIMSDK_GET_PATCHED_SOURCES_FROM="gitlab"

    QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR=${QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR%/}
    [ ! "${QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR}" == "no-wayland-protocols-provided" ]          && \
        {
            rsync -a ${QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR} ${QIMSDK_TMP_FOLDER}/
            QIMSDK_GET_PATCHED_SOURCES_FROM="host"
        }                                                                                       || \
        {
            QIMSDK_GET_PATCHED_SOURCES_FROM="gitlab"
        }

    QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR=${QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR%/}
    [ ! "${QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR}" == "no-gst-plugins-bad-provided" ]              && \
        {
            rsync -a ${QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR} ${QIMSDK_TMP_FOLDER}/
            QIMSDK_GET_PATCHED_SOURCES_FROM="host"
        }                                                                                       || \
        {
            QIMSDK_GET_PATCHED_SOURCES_FROM="gitlab"
        }

    QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR=${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR%/}
    [ ! "${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR}" == "no-gst-plugins-good-provided" ]            && \
        {
            rsync -a ${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR} ${QIMSDK_TMP_FOLDER}/
            QIMSDK_GET_PATCHED_SOURCES_FROM="host"
        }                                                                                       || \
        {
            QIMSDK_GET_PATCHED_SOURCES_FROM="gitlab"
        }

    QIMSDK_PATH_TO_eSDK_DIR=${QIMSDK_PATH_TO_eSDK_DIR%/}
    [ ! "${QIMSDK_PATH_TO_eSDK_DIR}" == "no-eSDK-provided" ]                                    && \
        {

            local PATH_TO_GST_PLUGINS_GOOD_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qti-gst/recipes-gst/gstreamer/gstreamer1.0-plugins-good/1.20/"

            [ ! -d ${PATH_TO_GST_PLUGINS_GOOD_PATCHES} ]                                        && \
                PATH_TO_GST_PLUGINS_GOOD_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qcom-qim-product-sdk/recipes-gst/gstreamer/gstreamer1.0-plugins-good/1.20/"

            [ ! -d ${PATH_TO_GST_PLUGINS_GOOD_PATCHES} ]                                        && \
                {
                    print-red "gstreamer-plugins-good's patches NOT found !!!"
                    return -1
                }

            local PATH_TO_GST_PLUGINS_BAD_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qti-gst/recipes-gst/gstreamer/gstreamer1.0-plugins-bad/1.20.4/"

            [ ! -d ${PATH_TO_GST_PLUGINS_BAD_PATCHES} ]                                         && \
                PATH_TO_GST_PLUGINS_BAD_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qcom-qim-product-sdk/recipes-gst/gstreamer/gstreamer1.0-plugins-bad/1.20/"

            [ ! -d ${PATH_TO_GST_PLUGINS_BAD_PATCHES} ]                                         && \
                {
                    print-red "gstreamer-plugins-bad's patches NOT found !!!"
                    return -2
                }

            local PATH_TO_WAYLAND_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qti-display/recipes-graphics/wayland/wayland-protocols/"

            [ ! -d ${PATH_TO_WAYLAND_PATCHES} ]                                                 && \
                PATH_TO_WAYLAND_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qcom-hwe/recipes-graphics/wayland/wayland-protocols/"

            [ ! -d ${PATH_TO_WAYLAND_PATCHES} ]                                                 && \
                {
                    print-red "wayland-protocol's patches NOT found !!!"
                    return -3
                }

            pushd ${QIMSDK_PATH_TO_eSDK_DIR}/tmp/sysroots/qcm6490/ 1>/dev/null                  || \
                {
                    print-red "FAILED: pushd to Path_to_eSDK_dir"
                    return -4
                }

                mkdir -p "${QIMSDK_TMP_FOLDER}/`
                    `headers/usr/share/wayland-protocols/stable/gbm-buffer-backend/"            && \

                rsync -a ./usr/share/libweston-10/protocols/gbm-buffer-backend.xml                 \
                    ${QIMSDK_TMP_FOLDER}/headers/usr/share/wayland-protocols/stable/`
                        `gbm-buffer-backend/                                                    && \

                rsync -aR ./usr/include/fastcv/fastcv.h                                            \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               && \
                rsync -aR ./usr/include/iot-core-algs/ib2c.h                                       \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               && \
                rsync -aR ./usr/include/display/media/mmm_color_fmt.h                              \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               && \
                rsync -aR ./usr/include/gbm_priv.h                                                 \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               && \
                rsync -aR ./usr/include/CL/cl_ext_qcom.h                                           \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               || \
                    {
                        echo "Something Went Wrong !!!"
                        popd 1>/dev/null
                        return -5
                    }

            popd 1>/dev/null                                                                    && \

            mkdir -p ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-bad-1.20.7/                       && \
            mkdir -p ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-good-1.20.7/                      && \
            mkdir -p ${QIMSDK_TMP_FOLDER}/patches/wayland-protocols-1.25/                       && \

            rsync -a ${QIMSDK_PATH_TO_eSDK_DIR}/layers/poky/meta/recipes-multimedia/gstreamer/`
                `gstreamer1.0-plugins-bad/*.patch                                                  \
                ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-bad-1.20.7/                            && \

            rsync -a ${PATH_TO_GST_PLUGINS_BAD_PATCHES}/*.patch                                    \
                ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-bad-1.20.7/                            && \

            rsync -a ${QIMSDK_PATH_TO_eSDK_DIR}/layers/poky/meta/recipes-multimedia/gstreamer/`
                `gstreamer1.0-plugins-good/*.patch                                                 \
                ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-good-1.20.7/                           && \

            rsync -a ${PATH_TO_GST_PLUGINS_GOOD_PATCHES}/*.patch                                   \
                ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-good-1.20.7/                           && \

            rsync -a ${PATH_TO_WAYLAND_PATCHES}/*.patch                                            \
                ${QIMSDK_TMP_FOLDER}/patches/wayland-protocols-1.25/                            || \
                {
                    print-red "Something get wrong!!!"
                    return -5
                }
        }

    local QIMSDK_WAYLAND_PROTOCOLS_BASENAME=$(basename ${QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR})
    local QIMSDK_GST_PLUGINS_BAD_BASENAME=$(basename   ${QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR})
    local QIMSDK_GST_PLUGINS_GOOD_BASENAME=$(basename  ${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR})

    local ABSOLUTE_PATH_TO_CONFIG_JSON=$(readlink -f ${PATH_TO_CONFIG_JSON})

    python3 ${QIMSDK_DOCKER_DIR}/scripts/tools/RecipeParser.py                                     \
        -l ${QIMSDK_PATH_TO_eSDK_DIR}/layers/                                                      \
        -j ${ABSOLUTE_PATH_TO_CONFIG_JSON}                                                         \
        -t ${QIMSDK_TMP_FOLDER}

    local QIMSDK_BASE_DIR="/mnt/work"

    DOCKER_BUILDKIT=1 docker build                                                                 \
            --build-arg QIMSDK_ARG_BASE_IMAGE=${QIMSDK_BASE_IMAGE}                                 \
            --build-arg QIMSDK_ARG_BASE_DIR=${QIMSDK_BASE_DIR}                                     \
            --build-arg QIMSDK_ARG_URL=${URL}                                                      \
            --build-arg QIMSDK_ARG_WAYLAND_PROTOCOLS_DIR=${QIMSDK_WAYLAND_PROTOCOLS_BASENAME}      \
            --build-arg QIMSDK_ARG_GST_PLUGINS_BAD_DIR=${QIMSDK_GST_PLUGINS_BAD_BASENAME}          \
            --build-arg QIMSDK_ARG_GST_PLUGINS_GOOD_DIR=${QIMSDK_GST_PLUGINS_GOOD_BASENAME}        \
            --build-arg QIMSDK_ARG_PATCHED_SOURCES=${QIMSDK_GET_PATCHED_SOURCES_FROM}              \
            --progress=plain --target QIMSDK_dev_image                                             \
            ${QIMSDK_DOCKER_DIR} -t ${QIMSDK_IMAGE_NAME}_dev

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Build image failed !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return $rc
    }

    rm -rf ${QIMSDK_TMP_FOLDER}

    print-green "Build image completed successfully !!!"

    return 0
}

# Build docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function qimsdk-docker-build-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_BASE_IMAGE
    local QIMSDK_PACKAGES_TMP_DIR
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_GST_SOURCES
    local QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK
    local QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE
    local QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR
    local QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR
    local QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR
    local QIMSDK_PATH_TO_eSDK_DIR

    qimsdk-docker-parse-json ${PATH_TO_CONFIG_JSON}                                                \
            QIMSDK_BASE_IMAGE                                                                      \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME                                                                      \
            QIMSDK_GST_SOURCES                                                                     \
            QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK                                                       \
            QIMSDK_PATH_TO_UNZIPPED_QNN_SDK                                                        \
            QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE                                                      \
            QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR                                                   \
            QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR                                                     \
            QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR                                                    \
            QIMSDK_PATH_TO_eSDK_DIR

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-docker-parse-json !!!"
        rm -rf ${QIMSDK_PACKAGES_TMP_DIR}
        return $rc
    }

    local QIMSDK_TMP_FOLDER="${QIMSDK_DOCKER_DIR}/tmp"
    mkdir -p ${QIMSDK_TMP_FOLDER}

    rsync -a ${QIMSDK_GST_SOURCES} ${QIMSDK_TMP_FOLDER}/gst-plugins-qti-oss

    QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK=${QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK%/}
    [ "${QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK}" == "no-snpe-sdk-provided" ]                         && \
        {
            touch ${QIMSDK_TMP_FOLDER}/${QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK}
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_PATH_TO_UNZIPPED_SNPE_SDK}/include/SNPE ${QIMSDK_TMP_FOLDER}/
        }

    QIMSDK_PATH_TO_UNZIPPED_QNN_SDK=${QIMSDK_PATH_TO_UNZIPPED_QNN_SDK%/}
    [ "${QIMSDK_PATH_TO_UNZIPPED_QNN_SDK}" == "no-qnn-sdk-provided" ]                           && \
        {
            touch ${QIMSDK_TMP_FOLDER}/${QIMSDK_PATH_TO_UNZIPPED_QNN_SDK}
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_PATH_TO_UNZIPPED_QNN_SDK}/include/QNN ${QIMSDK_TMP_FOLDER}/
        }

    [ "${QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE}" == "no-tflite-provided" ]                          && \
        {
            touch ${QIMSDK_TMP_FOLDER}/${QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE}
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_PATH_TO_TFLITE_DEV_PACKAGE} ${QIMSDK_TMP_FOLDER}/tflite-dev.deb
        }

    local QIMSDK_GET_PATCHED_SOURCES_FROM="gitlab"

    QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR=${QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR%/}
    [ ! "${QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR}" == "no-wayland-protocols-provided" ]          && \
        {
            rsync -a ${QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR} ${QIMSDK_TMP_FOLDER}/
            QIMSDK_GET_PATCHED_SOURCES_FROM="host"
        }                                                                                       || \
        {
            QIMSDK_GET_PATCHED_SOURCES_FROM="gitlab"
        }

    QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR=${QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR%/}
    [ ! "${QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR}" == "no-gst-plugins-bad-provided" ]              && \
        {
            rsync -a ${QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR} ${QIMSDK_TMP_FOLDER}/
            QIMSDK_GET_PATCHED_SOURCES_FROM="host"
        }                                                                                       || \
        {
            QIMSDK_GET_PATCHED_SOURCES_FROM="gitlab"
        }

    QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR=${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR%/}
    [ ! "${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR}" == "no-gst-plugins-good-provided" ]            && \
        {
            rsync -a ${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR} ${QIMSDK_TMP_FOLDER}/
            QIMSDK_GET_PATCHED_SOURCES_FROM="host"
        }                                                                                       || \
        {
            QIMSDK_GET_PATCHED_SOURCES_FROM="gitlab"
        }

    QIMSDK_PATH_TO_eSDK_DIR=${QIMSDK_PATH_TO_eSDK_DIR%/}
    [ ! "${QIMSDK_PATH_TO_eSDK_DIR}" == "no-eSDK-provided" ]                                    && \
        {

            local PATH_TO_GST_PLUGINS_GOOD_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qti-gst/recipes-gst/gstreamer/gstreamer1.0-plugins-good/1.20/"

            [ ! -d ${PATH_TO_GST_PLUGINS_GOOD_PATCHES} ]                                        && \
                PATH_TO_GST_PLUGINS_GOOD_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qcom-qim-product-sdk/recipes-gst/gstreamer/gstreamer1.0-plugins-good/1.20/"

            [ ! -d ${PATH_TO_GST_PLUGINS_GOOD_PATCHES} ]                                        && \
                {
                    print-red "gstreamer-plugins-good's patches NOT found !!!"
                    return -1
                }

            local PATH_TO_GST_PLUGINS_BAD_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qti-gst/recipes-gst/gstreamer/gstreamer1.0-plugins-bad/1.20.4/"

            [ ! -d ${PATH_TO_GST_PLUGINS_BAD_PATCHES} ]                                         && \
                PATH_TO_GST_PLUGINS_BAD_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qcom-qim-product-sdk/recipes-gst/gstreamer/gstreamer1.0-plugins-bad/1.20/"

            [ ! -d ${PATH_TO_GST_PLUGINS_BAD_PATCHES} ]                                         && \
                {
                    print-red "gstreamer-plugins-bad's patches NOT found !!!"
                    return -2
                }

            local PATH_TO_WAYLAND_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qti-display/recipes-graphics/wayland/wayland-protocols/"

            [ ! -d ${PATH_TO_WAYLAND_PATCHES} ]                                                 && \
                PATH_TO_WAYLAND_PATCHES="${QIMSDK_PATH_TO_eSDK_DIR}/layers/`
                `meta-qcom-hwe/recipes-graphics/wayland/wayland-protocols/"

            [ ! -d ${PATH_TO_WAYLAND_PATCHES} ]                                                 && \
                {
                    print-red "wayland-protocol's patches NOT found !!!"
                    return -3
                }

            pushd ${QIMSDK_PATH_TO_eSDK_DIR}/tmp/sysroots/qcm6490/ 1>/dev/null                  || \
                {
                    print-red "FAILED: pushd to Path_to_eSDK_dir"
                    return -4
                }

                mkdir -p "${QIMSDK_TMP_FOLDER}/`
                    `headers/usr/share/wayland-protocols/stable/gbm-buffer-backend/"            && \

                rsync -a ./usr/share/libweston-10/protocols/gbm-buffer-backend.xml                 \
                    ${QIMSDK_TMP_FOLDER}/headers/usr/share/wayland-protocols/stable/`
                        `gbm-buffer-backend/                                                    && \

                rsync -aR ./usr/include/fastcv/fastcv.h                                            \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               && \
                rsync -aR ./usr/include/iot-core-algs/ib2c.h                                       \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               && \
                rsync -aR ./usr/include/display/media/mmm_color_fmt.h                              \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               && \
                rsync -aR ./usr/include/gbm_priv.h                                                 \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               && \
                rsync -aR ./usr/include/CL/cl_ext_qcom.h                                           \
                    ${QIMSDK_TMP_FOLDER}/headers/                                               || \
                    {
                        echo "Something Went Wrong !!!"
                        popd 1>/dev/null
                        return -5
                    }

            popd 1>/dev/null                                                                    && \

            mkdir -p ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-bad-1.20.7/                       && \
            mkdir -p ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-good-1.20.7/                      && \
            mkdir -p ${QIMSDK_TMP_FOLDER}/patches/wayland-protocols-1.25/                       && \

            rsync -a ${QIMSDK_PATH_TO_eSDK_DIR}/layers/poky/meta/recipes-multimedia/gstreamer/`
                `gstreamer1.0-plugins-bad/*.patch                                                  \
                ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-bad-1.20.7/                            && \

            rsync -a ${PATH_TO_GST_PLUGINS_BAD_PATCHES}/*.patch                                    \
                ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-bad-1.20.7/                            && \

            rsync -a ${QIMSDK_PATH_TO_eSDK_DIR}/layers/poky/meta/recipes-multimedia/gstreamer/`
                `gstreamer1.0-plugins-good/*.patch                                                 \
                ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-good-1.20.7/                           && \

            rsync -a ${PATH_TO_GST_PLUGINS_GOOD_PATCHES}/*.patch                                   \
                ${QIMSDK_TMP_FOLDER}/patches/gst-plugins-good-1.20.7/                           && \

            rsync -a ${PATH_TO_WAYLAND_PATCHES}/*.patch                                            \
                ${QIMSDK_TMP_FOLDER}/patches/wayland-protocols-1.25/                            || \
                {
                    print-red "Something get wrong!!!"
                    return -5
                }
        }

    local QIMSDK_WAYLAND_PROTOCOLS_BASENAME=$(basename ${QIMSDK_PATH_TO_WAYLAND_PROTOCOLS_DIR})
    local QIMSDK_GST_PLUGINS_BAD_BASENAME=$(basename   ${QIMSDK_PATH_TO_GST_PLUGINS_BAD_DIR})
    local QIMSDK_GST_PLUGINS_GOOD_BASENAME=$(basename  ${QIMSDK_PATH_TO_GST_PLUGINS_GOOD_DIR})

    local ABSOLUTE_PATH_TO_CONFIG_JSON=$(readlink -f ${PATH_TO_CONFIG_JSON})

    python3 ${QIMSDK_DOCKER_DIR}/scripts/tools/RecipeParser.py                                     \
        -l ${QIMSDK_PATH_TO_eSDK_DIR}/layers/                                                      \
        -j ${ABSOLUTE_PATH_TO_CONFIG_JSON}                                                         \
        -t ${QIMSDK_TMP_FOLDER}

    local QIMSDK_BASE_DIR="/mnt/work"

    DOCKER_BUILDKIT=1 docker build                                                                 \
            --build-arg QIMSDK_ARG_BASE_IMAGE=${QIMSDK_BASE_IMAGE}                                 \
            --build-arg QIMSDK_ARG_BASE_DIR=${QIMSDK_BASE_DIR}                                     \
            --build-arg QIMSDK_ARG_WAYLAND_PROTOCOLS_DIR=${QIMSDK_WAYLAND_PROTOCOLS_BASENAME}      \
            --build-arg QIMSDK_ARG_GST_PLUGINS_BAD_DIR=${QIMSDK_GST_PLUGINS_BAD_BASENAME}          \
            --build-arg QIMSDK_ARG_GST_PLUGINS_GOOD_DIR=${QIMSDK_GST_PLUGINS_GOOD_BASENAME}        \
            --build-arg QIMSDK_ARG_PATCHED_SOURCES=${QIMSDK_GET_PATCHED_SOURCES_FROM}              \
            --progress=plain --target QIMSDK_device_image                                          \
            ${QIMSDK_DOCKER_DIR} -t ${QIMSDK_IMAGE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Build image failed !!!"
        rm -rf ${QIMSDK_TMP_FOLDER}
        return $rc
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
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id !!!"
        return $rc
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    docker save ${QIMSDK_IMAGE_NAME}:latest -o ${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Device load image failed: docker save failed !!!"
        rm ${FILE_NAME}

        return $rc
    }

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qimsdk-device-command "mkdir -p /home/data/docker_images" ${QIMSDK_DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qimsdk-device-command !!!"
            rm ${FILE_NAME}

            return $rc
        }

        adb push ${FILE_NAME} /home/data/docker_images

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: adb push ${FILE_NAME} /home/data/docker_images !!!"
            rm ${FILE_NAME}

            return $rc
        }

        rm ${FILE_NAME}

        qimsdk-device-command "docker load -i /home/data/docker_images/${FILE_NAME}" ${QIMSDK_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return $rc
        }

        qimsdk-device-command "rm /home/data/docker_images/${FILE_NAME}" ${QIMSDK_DEVICE_ID}

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
function qimsdk-docker-device-save-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local URL

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    qimsdk-get-url ${PATH_TO_CONFIG_JSON} URL

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-url !!!"
        return $rc
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    docker save ${QIMSDK_IMAGE_NAME}:latest -o ${FILE_NAME}

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
function qimsdk-docker-device-load-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local URL
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    qimsdk-get-url ${PATH_TO_CONFIG_JSON} URL

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-url !!!"
        return $rc
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id !!!"
        return $rc
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    rsync -aP ${URL}/${FILE_NAME} ${FILE_NAME}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: rsync -aP ${URL}/${FILE_NAME} ${FILE_NAME}"
        rm ${FILE_NAME}

        return $rc
    }

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qimsdk-device-command "mkdir -p /home/data/docker_images" ${QIMSDK_DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qimsdk-device-command !!!"
            rm ${FILE_NAME}

            return $rc
        }

        adb push ${FILE_NAME} /home/data/docker_images

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: adb push ${FILE_NAME} /home/data/docker_images !!!"
            rm ${FILE_NAME}

            return $rc
        }

        rm ${FILE_NAME}

        qimsdk-device-command "docker load -i /home/data/docker_images/${FILE_NAME}" ${QIMSDK_DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "Device load image failed: docker load failed !!!"
            return $rc
        }

        qimsdk-device-command "rm /home/data/docker_images/${FILE_NAME}" ${QIMSDK_DEVICE_ID}

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
function qimsdk-dev-docker-run-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    docker run -it -d -h ${QIMSDK_CONTAINER_NAME}_dev --name ${QIMSDK_CONTAINER_NAME}_dev          \
        ${QIMSDK_IMAGE_NAME}_dev bash

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Run dev container failed !!!"
        return $rc
    }

    # Propagate ssh and gitconfig to container
    docker exec ${QIMSDK_CONTAINER_NAME}_dev mkdir /root/.ssh            || \
        {
            print-red "docker mkdir ~/.ssh failed !!!"
            return -4
        }

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp ${f} ${QIMSDK_CONTAINER_NAME}_dev:/root/.ssh/${BASE_NAME}         || \
                {
                    print-red "Propagating .ssh/ to docker failed !!!"
                    return -5
                }
        done
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
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    docker run -it -d -h ${QIMSDK_CONTAINER_NAME} --name ${QIMSDK_CONTAINER_NAME}          \
        ${QIMSDK_IMAGE_NAME} bash

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "Run device container failed on pc emulator !!!"
        return $rc
    }

    # Propagate ssh and gitconfig to container
    docker exec ${QIMSDK_CONTAINER_NAME} mkdir /root/.ssh            || \
        {
            print-red "docker mkdir ~/.ssh failed !!!"
            return -4
        }

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp ${f} ${QIMSDK_CONTAINER_NAME}:/root/.ssh/${BASE_NAME}         || \
                {
                    print-red "Propagating .ssh/ to docker failed !!!"
                    return -5
                }
        done
    fi

    print-green "Run device container successful on pc emulator !!!"

    return 0
}

# Run selected device container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-device-run-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID
    local PLATFORM_SPECIFIC_MAP
    local PLATFORM_LIBS_TO_MOUNT

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return $rc
    }

    qimsdk-get-platform-specific-mapping ${PATH_TO_CONFIG_JSON} PLATFORM_SPECIFIC_MAP

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-platform-specific-mapping  !!!"
        return $rc
    }

    qimsdk-get-platform-libs-to-mount ${PATH_TO_CONFIG_JSON} PLATFORM_LIBS_TO_MOUNT

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-platform-specific-mapping  !!!"
        return $rc
    }
    (

        echo "docker run -it -d ${PLATFORM_SPECIFIC_MAP} ${PLATFORM_LIBS_TO_MOUNT}                 \
             -h ${QIMSDK_CONTAINER_NAME} --name ${QIMSDK_CONTAINER_NAME} ${QIMSDK_IMAGE_NAME}      \
             " > /tmp/docker_run.sh
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}
        adb push /tmp/docker_run.sh /tmp/
        qimsdk-device-command "source /tmp/docker_run.sh"                                       || \
            {
                rm -rf /tmp/docker_run.sh
                qimsdk-device-command "rm -rf /tmp/docker_run.sh"
                echo "qimsdk-docker-device-run-container failed !!!"
                return -1
            }
        rm -rf /tmp/docker_run.sh
        qimsdk-device-command "rm -rf /tmp/docker_run.sh"
    )

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
function qimsdk-docker-device-rm-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return $rc
    }

    qimsdk-device-command "docker rm ${QIMSDK_CONTAINER_NAME}" ${QIMSDK_DEVICE_ID}

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
function qimsdk-docker-device-start-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return $rc
    }

    qimsdk-device-command "docker start ${QIMSDK_CONTAINER_NAME}" ${QIMSDK_DEVICE_ID}

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
function qimsdk-docker-device-stop-container() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return $rc
    }

    qimsdk-device-command "docker stop ${QIMSDK_CONTAINER_NAME}" ${QIMSDK_DEVICE_ID}

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
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return $rc
    }

    qimsdk-device-command "docker exec ${QIMSDK_CONTAINER_NAME} bash -c ${CMD}" ${QIMSDK_DEVICE_ID}
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-device-command !!!"
        return $rc
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
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return $rc
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return $rc
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
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return $rc
    }

    local DEVICE_DOCKER_IMAGES=$(
        qimsdk-device-command "docker images -f 'dangling=true' -q" ${QIMSDK_DEVICE_ID}
    )

    qimsdk-device-command "docker rmi ${DEVICE_DOCKER_IMAGES}" ${QIMSDK_DEVICE_ID}

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-device-command !!!"
        return $rc
    }

    print-green "Device docker images cleanup complete !!!"

    return 0
}

# Docker host images clean up
function qimsdk-docker-host-images-cleanup() {
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

# Copy artifacts directly to path in device
#   $1 - (mandatory) path to target config json
function qimsdk-dev-send-artifacts-to-device() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_DEVICE_ID
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return $rc
    }

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    docker cp ${QIMSDK_CONTAINER_NAME}_dev:/mnt/work/deploy /tmp/.

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qimsdk-device-command "mkdir -p /opt/qti/development" ${QIMSDK_DEVICE_ID}

        adb push --sync /tmp/deploy/usr /opt/qti/development/

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: adb push /tmp/deploy/usr /opt/qti/development/ !!!"
            rm -rf /tmp/deploy

            return $rc
        }

        rm -rf /tmp/deploy
    )

    echo "Dev artifacts saved to device ${QIMSDK_DEVICE_ID}"
}

# Save artifacts to URL provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dev-save-artifacts() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local URL

    qimsdk-get-url ${PATH_TO_CONFIG_JSON} URL

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-url !!!"
        return $rc
    }

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-device-id  !!!"
        return $rc
    }

    docker cp ${QIMSDK_CONTAINER_NAME}_dev:/mnt/work/deploy /tmp/.

    pushd /tmp/deploy/ > /dev/null
        tar cf qimsdk_dev_artifacts.tar ./*                                                     && \
            rsync -aP qimsdk_dev_artifacts.tar ${URL}                                           || \
            {
                echo "rsync -a qimsdk_dev_artifacts.tar ${URL} failed !!!"
                popd > /dev/null
                return -1
            }
        rm -f qimsdk_dev_artifacts.tar
    popd > /dev/null

    echo "Dev artifacts saved to ${URL}"
}

# Load artifacts from URL provided in config json file.
#   $1 - (mandatory) path to target config json
function qimsdk-dev-load-artifacts() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_DEVICE_ID
    local URL

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    qimsdk-get-url ${PATH_TO_CONFIG_JSON} URL

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-get-url !!!"
        return $rc
    }

    qimsdk-get-device-id ${PATH_TO_CONFIG_JSON} QIMSDK_DEVICE_ID

    (
        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        rsync -aP ${URL}/qimsdk_dev_artifacts.tar .                                             && \
            qimsdk-device-command "mkdir -p /opt/qti/development" ${QIMSDK_DEVICE_ID}           && \
            adb push qimsdk_dev_artifacts.tar /opt/qti/development/                             && \
            qimsdk-device-command "cd /opt/qti/development                                      && \
                tar -xf /opt/qti/development/qimsdk_dev_artifacts.tar                           && \
                docker cp usr ${QIMSDK_CONTAINER_NAME}:/" ${QIMSDK_DEVICE_ID}                   && \
            qimsdk-device-command "rm -rf /opt/qti/development/usr"                                \
                ${QIMSDK_DEVICE_ID}                                                             || \
            {
                print-red "Artifacts load failed !!!"

                qimsdk-device-command "rm -rf /opt/qti/development/usr"
                qimsdk-device-command "rm -f /opt/qti/development/qimsdk_dev_artifacts.tar"

                rm -f qimsdk_dev_artifacts.tar

                return -2
            }

        qimsdk-device-command "rm -f /opt/qti/development/qimsdk_dev_artifacts.tar"
        rm -f qimsdk_dev_artifacts.tar
    )

    echo "Dev artifacts loaded from ${URL}"
}

QIMSDK_DOCKER_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"

source ${QIMSDK_DOCKER_DIR}/scripts/common.sh

print-green "qimsdk-docker-build-image                                        <path-to-config-json>"
echo "    Build docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR}"
print-blue "qimsdk-docker-device-update-image                                 <path-to-config-json>"
echo "    Update selected device image to the device"
print-blue "qimsdk-docker-device-save-image                                   <path-to-config-json>"
echo "    Save selected device image"
print-blue "qimsdk-docker-device-load-image                                   <path-to-config-json>"
echo "    Loads device image on the device"
print-blue "qimsdk-docker-device-run-container                                <path-to-config-json>"
echo "    Run device container"
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
echo "qimsdk-dev-docker-build-image                                           <path-to-config-json>"
echo "    Build dev Docker image"
echo "qimsdk-dev-docker-run-container                                         <path-to-config-json>"
echo "    Run dev Docker container"
echo "qimsdk-dev-send-artifacts-to-device                                     <path-to-config-json>"
echo "    Copy artifacts directly to /opt/qti/development/ path in device"
echo "qimsdk-dev-save-artifacts                                               <path-to-config-json>"
echo "    Save artifacts to URL provided in config json file."
echo "qimsdk-dev-load-artifacts                                               <path-to-config-json>"
echo "    Load artifacts from URL provided in config json file."
