#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

function qml-update-libraries() {

    # QML_ACCELERATION_ENGINE_NAMES is a comma separated string
    for ACCELERATION_ENGINE_NAME in ${QML_ACCELERATION_ENGINE_NAMES//,/ }; do

        type qml-update-libraries-${ACCELERATION_ENGINE_NAME} &>/dev/null

        local rc=$?
        [ $rc -ne 0 ] && {
            echo "No such function: qml-update-libraries-${ACCELERATION_ENGINE_NAME}"
            return $rc
        }

        qml-update-libraries-${ACCELERATION_ENGINE_NAME}
         rc=$?
        [ $rc -ne 0 ] && {
            echo "FAILED: qml-update-libraries-${ACCELERATION_ENGINE_NAME}"
            return $rc
        }

    done

    return 0
}

function qml-update-libraries-snpe() {

    declare -A MAP_TARGET_TO_LIB

    MAP_TARGET_TO_LIB["kalama"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcm6490"]="aarch64-oe-linux-gcc11.2"
    MAP_TARGET_TO_LIB["qcs6490"]="aarch64-ubuntu-gcc9.4"
    MAP_TARGET_TO_LIB["qrb5165"]="aarch64-oe-linux-gcc9.3"

    TARGET_ACCELERATION_ENGINE_LIBRARY=${MAP_TARGET_TO_LIB[${QML_TARGET_PLATFORM}]}

    [ -z "${TARGET_ACCELERATION_ENGINE_LIBRARY}" ] && {
        echo "FAILED: Mapping target engine library unsuccessfull for target ${QML_TARGET_PLATFORM} !!!"
        return -1
    }

    local ACCELERATION_ENGINE_PATH="${QML_BASE_DIR}/downloads/snpe"

    cp ${ACCELERATION_ENGINE_PATH}/lib/${TARGET_ACCELERATION_ENGINE_LIBRARY}/* /usr/lib/

    cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v66/unsigned/lib* /usr/lib/rfsa/adsp/
    cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v68/unsigned/lib* /usr/lib/rfsa/adsp/
    cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v69/unsigned/lib* /usr/lib/rfsa/adsp/
    cp ${ACCELERATION_ENGINE_PATH}/lib/hexagon-v73/unsigned/lib* /usr/lib/rfsa/adsp/

    cp ${ACCELERATION_ENGINE_PATH}/bin/${TARGET_ACCELERATION_ENGINE_LIBRARY}/* /usr/bin/

    return 0
}
