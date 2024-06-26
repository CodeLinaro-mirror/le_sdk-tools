#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# git am wrapper function
#   $1 - Path to patch file
function qimsdk-aplly-patch() {
    local PATCH_FILE=${1}

    git am ${PATCH_FILE}                                                                        || \
        {
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
    [ -d "${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25" ]                                      && \
        (
            local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/wayland-protocols-1.25"
            cd ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25                                    && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0001-wayland-protocols-add-custom-position-support-in-xdg.patch
        )                                                                                       || \
        {
            echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25 !"
            return -1
        }
}

# Apply patches to gst-plugins-good-1.20.7
function qimsdk-apply-patches-gst-plugins-good-1-20-7() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7" ]                                     && \
        (
            local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/gst-plugins-good-1.20.7"
            cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0001-qt-include-ext-qt-gstqtgl.h-instead-of-gst-gl-gstglf.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0002-v4l2-Add-support-for-fd-memory-import.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0003-gstreamer1.0-plugins-good-modify-caps.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0004-v4l2-Add-support-for-dma-memory-allocation.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0005-v4l2-Add-support-for-dynamic-resolution-change.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0006-v4l2-support-for-controls-and-input-formats.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0007-v4l2-Handle-srccaps-and-GAP-buffer.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0008-gstreamer1.0-plugins-good-Add-meson-option-to-build-.patch
        )                                                                                       || \
        {
            echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7 !"
            return -1
        }
}

# Apply patches to gst-plugins-bad-1.20.7
function qimsdk-apply-patches-gst-plugins-bad-1-20-7() {
    [ -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7" ]                                      && \
        (
            local PATH_TO_PATCHES="${QIMSDK_PATCHES_DIR}/gst-plugins-bad-1.20.7"
            cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7                                    && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0001-fix-maybe-uninitialized-warnings-when-compiling-with.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0002-avoid-including-sys-poll.h-directly.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0003-ensure-valid-sentinals-for-gst_structure_get-etc.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0004-opencv-resolve-missing-opencv-data-dir-in-yocto-buil.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0005-videoparser-support-protected-content-caps.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0006-videoparser-update-width-and-height-on-resolution-ch.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/CVE-2023-40474.patch                          && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/CVE-2023-40475.patch                          && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/CVE-2023-40476.patch                          && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/CVE-2023-44429.patch                          && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0001-waylandsink-support-position-and-dimensions.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0002-waylandsink-support-scaler-protocol.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0003-waylandsink-support-gbm-buffer-backend-protocol.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0004-waylandsink-release-pending-buffers-in-composer.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0005-waylandsink-support-gap-buffers.patch    && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0006-waylandsink-increase-timeout-limitation-in-gst_wl_wi.patch && \
            qimsdk-aplly-patch ${PATH_TO_PATCHES}/0007-gstreamer1.0-plugins-bad-Add-meson-option-to-build-a.patch
        )                                                                                       || \
        {
            echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7 !"
            return -1
        }
}
