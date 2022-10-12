#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Register layer
QIMSDK_ALL_LAYERS+=("gst-plugins-qti")

# Sync gst-plugins-qti
function qimsdk-gst-plugins-qti-sync() {
    # Remove meta layers to be cloned
    rm -rf ${QIMSDK_BASE_FOLDER}/poky/meta-qti-gst*
    rm -rf ${QIMSDK_ESDK_BASE_FOLDER}/layers/src/vendor/qcom/opensource/gst-plugins-qti-oss

    #Remove gstreamer from BBMAKS
    sed -i "s/meta\/recipes-multimedia\/gstreamer\///g" ${QIMSDK_ESDK_BASE_FOLDER}/conf/local.conf

    [ "${QIMSDK_ESDK_TFLITE_FILE}" != "no-tflite-dev-archive-available" ]                       && \
        rm -rf ${QIMSDK_ESDK_BASE_FOLDER}/layers/poky/meta-qti-ml

    # Clone required repositories
    git clone "${QIMSDK_ESDK_SYNC_URL_PREFIX}"/platform/vendor/qcom-opensource/gst-plugins-qti-oss \
        ${QIMSDK_ESDK_BASE_FOLDER}/layers/src/vendor/qcom/opensource/gst-plugins-qti-oss           \
        --branch=LE.UM.6.4.2 --single-branch                                                    && \
    git clone "${QIMSDK_ESDK_SYNC_URL_PREFIX}"/meta-qti-gst                                        \
        ${QIMSDK_BASE_FOLDER}/poky/meta-qti-gst                                                    \
        --branch=LE.UM.6.4.2 --single-branch                                                    || \
        {
            print-red "git clone failed !!!";
            return -1;
        }

    # Setup tf lite prebuilt, if available
    [ "${QIMSDK_ESDK_TFLITE_FILE}" != "no-tflite-dev-archive-available" ]                       && \
        {
            rm -rf ${QIMSDK_ESDK_BASE_FOLDER}/layers/poky/meta-qti-ml
            git clone "${QIMSDK_ESDK_SYNC_URL_PREFIX}"/meta-qti-ml                                 \
                ${QIMSDK_ESDK_BASE_FOLDER}/layers/poky/meta-qti-ml                                 \
                --branch=iot-ml.lnx.3.0 --single-branch                                         || \
                {
                    print-red "git clone of meta-qti-ml failed !!!";
                    return -2;
                }
        }
    [ "${QIMSDK_ESDK_TFLITE_FILE}" != "no-tflite-dev-archive-available" ]                       && \
        sed -i "s/tensorflow-lite/tensorflow-lite-prebuilt/g" ${QIMSDK_BASE_FOLDER}/poky/meta-qti-gst/recipes/gstreamer/gstreamer1.0-plugins-qti-oss-mltflite.bb

    return 0
}

# Add meta-qti-gst layer
function qimsdk-gst-plugins-qti-add-layers() {
    qimsdk-bitbake-add-layers ${QIMSDK_BASE_FOLDER}/poky/meta-qti-gst
}

# Prepare all recipes in layer
function qimsdk-gst-plugins-qti-prepare-layer() {
    devtool modify gstreamer1.0-plugins-qti-oss-all
}

# Prepare gst-plugins-qti
function qimsdk-gst-plugins-qti-prepare() {
    qimsdk-gst-plugins-qti-add-layers                                                           && \
        qimsdk-gst-plugins-qti-prepare-layer
}

# Build gst-plugins-qti
function qimsdk-gst-plugins-qti-build() {
    devtool build gstreamer1.0-plugins-qti-oss-all
}

# Package gst-plugins-qti
function qimsdk-gst-plugins-qti-package() {
    # Build task of that recipe generates all ipk files for dependent packages
    devtool package gstreamer1.0-plugins-qti-oss-all
}

# Inspect plugins
function qimsdk-gst-plugins-qti-inspect() {
    # Detecting installed gst plugins
    echo "Detecting installed gst plugins ..."
    qimsdk-device-command "ls /usr/lib/gstreamer-1.0/libgst* > /data/plugin-list.txt" || return -1
    adb pull /data/plugin-list.txt ${QIMSDK_WORK_FOLDER}/ 2>&1 > /dev/null || return -2
    qimsdk-device-command "rm -f /data/plugin-list.txt"
    plugins=($(cat ${QIMSDK_WORK_FOLDER}/plugin-list.txt))
    rm -f ${QIMSDK_WORK_FOLDER}/plugin-list.txt

    # Inspecting installed gst plugins
    echo "Inspecting installed gst plugins ..."
    qimsdk-device-command "rm -f /data/gst-inspect-error-log.txt"
    for PLUGIN in ${plugins[@]}; do
        qimsdk-device-command "gst-inspect-1.0 ${PLUGIN} 1>/dev/null 2>>/data/gst-inspect-error-log.txt "
    done

    # Check output
    adb pull /data/gst-inspect-error-log.txt ${QIMSDK_WORK_FOLDER}/ 2>&1 > /dev/null
    [ -f ${QIMSDK_WORK_FOLDER}/gst-inspect-error-log.txt ]                                      && \
    [ `wc -c ${QIMSDK_WORK_FOLDER}/gst-inspect-error-log.txt | cut -d ' ' -f 1` -eq 0 ]         && \
        print-green "All gst plugins are inspected successfully !!!"                              ||
        {
            print-red "Gst inspection failed:";
            cat ${QIMSDK_WORK_FOLDER}/gst-inspect-error-log.txt
        }
    rm -f ${QIMSDK_WORK_FOLDER}/gst-inspect-error-log.txt
}
