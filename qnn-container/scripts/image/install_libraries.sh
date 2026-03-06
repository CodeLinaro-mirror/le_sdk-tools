#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

function qnn-install-libraries() {
    local QNN_SDK_VER=${QNN_VERSION}
    local VER_PREFIX="v"

    declare -A MAP_TARGET_TO_LIB
    declare -A MAP_TARGET_TO_HEXAGON_LIB_VERSION

    MAP_TARGET_TO_LIB["kalama"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcm6490"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcs6490"]="aarch64-ubuntu-gcc9.4"
    MAP_TARGET_TO_LIB["qrb5165"]="aarch64-oe-linux-gcc9.3"
    MAP_TARGET_TO_LIB["qcs9100"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcs8300"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["klm"]="aarch64-oe-linux-gcc11.2"

    MAP_TARGET_TO_HEXAGON_LIB_VERSION["kalama"]="v73"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["qcm6490"]="v68"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["qcs6490"]="v68"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["qcs9100"]="v73"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["qrb5165"]="v66"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["qcs8300"]="v75"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["klm"]="klm"

    TARGET_ACCELERATION_ENGINE_LIBRARY=${MAP_TARGET_TO_LIB[${QNN_TARGET_PLATFORM,,}]}

    [ -z "${TARGET_ACCELERATION_ENGINE_LIBRARY}" ] && {
        echo "FAILED: Mapping target engine library unsuccessful for target ${QNN_TARGET_PLATFORM} !!!"
        return -1
    }

    TARGET_HEXAGON_LIBRARY_VERSION=${MAP_TARGET_TO_HEXAGON_LIB_VERSION[${QNN_TARGET_PLATFORM,,}]}
    [ -z "${TARGET_HEXAGON_LIBRARY_VERSION}" ] && {
        echo "FAILED: Mapping target library version unsuccessful for target                       \
            ${QNN_TARGET_PLATFORM} !!!"

        return -2
    }

    local rc=$?
    rc=$(curl -iL --write-out "%{http_code}\n" --output ${VER_PREFIX}${QNN_SDK_VER}.zip            \
        "https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community`
        `/All/${QNN_SDK_VER}/${VER_PREFIX}${QNN_SDK_VER}.zip")

    [ "$rc" -ne 200 ] && {
        echo "FAILED: to download SDK ${VER_PREFIX}${QNN_SDK_VER}"
        return -3
    }

    rc=$(unzip -q ${VER_PREFIX}${QNN_SDK_VER}.zip -d ${QNN_BASE_DIR}/downloads/)
    [ "$rc" -ne 200 ] && {
        echo "FAILED: to unzip ${VER_PREFIX}${QNN_SDK_VER}.zip"
        return $rc
    }

    local ACCELERATION_ENGINE_PATH="${QNN_BASE_DIR}/downloads/qairt/${QNN_SDK_VER}"

    cp ${ACCELERATION_ENGINE_PATH}/lib/${TARGET_ACCELERATION_ENGINE_LIBRARY}/*                     \
        /deploy/qnn/usr/lib/
    cp ${ACCELERATION_ENGINE_PATH}/bin/${TARGET_ACCELERATION_ENGINE_LIBRARY}/* /deploy/qnn/usr/bin/

    if [[ "${TARGET_HEXAGON_LIBRARY_VERSION}" == "klm" ]]; then
        cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v68/unsigned/lib* /deploy/qnn/usr/lib/rfsa/adsp/
        cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v73/unsigned/lib* /deploy/qnn/usr/lib/rfsa/adsp/
        cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v75/unsigned/lib* /deploy/qnn/usr/lib/rfsa/adsp/
    else
        cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-${TARGET_HEXAGON_LIBRARY_VERSION}/unsigned/lib* \
        /deploy/qnn/usr/lib/rfsa/adsp/
    fi

    return 0
}
