#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Register layer
QIMSDK_ALL_LAYERS+=("gst-plugins-qti")

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

    # Remove gstreamer from BBMASK
    sed -i "s/meta\/recipes-multimedia\/gstreamer\///g" ${QIMSDK_ESDK_BASE_FOLDER}/conf/local.conf

    # Use kernel headers dir from local sysroot
    sed -i "s/\${STAGING_KERNEL_BUILDDIR}/\${STAGING_INCDIR}\/linux-msm/g" ${QIMSDK_BASE_FOLDER}/poky/meta-qti-gst/recipes/gstreamer/*.bb*

    # Remove not needed dependency to kernel workdir
    sed -i "s/do_configure\[depends\] += \"virtual\/kernel:do_shared_workdir\"//g" ${QIMSDK_BASE_FOLDER}/poky/meta-qti-gst/recipes/gstreamer/*.bb*

    # Setup tf lite prebuilt, if available
    [ "${QIMSDK_ESDK_TFLITE_FILE}" != "no-tflite-dev-archive-available" ]                       && \
        {
            sed -i "s/DEPENDS += \"tensorflow-lite\"/DEPENDS += \"tensorflow-lite-prebuilt\"\\ndo_configure[depends] += \"tensorflow-lite-prebuilt:do_package_write_ipk\"/g" ${QIMSDK_BASE_FOLDER}/poky/meta-qti-gst/recipes/gstreamer/*.bb*
        }

    # Setup snpe dir, if available
    [ "${QIMSDK_ESDK_SNPE_DIR}" != "no-snpe-dir-available" ]                       && \
        {
            mkdir -p /mnt/qimsdk/esdk/layers/poky/meta-qti-ml-prop/recipes/snpe-sdk/files/snpe
            cp -r ${QIMSDK_ESDK_BASE_FOLDER}/downloads/${QIMSDK_ESDK_SNPE_DIR}/* /mnt/qimsdk/esdk/layers/poky/meta-qti-ml-prop/recipes/snpe-sdk/files/snpe
            rm -f ${QIMSDK_ESDK_BASE_FOLDER}/layers/poky/meta-qti-ml-prop/recipes/snpe-sdk/files/snpe/lib/aarch64-oe-linux-gcc8.2/libatomic.so.1
        }

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
