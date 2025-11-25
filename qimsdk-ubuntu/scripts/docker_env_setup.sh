# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Build docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR} directory
#   $1 - (mandatory) path to target config json
function qimsdk-docker-build-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local QIMSDK_IMSDK_SRC_BRANCH
    local QIMSDK_SOLUTIONS_BRANCH

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-branch-names ${PATH_TO_CONFIG_JSON}                                                 \
            QIMSDK_IMSDK_SRC_BRANCH                                                                \
            QIMSDK_SOLUTIONS_BRANCH

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-branch-names !!!"
        return ${rc}
    }

    DOCKER_BUILDKIT=1 docker build                                                                 \
            --progress=plain --target qimsdk_ubun_image                                            \
            --build-arg QIMSDK_ARG_IMSDK_SRC_BRANCH=${QIMSDK_IMSDK_SRC_BRANCH}                     \
            --build-arg QIMSDK_ARG_SOLUTIONS_BRANCH=${QIMSDK_SOLUTIONS_BRANCH}                     \
            ${QIMSDK_DOCKER_DIR} -t ${QIMSDK_IMAGE_NAME}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Build image failed !!!"
        return ${rc}
    }

    print-green "Build image completed successfully !!!"

    return 0
}

# Save selected device image
# $1 - (mandatory) path to target config json
function qimsdk-docker-save-image() {
    local PATH_TO_CONFIG_JSON=${1}
    local QIMSDK_CONTAINER_NAME
    local QIMSDK_IMAGE_NAME
    local DOCKER_IMAGE_PATH

    qimsdk-get-container-and-image-name ${PATH_TO_CONFIG_JSON}                                     \
            QIMSDK_CONTAINER_NAME                                                                  \
            QIMSDK_IMAGE_NAME

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-container-and-image-name !!!"
        return ${rc}
    }

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} DOCKER_IMAGE_PATH

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-docker-image-path !!!"
        return ${rc}
    }

    [[ "${DOCKER_IMAGE_PATH}" != *":"* ]] && [ ! -d "${DOCKER_IMAGE_PATH}" ] && {
        mkdir -p ${DOCKER_IMAGE_PATH}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: mkdir -p ${DOCKER_IMAGE_PATH} !!!"
            return ${rc}
        }
    }

    local FILE_NAME="${QIMSDK_IMAGE_NAME}.tar"

    local COMMON_PATH=""

    [ -d ${DOCKER_IMAGE_PATH} ] && {
        COMMON_PATH=${DOCKER_IMAGE_PATH}
    } || {
        COMMON_PATH=$(mktemp -d)
    }

    docker save ${QIMSDK_IMAGE_NAME}:latest -o ${COMMON_PATH}/${FILE_NAME}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "Device save image failed: docker save failed !!!"
        rm -f ${COMMON_PATH}/${FILE_NAME}

        return ${rc}
    }

    qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/${FILE_NAME} ${DOCKER_IMAGE_PATH}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-sync-to-remote-and-clean"
        rm -f ${COMMON_PATH}/${FILE_NAME}

        return ${rc}
    }

    local PLATFORMS=(
        $(cat ${PATH_TO_CONFIG_JSON} | jq '.Supported_targets[]' | tr -d '"')
    )

    for SUFFIX_NAME in ${PLATFORMS[@]}; do
        local DEVICE_JSON="${QIMSDK_DOCKER_DIR}/targets/${SUFFIX_NAME}.json"

        qimsdk-generate-docker-run-cdi-cmd ${DEVICE_JSON}                                          \
                ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh                                    \
                ${QIMSDK_CONTAINER_NAME}                                                           \
                ${QIMSDK_IMAGE_NAME}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "Generate ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh file failed !!!"
            rm -f ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh

            return ${rc}
        }

        qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh            \
                ${DOCKER_IMAGE_PATH}

        rc=$?
        [ ${rc} -ne 0 ] && {
            print-red "FAILED: qimsdk-sync-to-remote-and-clean"
            rm -f ${COMMON_PATH}/docker_run_cdi_${SUFFIX_NAME}.sh

            return ${rc}
        }
    done

    cp ${QIMSDK_DOCKER_DIR}/scripts/generate_cdi_json.sh ${COMMON_PATH}
    qimsdk-sync-to-remote-and-clean ${COMMON_PATH}/generate_cdi_json.sh                            \
            ${DOCKER_IMAGE_PATH}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-sync-to-remote-and-clean"

        return ${rc}
    }

    print-green "Device save image successful !!!"

    return 0
}

QIMSDK_DOCKER_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"
source ${QIMSDK_DOCKER_DIR}/scripts/common.sh

print-green "Docker build environment setup"
echo "=============================="
print-green "qimsdk-docker-build-image <path-to-config-json>"
echo "    Build docker image based on Dockerfile in ${QIMSDK_DOCKER_DIR}"
print-green "qimsdk-docker-save-image <path-to-config-json>"
echo "    Save selected device image, compose file and run command"
