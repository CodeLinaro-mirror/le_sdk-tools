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
                rsync -aP qimsdk_dev_artifacts_${VARIANT}.tar ${DOCKER_IMAGE_PATH} || {
                    echo "rsync -a qimsdk_dev_artifacts_${VARIANT}.tar `
                        `${DOCKER_IMAGE_PATH} failed !!!"
                    popd > /dev/null
                    return -2
                }
        rm -f qimsdk_dev_artifacts_${VARIANT}.tar
    popd  > /dev/null

    echo "Dev ${VARIANT} artifacts saved to ${DOCKER_IMAGE_PATH}"
}

# Save release variant artifacts to Docker_image_path provided in config json file.
function qimsdk-dev-save-artifacts() {
    qimsdk-dev-save-artifacts-variant release
}

# Save debug variant artifacts to Docker_image_path provided in config json file.
function qimsdk-dev-save-artifacts-dbg() {
    qimsdk-dev-save-artifacts-variant debug
}

print-blue "qimsdk-dev-save-artifacts"
echo "    Send built binaries to Docker_image_path specified in config json file"
print-yellow "qimsdk-dev-save-artifacts-dbg"
echo "    Send built debug binaries to Docker_image_path specified in config json file"
