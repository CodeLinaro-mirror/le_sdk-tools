#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Array containing all layers
QIMSDK_ALL_LAYERS=()

# Prepare all layers
function qimsdk-layers-prepare() {
    local LAYER

    # Check whether code was already prepared
    [ -f "${QIMSDK_WORK_DIR}/prepared" ] && print-red "Layers are already prepared" && return -1

    # Prepare all layers
    for LAYER in "${QIMSDK_ALL_LAYERS[@]}"; do
        qimsdk-${LAYER}-prepare || return -3
    done

    # Mark that code is already prepared
    [ ! -d "${QIMSDK_WORK_DIR}" ] && mkdir -p ${QIMSDK_WORK_DIR}/
    touch ${QIMSDK_WORK_DIR}/prepared

    print-green "All layers prepared successfully !!!"
}

# Clean all layers
function qimsdk-layers-clean() {
    local LAYER

    # Check whether code was already prepared
    [ ! -f "${QIMSDK_WORK_DIR}/prepared" ] && print-red "Layers are not prepared" && return -1

    # Clean all layers
    for LAYER in "${QIMSDK_ALL_LAYERS[@]}"; do
        qimsdk-${LAYER}-clean || return -3
    done

    # Mark that code is cleaned
    [ -d "${QIMSDK_WORK_DIR}" ] && rm -rf ${QIMSDK_WORK_DIR}/prepared

    print-green "All layers cleaned successfully !!!"
}

# Build all layers
function qimsdk-layers-build() {
    local LAYER

    # Build all layers
    for LAYER in "${QIMSDK_ALL_LAYERS[@]}"; do
        qimsdk-${LAYER}-build || return -1
    done

    print-green "All layers built successfully !!!"
}

# Package all layers
function qimsdk-layers-package() {
    # Generate python package (.whl)
    ( cd ${QIMSDK_WORK_DIR}/../scripts/local/; python3 setup_qimsdk_sync.py bdist_wheel )

    local LAYER

    # Package all layers
    for LAYER in "${QIMSDK_ALL_LAYERS[@]}"; do
        qimsdk-${LAYER}-package || return -1
    done

    print-green "All layers packaged successfully !!!"
}

# Prepare, build and package all layers
function qimsdk-layers-prepare-build-package() {
    qimsdk-layers-prepare && qimsdk-layers-build && qimsdk-layers-package
}

# Print help
print-green "qimsdk-layers-build"
echo "    must be invoked to compile modified layers"
print-green "qimsdk-layers-package"
echo "    must be invoked after invoking qimsdk-layers-build to package compiled recipes"
