#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Parse python json configuraiton
#   ${1} - (mandatory) path to container config json
#   ${2} - out device id
#   ${3} - out backend name
#   ${4} - out dlc model name
#   ${5} - out buffer type
#   ${6} - path of example directory
#   ${7} - path of output results directory
function qml-host-parse-python-json() {
    PATH_TO_CONFIG_JSON=${1}
    local -n OUT_DEVICE_ID=${2}
    local -n OUT_BACKEND=${3}
    local -n OUT_MODEL=${4}
    local -n OUT_BUFFER_TYPE=${5}
    local -n OUT_PATH_TO_EXAMPLES_DIRECTORY=${6}
    local -n OUT_TEST_OUTPUT_DIRECTORY_NAME=${7}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to config json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_BACKEND=$(echo ${JSON_CONTENT} | jq '.Backend' | tr -d '"')

    [ -z "${OUT_BACKEND}" ] && {
        print-red "Backend attribute in dev_config.json is not set, it must be cpu or gpu !!!"
        return -2
    }

    OUT_MODEL=$(echo ${JSON_CONTENT} | jq '.Model' | tr -d '"')

    [ -z "${OUT_MODEL}" ] && {
        print-red "Model attribute in dev_config.json is not set !!!"
        return -3
    }

    OUT_BUFFER_TYPE=$(echo ${JSON_CONTENT} | jq '.Buffer' | tr -d '"')

    [ -z "${OUT_BUFFER_TYPE}" ] && {
        print-red "Buffer attribute in dev_config.json is not set,                                 \
            it must be one of the following USERBUFFER_TF8, USERBUFFER_TF16 or USERBUFFER_FLOAT !!!"
        return -4
    }

    OUT_PATH_TO_EXAMPLES_DIRECTORY=$(echo ${JSON_CONTENT} | jq '.TestExamplesDirectory' | tr -d '"')

    [ ! -d "${OUT_PATH_TO_EXAMPLES_DIRECTORY}" ] && {
        print-red "TestExamplesDirectory attribute in dev_config.json is empty,                    \
         or no such directory !!!"
        return -5
    }

    OUT_TEST_OUTPUT_DIRECTORY_NAME=$(echo ${JSON_CONTENT} | jq '.TestOutputDirectoryName' |
        tr -d '"')

    [ -z "${OUT_TEST_OUTPUT_DIRECTORY_NAME}" ] && {
        print-red "TestOutputDirectoryName attribute in dev_config.json is not set !!!"
        return -6
    }

    OUT_DEVICE_ID=$(echo ${JSON_CONTENT} | jq '.DeviceID' | tr -d '"')

    return 0
}

# Sync Python wrapper src and test examples to the container
#   ${1} - (mandatory) path to container config json
function qml-sync-snpe() {

    local QML_ARG_BASE_DIR=/mnt/qml
    local PATH_TO_CONFIG_JSON=${1}

    local DEVICE_ID
    local BACKEND
    local MODEL
    local BUFFER_TYPE
    local PATH_TO_EXAMPLES_DIRECTORY
    local TEST_OUTPUT_DIRECTORY_NAME

    qml-host-parse-python-json ${PATH_TO_CONFIG_JSON}                                              \
        DEVICE_ID                                                                                  \
        BACKEND                                                                                    \
        MODEL                                                                                      \
        BUFFER_TYPE                                                                                \
        PATH_TO_EXAMPLES_DIRECTORY                                                                 \
        TEST_OUTPUT_DIRECTORY_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-host-parse-python-json !!!"
        return $rc
    }

    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    (
        export ANDROID_SERIAL=${DEVICE_ID}

        qml-device-prepare ${DEVICE_ID}

        local rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qml-device-prepare !!!"
            return $rc
        }

        local RELATIVE_PATH_TO_EXAMPLES_DIRECTORY=$(realpath --relative-to="${PWD}"                \
            "$PATH_TO_EXAMPLES_DIRECTORY")

        adb push ${RELATIVE_PATH_TO_EXAMPLES_DIRECTORY} /tmp/examples

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: adb push ${RELATIVE_PATH_TO_EXAMPLES_DIRECTORY} /tmp/examples !!!"
            return $rc
        }

        qml-device-command "docker cp /tmp/examples/ ${QML_CONTAINER_NAME}:${QML_ARG_BASE_DIR}/." \
            ${DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qml-device-command !!!"
            qml-device-command "rm -rf /tmp/examples" ${DEVICE_ID}

            return $rc
        }

        qml-device-command "rm -rf /tmp/examples" ${DEVICE_ID}

        rc=$?
        [ $rc -ne 0 ] && {
            print-red "FAILED: qml-device-command !!!"
            return $rc
        }

        return 0
    )
}

# Run Python wrapper script on the container
#   ${1} - (mandatory) path to container config json
function qml-run-snpe() {

    local QML_ARG_BASE_DIR=/mnt/qml
    local PATH_TO_CONFIG_JSON=${1}

    local DEVICE_ID
    local BACKEND
    local MODEL
    local BUFFER_TYPE
    local PATH_TO_EXAMPLES_DIRECTORY
    local TEST_OUTPUT_DIRECTORY_NAME

    qml-host-parse-python-json ${PATH_TO_CONFIG_JSON}                                              \
        DEVICE_ID                                                                                  \
        BACKEND                                                                                    \
        MODEL                                                                                      \
        BUFFER_TYPE                                                                                \
        PATH_TO_EXAMPLES_DIRECTORY                                                                 \
        TEST_OUTPUT_DIRECTORY_NAME

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-host-parse-python-json !!!"
        return $rc
    }

    local QML_CONTAINER_NAME
    local QML_IMAGE_NAME

    qml-get-container-and-image-name ${PATH_TO_CONFIG_JSON} QML_CONTAINER_NAME QML_IMAGE_NAME

    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qml-get-container-and-image-name !!!"
        return $rc
    }

    # make upper and lower case conversion
    local BACKEND_lc=${BACKEND,,}
    local BUFFER_uc=${BUFFER_TYPE^^}

    (
        export ANDROID_SERIAL=${DEVICE_ID}

        adb shell "docker exec ${QML_CONTAINER_NAME} cat ${QML_ARG_BASE_DIR}/examples/inputs.txt "

        time adb shell "docker exec ${QML_CONTAINER_NAME}                                          \
            snpe-net-run                                                                           \
                ${BACKEND_lc}                                                                      \
                --container ${QML_ARG_BASE_DIR}/examples/${MODEL}                                  \
                --input_list ${QML_ARG_BASE_DIR}/examples/inputs.txt                               \
                --output_dir ${QML_ARG_BASE_DIR}/${TEST_OUTPUT_DIRECTORY_NAME}"

        return 0
    )
}

QML_DOCKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

source ${QML_DOCKER_DIR}/scripts/host/common.sh

print-blue "qml-sync-snpe                                   <path/to/targets/dev_config.json>"
echo "    Sync snpe input files to the container"
print-blue "qml-run-snpe                                    <path/to/targets/dev_config.json>"
echo "    Run snpe-net-run on the container"
