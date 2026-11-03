#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Save artifacts to Docker_image_path provided in config json file. Internal
# helper: reached only via "docker exec" against the running dbg container,
# from the builder-push-artifacts-device[-dbg] / builder-push-artifacts-
# docker[-dbg] functions in scripts-dbg/docker_env_setup.sh, which run on the
# host rather than inside this container.
#   $1 - (mandatory) artifacts variant - release or debug
function builder-save-artifacts-variant() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
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

    [[ -z "${QIMSDK_DOCKER_IMAGE_PATH}" ]]  || [ ! -d ${QIMSDK_DOCKER_IMAGE_PATH} ]             && {
        print-red "Docker image path unset or not a valid directory!"
        return -1
    }

    (
        cd ${PACKAGES_DIRECTORY}                                                                && \
        tar cf qimsdk_dev_artifacts_${VARIANT}.tar ./*                                          && \
        rsync -aP qimsdk_dev_artifacts_${VARIANT}.tar ${QIMSDK_DOCKER_IMAGE_PATH}               || {
            echo "rsync -a qimsdk_dev_artifacts_${VARIANT}.tar `
                    `${QIMSDK_DOCKER_IMAGE_PATH} failed !!!"
            rm -f qimsdk_dev_artifacts_${VARIANT}.tar
            return -1
        }
    )
    local rc=$?
    rm -f ${PACKAGES_DIRECTORY}/qimsdk_dev_artifacts_${VARIANT}.tar
    [ ${rc} -ne 0 ] && return -1

    echo "dev ${VARIANT} artifacts saved to ${QIMSDK_DOCKER_IMAGE_PATH} !!!"
}

# Save release variant artifacts to Docker_image_path provided in config json file.
function builder-save-artifacts() {
    builder-save-artifacts-variant release
}

# Save debug variant artifacts to Docker_image_path provided in config json file.
function builder-save-artifacts-dbg() {
    builder-save-artifacts-variant debug
}
