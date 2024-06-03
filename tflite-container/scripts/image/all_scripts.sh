#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

TF_LITE_ALL_SCRIPTS_FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${TF_LITE_ALL_SCRIPTS_FOLDER}/env_variables.sh 2>/dev/null

# Setup eSDK environment
source ${TFLITE_SDK_BASE_DIR}/${TFLITE_SDK_ENV_SETUP_SCRIPT} 2>/dev/null

# tools.sh amd device.sh need to be sourced first. Their functions are used in other scripts
source ${TFLITE_BASE_DIR}/scripts/common/tools.sh

# Source all other scripts
for f in ${TFLITE_BASE_DIR}/scripts/*/*.sh; do
    [ "$(basename ${f})" != "tools.sh" ]  && source ${f}
done
$@
