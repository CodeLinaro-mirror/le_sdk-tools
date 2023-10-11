#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Setup eSDK environment
pushd ${QIMSDK_ESDK_BASE_DIR} 1>/dev/null
source ${QIMSDK_ENV_SETUP_SCRIPT}
popd 1>/dev/null

# Source all scripts
source ${QIMSDK_SCRIPTS}/common/tools.sh
for f in ${QIMSDK_SCRIPTS}/*/*.sh; do
    source ${f}
done
$@
