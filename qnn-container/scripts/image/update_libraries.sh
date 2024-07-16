#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

function qnn-update-libraries() {

    declare -A MAP_TARGET_TO_LIB

    MAP_TARGET_TO_LIB["kalama"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcm6490"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcs6490"]="aarch64-ubuntu-gcc9.4"
    MAP_TARGET_TO_LIB["qrb5165"]="aarch64-oe-linux-gcc9.3"
    MAP_TARGET_TO_LIB["qcs9100"]="aarch64-oe-linux-gcc11.2"

    TARGET_ACCELERATION_ENGINE_LIBRARY=${MAP_TARGET_TO_LIB[${QNN_TARGET_PLATFORM}]}

    [ -z "${TARGET_ACCELERATION_ENGINE_LIBRARY}" ] && {
        echo "FAILED: Mapping target engine library unsuccessfull for target ${QNN_TARGET_PLATFORM} !!!"
        return -1
    }

    local ACCELERATION_ENGINE_PATH="${QNN_BASE_DIR}/downloads/qnn/${QNN_VERSION}"

    cp ${ACCELERATION_ENGINE_PATH}/lib/${TARGET_ACCELERATION_ENGINE_LIBRARY}/* ${QNN_DEPLOY_DIR}/usr/lib/

    cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v66/unsigned/lib* ${QNN_DEPLOY_DIR}/usr/lib/rfsa/adsp/
    cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v68/unsigned/lib* ${QNN_DEPLOY_DIR}/usr/lib/rfsa/adsp/
    cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v69/unsigned/lib* ${QNN_DEPLOY_DIR}/usr/lib/rfsa/adsp/
    cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v73/unsigned/lib* ${QNN_DEPLOY_DIR}/usr/lib/rfsa/adsp/

    cp ${ACCELERATION_ENGINE_PATH}/bin/${TARGET_ACCELERATION_ENGINE_LIBRARY}/* ${QNN_DEPLOY_DIR}/usr/bin/

    return 0
}
