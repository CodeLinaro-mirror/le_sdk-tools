#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Setup eSDK environment
pushd ${QIMSDK_ESDK_BASE_FOLDER} 1>/dev/null
source environment-setup-aarch64-oe-linux-sdllvm || source environment-setup-armv8a-oe-linux-sdllvm
popd 1>/dev/null

# Source all scripts
source ${QIMSDK_SCRIPTS}/common/tools.sh
for f in ${QIMSDK_SCRIPTS}/*/*.sh; do
    source $f
done
$@
