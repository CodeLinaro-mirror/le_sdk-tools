#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Save artifacts to Docker_image_path provided in config json file.
#   $1 - (mandatory) artifacts variant - release or debug
function qimsdk-dbg-save-artifacts-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

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

    echo "dev ${VARIANT} artifacts saved to ${QIMSDK_DOCKER_IMAGE_PATH} !!!"
}

# Save release variant artifacts to Docker_image_path provided in config json file.
function qimsdk-dbg-save-artifacts() {
    qimsdk-dbg-save-artifacts-variant release
}

# Save debug variant artifacts to Docker_image_path provided in config json file.
function qimsdk-dbg-save-artifacts-dbg() {
    qimsdk-dbg-save-artifacts-variant debug
}

# Push artifacts to device with id provided in config json file.
#   $1 - (mandatory) artifacts variant - release or debug
function qimsdk-dbg-push-artifacts-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local VARIANT=${1}

    (
        qimsdk-dbg-save-artifacts-variant ${VARIANT}
        local rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: qimsdk-dbg-save-artifacts-variant !!!"
            return ${rc}
        }

        export ANDROID_SERIAL=${QIMSDK_DEVICE_ID}

        [ -z ${ANDROID_SERIAL} ] && {
            print-red "Android serial is not set !!!"
            rm ${FILE_NAME}

            return -1
        }

        qimsdk-device-command "mkdir -p /tmp/qti/development" ${QIMSDK_DEVICE_ID}               && \
                adb push ${QIMSDK_DOCKER_IMAGE_PATH}/qimsdk_dev_artifacts_${VARIANT}.tar           \
                        /tmp/qti/development/                                                   && \
                qimsdk-device-command "cd /tmp/qti/development                                  && \
                        tar -xf /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar        && \
                        docker cp usr ${QIMSDK_CONTAINER_NAME}:/" ${QIMSDK_DEVICE_ID}           && \
                qimsdk-device-command "rm -rf /tmp/qti/development/usr" ${QIMSDK_DEVICE_ID}     || {
            print-red "Artifacts push failed !!!"

            qimsdk-device-command "rm -rf /tmp/qti/development/usr"
            qimsdk-device-command "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"

            rm -f qimsdk_dev_artifacts_${VARIANT}.tar

            return -1
        }

        qimsdk-device-command "rm -f /tmp/qti/development/qimsdk_dev_artifacts_${VARIANT}.tar"
        rm -f qimsdk_dev_artifacts_${VARIANT}.tar
    )

    echo "dbg ${VARIANT} artifacts pushed to ${QIMSDK_DEVICE_ID} !!!"
}

# Push release variant to device with id provided provided in config json file.
function qimsdk-dbg-push-artifacts() {
    qimsdk-dbg-push-artifacts-variant release
}

# Push debug variant to device with id provided provided in config json file.
function qimsdk-dbg-push-artifacts-dbg() {
    qimsdk-dbg-push-artifacts-variant debug
}

print-blue "qimsdk-dbg-save-artifacts"
echo "    Send built binaries to Docker_image_path specified in config json file"
print-yellow "qimsdk-dbg-save-artifacts-dbg"
echo "    Send built debug binaries to Docker_image_path specified in config json file"
print-blue "qimsdk-dbg-push-artifacts"
echo "    Push release variant to device with id provided provided in config json file"
print-yellow "qimsdk-dbg-push-artifacts-dbg"
echo "    Push debug variant to device with id provided provided in config json file"
