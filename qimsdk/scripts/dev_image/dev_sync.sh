#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Save artifacts to Docker_image_path provided in config json file.
#   $1 - (mandatory) artifacts variant - release or debug
function qimsdk-dev-save-artifacts-variant() {
    local VARIANT=${1}
    [ "${VARIANT}" == "release" ] || [ "${VARIANT}" == "debug" ] || {
        print-red "Failed to save ${VARIANT} packages !!!"
        print-red "Wrong variant provided: supported variants: release, debug !!!"
        return -1
    }

    local PACKAGES_DIRECTORY
    [ "${VARIANT}" == "release" ] && PACKAGES_DIRECTORY="${QIMSDK_INSTALL_DIR}"
    [ "${VARIANT}" == "debug" ]   && PACKAGES_DIRECTORY="${QIMSDK_INSTALL_DEBUG_DIR}"

    pushd ${PACKAGES_DIRECTORY} > /dev/null
        tar cf qimsdk_dev_artifacts_${VARIANT}.tar ./*                                          && \
                rsync -aP qimsdk_dev_artifacts_${VARIANT}.tar ${QIMSDK_DOCKER_IMAGE_PATH}       || {
                    echo "rsync -a qimsdk_dev_artifacts_${VARIANT}.tar `
                        `${QIMSDK_DOCKER_IMAGE_PATH} failed !!!"
                    popd > /dev/null
                    return -1
                }
        rm -f qimsdk_dev_artifacts_${VARIANT}.tar
    popd  > /dev/null

    echo "Dev ${VARIANT} artifacts saved to ${QIMSDK_DOCKER_IMAGE_PATH} !!!"
}

# Save release variant artifacts to Docker_image_path provided in config json file.
function qimsdk-dev-save-artifacts() {
    qimsdk-dev-save-artifacts-variant release
}

# Save debug variant artifacts to Docker_image_path provided in config json file.
function qimsdk-dev-save-artifacts-dbg() {
    qimsdk-dev-save-artifacts-variant debug
}

# Push artifacts to device with id provided in config json file.
#   $1 - (mandatory) artifacts variant - release or debug
function qimsdk-dev-push-artifacts-variant() {
    local VARIANT=${1}

    (
        QIMSDK_DOCKER_IMAGE_PATH=/tmp

        qimsdk-dev-save-artifacts-variant ${VARIANT}
        local rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: qimsdk-dev-save-artifacts-variant !!!"
            return ${rc}
        }

        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qimsdk-device-command "mkdir -p /opt/qti/development" ${QIMSDK_DEVICE_ID}               && \
                adb push ${QIMSDK_DOCKER_IMAGE_PATH}/qimsdk_dev_artifacts_${VARIANT}.tar           \
                        /opt/qti/development/                                                   && \
                qimsdk-device-command "cd /opt/qti/development                                  && \
                        tar -xf /opt/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar        && \
                        docker cp usr ${QIMSDK_CONTAINER_NAME}:/" ${QIMSDK_DEVICE_ID}           && \
                qimsdk-device-command "rm -rf /opt/qti/development/usr" ${QIMSDK_DEVICE_ID}     || {
            print-red "Artifacts push failed !!!"

            qimsdk-device-command "rm -rf /opt/qti/development/usr"
            qimsdk-device-command "rm -f /opt/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"

            rm -f qimsdk_dev_artifacts_${VARIANT}.tar

            return -1
        }

        qimsdk-device-command "rm -f /opt/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"
        rm -f qimsdk_dev_artifacts_${VARIANT}.tar
    )

    echo "Dev ${VARIANT} artifacts pished to ${QIMSDK_ARG_DEVICE_ID} !!!"
}

# Push release variant to device with id provided provided in config json file.
function qimsdk-dev-push-artifacts() {
    qimsdk-dev-push-artifacts-variant release
}

# Push debug variant to device with id provided provided in config json file.
function qimsdk-dev-push-artifacts-dbg() {
    qimsdk-dev-push-artifacts-variant debug
}

print-blue "qimsdk-dev-save-artifacts"
echo "    Send built binaries to Docker_image_path specified in config json file"
print-yellow "qimsdk-dev-save-artifacts-dbg"
echo "    Send built debug binaries to Docker_image_path specified in config json file"
print-blue "qimsdk-dev-push-artifacts"
echo "    Push release variant to device with id provided provided in config json file"
print-yellow "qimsdk-dev-push-artifacts-dbg"
echo "    Push debug variant to device with id provided provided in config json file"
