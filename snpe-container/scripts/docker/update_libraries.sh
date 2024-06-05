#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

function qml-update-libraries() {

    # QML_ACCELERATION_ENGINE_NAMES is a comma separated string
    local engine_names=${QML_ACCELERATION_ENGINE_NAMES//,/ }
    local sdk_vers=${QML_SDK_VERS_STRING//,/ }
    for index in ${!engine_names[@]}; do
        local ACCELERATION_ENGINE_NAME=${engine_names[index]}
        local SDK_VER=${sdk_vers[index]}

        type qml-update-libraries-${ACCELERATION_ENGINE_NAME} &>/dev/null

        local rc=$?
        [ $rc -ne 0 ] && {
            echo "No such function: qml-update-libraries-${ACCELERATION_ENGINE_NAME}"
            return $rc
        }

        qml-update-libraries-${ACCELERATION_ENGINE_NAME} ${SDK_VER}
        rc=$?
        [ $rc -ne 0 ] && {
            echo "FAILED: qml-update-libraries-${ACCELERATION_ENGINE_NAME} ${SDK_VER}"
            return $rc
        }

    done

    return 0
}

# Update libraries required for snpe
#   ${1} - (mandatory) sdk version
function qml-update-libraries-snpe() {
    local QML_SDK_VER=$1
    local VER_PREFIX="v"
    declare -A MAP_TARGET_TO_LIB
    declare -A MAP_TARGET_TO_HEXAGON_LIB_VERSION

    MAP_TARGET_TO_LIB["kalama"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcm6490"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcs9100"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcs6490"]="aarch64-ubuntu-gcc9.4"
    MAP_TARGET_TO_LIB["qrb5165"]="aarch64-oe-linux-gcc9.3"

    MAP_TARGET_TO_HEXAGON_LIB_VERSION["kalama"]="v73"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["qcm6490"]="v68"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["qcs6490"]="v68"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["qcs9100"]="v73"
    MAP_TARGET_TO_HEXAGON_LIB_VERSION["qrb5165"]="v66"

    TARGET_ACCELERATION_ENGINE_LIBRARY=${MAP_TARGET_TO_LIB[${QML_TARGET_PLATFORM}]}

    [ -z "${TARGET_ACCELERATION_ENGINE_LIBRARY}" ] && {
        echo "FAILED: Mapping target engine library unsuccessfull for target                       \
         ${QML_TARGET_PLATFORM} !!!"
        return -1
    }

    TARGET_HEXAGON_LIBRARY_VERSION=${MAP_TARGET_TO_HEXAGON_LIB_VERSION[${QML_TARGET_PLATFORM}]}
    [ -z "${TARGET_ACCELERATION_ENGINE_LIBRARY}" ] && {
        echo "FAILED: Mapping target library version unsuccessfull for target                      \
         ${QML_TARGET_PLATFORM} !!!"
        return -2
    }

    local rc=$?
    rc=$(curl -iL --write-out "%{http_code}\n" --output ${QML_SDK_VER}.zip                         \
    "https://softwarecenter.qualcomm.com/api/download/software/qualcomm_neural_processing_sdk/${QML_SDK_VER}.zip")

    [ $rc -ne 200 ] && {
        echo "FAILED: to download SDK ${ACCELERATION_ENGINE_NAME} ${QML_SDK_VER}"
        return -3
    }
    unzip -q ${QML_SDK_VER}.zip -d ${QML_BASE_DIR}/downloads/

    local ACCELERATION_ENGINE_PATH="${QML_BASE_DIR}/downloads/qairt/${QML_SDK_VER#${VER_PREFIX}}"

    cp ${ACCELERATION_ENGINE_PATH}/lib/${TARGET_ACCELERATION_ENGINE_LIBRARY}/*                     \
    /deploy/snpe/usr/lib/
    cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-${TARGET_HEXAGON_LIBRARY_VERSION}/unsigned/lib*     \
    /deploy/snpe/usr/lib/rfsa/adsp/
    cp ${ACCELERATION_ENGINE_PATH}/bin/${TARGET_ACCELERATION_ENGINE_LIBRARY}/* /deploy/snpe/usr/bin/

    return 0
}
