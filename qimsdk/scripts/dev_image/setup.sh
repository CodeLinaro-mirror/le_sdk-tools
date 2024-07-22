#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# git am wrapper function
#   $1 - Path to patch file
function qimsdk-aplly-patch() {
    local PATCH_FILE=${1}

    git am ${PATCH_FILE} || {
        echo "Failed to apply patch ${PATCH_FILE}!" && return -1
    }
}

# Wrapper function to apply qti patches to all needed opensource libs
function qimsdk-aplly-patches() {
    qimsdk-apply-patches-wayland-protocols-1-25                                                 && \
            qimsdk-apply-patches-gst-plugins-good-1-20-7                                        && \
            qimsdk-apply-patches-gst-plugins-bad-1-20-7
}

# Apply patches to wayland-protocols-1.25
function qimsdk-apply-patches-wayland-protocols-1-25() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25" ] && (
        local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/wayland-protocols-1.25"
        local WAYLAND_PATCHES=$(cat ${QIMSDK_RECIPES_JSON} | jq '.wayland[]' | tr -d '"')

        cd ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25

        for PATCH in ${WAYLAND_PATCHES}; do
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/${PATCH}
        done
    ) || {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25 !"
        return -1
    }
}

# Apply patches to gst-plugins-good-1.20.7
function qimsdk-apply-patches-gst-plugins-good-1-20-7() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7" ] && (
        local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/gst-plugins-good-1.20.7"

        local PLUGINS_GOOD_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.plugins_good[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7

        for PATCH in ${PLUGINS_GOOD_PATCHES}; do
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/${PATCH}
        done
    ) || {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7 !"
        return -1
    }
}

# Apply patches to gst-plugins-bad-1.20.7
function qimsdk-apply-patches-gst-plugins-bad-1-20-7() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7" ] && (
        local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/gst-plugins-bad-1.20.7"

        local PLUGINS_BAD_PATCHES=$(
            cat ${QIMSDK_RECIPES_JSON} | jq '.plugins_bad[]' | tr -d '"'
        )

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7

        for PATCH in ${PLUGINS_BAD_PATCHES}; do
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/${PATCH}
        done
    ) || {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7 !"
        return -1
    }
}
