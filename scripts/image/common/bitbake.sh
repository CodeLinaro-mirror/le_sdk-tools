#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Add Layer in bitbake
#   $1 - (mandatory) layer dir
function qimsdk-bitbake-add-layers() {
    local LAYER=$1
    local rc

    [ -z "${LAYER}" ] && print-red "Layer folder must be provided as first argument !!!" && return -1

    pushd  ${QIMSDK_ESDK_BASE_FOLDER} 1>/dev/null
    layers/poky/bitbake/bin/bitbake-layers add-layer ${LAYER}
    rc=$?
    popd 1>/dev/null
    return $rc
}
