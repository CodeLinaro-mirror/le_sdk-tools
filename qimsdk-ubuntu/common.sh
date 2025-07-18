# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

function print-red() {
    tput setaf 1 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

function print-green() {
    tput setaf 2 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

# Remote Sync Wrapper
# Sync from host to remote and clean-up if success
#   $1 - (mandatory) SRC: source to sync
#   $2 - (mandatory) DST: destination where to sync
function qimsdk-sync-to-remote-and-clean() {
    local SRC=${1}
    local DST=${2}

    [[ -d ${DST} || -f ${DST} ]] && {
        return 0
    }

    rsync -aP ${SRC} ${DST}

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: rsync -aP ${SRC} ${DST}"
        return ${rc}
    }

    rm -f ${SRC}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: rm ${SRC}"
        return ${rc}
    }

    return 0
}

# Get container and image from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give container name as argument
#   $3 - (mandatory) give image name as argument
function qimsdk-get-container-and-image-name() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_CONTAINER_NAME=${2}
    local -n OUT_QIMSDK_IMAGE_NAME=${3}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local QIMSDK_ADDITIONAL_TAG=$(
        echo ${JSON_CONTENT} |  jq '.Additional_tag_container' | tr -d '"'
    )

    [ ! -z "${QIMSDK_ADDITIONAL_TAG}" ] && {
        QIMSDK_ADDITIONAL_TAG="-${QIMSDK_ADDITIONAL_TAG}"
    }

    OUT_QIMSDK_CONTAINER_NAME="qimsdk${QIMSDK_ADDITIONAL_TAG}"

    local ADDITIONAL_TAG_IMAGE=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_image' | tr -d '"')

    [ ! -z "${ADDITIONAL_TAG_IMAGE}" ] && {
        ADDITIONAL_TAG_IMAGE="-${ADDITIONAL_TAG_IMAGE}"
    }

    OUT_QIMSDK_IMAGE_NAME="qimsdk${ADDITIONAL_TAG_IMAGE}"

    return 0
}

# Get remote sync destination from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Docker_image_path as argument
function qimsdk-get-docker-image-path() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_DOCKER_IMAGE_PATH=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_DOCKER_IMAGE_PATH=$(echo ${JSON_CONTENT} |  jq '.Docker_image_path' | tr -d '"')

    [ -z "${OUT_DOCKER_IMAGE_PATH}" ] && {
        print-red "Docker_image_path attribute in config.json is not set !!!"
        return -1
    }

    return 0
}

# Get User_Libraries_To_Mount from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give User specific libraries to be mounted as argument
function qimsdk-get-libs-to-mount() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_SPECIFIC_LIBS=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    declare -a LIBS_ARRAY

    LIBS_ARRAY=$(
        echo ${JSON_CONTENT} | jq '.Libraries_To_Mount[]' | tr -d '"'
    )

    [ ! -z "${LIBS_ARRAY}" ] && {
        declare -a LIBS_ARRAY_TEMP=""

        for PLATFORM_LIB in ${LIBS_ARRAY[@]}; do
            LIBS_ARRAY_TEMP+="-v ${PLATFORM_LIB}:${PLATFORM_LIB} "
        done

        OUT_SPECIFIC_LIBS=${LIBS_ARRAY_TEMP}
    } || {
        OUT_SPECIFIC_LIBS=""
    }

    return 0
}

# Get Exports from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) EXPORTS: set of variables, which will be exported
function qimsdk-get-variables-to-export() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_EXPORTS=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local EXPORTS_LOCAL=$(
        echo ${JSON_CONTENT} | jq -r '.Exports[]'
    )

    declare -a EXPORT_TEMP=""

    for EXPORT in ${EXPORTS_LOCAL[@]}; do
        EXPORT_TEMP+="-e ${EXPORT} "
    done

    OUT_EXPORTS=${EXPORT_TEMP}

    return 0
}

# Get set of dev nodes to map from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) PLATFORM_SPECIFIC_MAPPINGS: set of dev nodes that will be mapped
function qimsdk-get-platform-specific-mappings() {
    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_MAPPINGS=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local MAPPINGS_LOCAL=$(
        echo ${JSON_CONTENT} | jq -r '.Platform_Specific_Mappings[]'
    )

    declare -a MAPPINGS_TEMP=""

    for MAPPINGS in ${MAPPINGS_LOCAL[@]}; do
        MAPPINGS_TEMP+="--device ${MAPPINGS} "
    done

    OUT_MAPPINGS=${MAPPINGS_TEMP}

    return 0
}

# Generate docker run cmd in shell file
#   $1 - (mandatory) path to qimsdk target json
#   $2 - (mandatory) remote path
#   $3 - (mandatory) container name from user's config json
#   $4 - (mandatory) image name from user's config json
function qimsdk-generate-docker-run-cmd() {
    local PATH_TO_TARGET_CONFIG_JSON=${1}
    local RESULT=${2}
    local CONTAINER_NAME=${3}
    local IMAGE_NAME=${4}

    [ ! -f "${PATH_TO_TARGET_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local LIBS_TO_MOUNT
    qimsdk-get-libs-to-mount ${PATH_TO_TARGET_CONFIG_JSON} LIBS_TO_MOUNT

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-libs-to-mount  !!!"
        return ${rc}
    }

    local PLATFORM_SPECIFIC_MAPPINGS
    qimsdk-get-platform-specific-mappings ${PATH_TO_TARGET_CONFIG_JSON} PLATFORM_SPECIFIC_MAPPINGS

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-platform-specific-mappings  !!!"
        return ${rc}
    }

    local TARGET_EXPORTS
    qimsdk-get-variables-to-export ${PATH_TO_TARGET_CONFIG_JSON}                                   \
            TARGET_EXPORTS

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: qimsdk-get-variables-to-export !!!"
        return ${rc}
    }

    echo "docker run -it -d --net host                                                             \
            ${LIBS_TO_MOUNT} ${PLATFORM_SPECIFIC_MAPPINGS} ${TARGET_EXPORTS}                       \
            -h ${CONTAINER_NAME} --user qimsdk --name ${CONTAINER_NAME} ${IMAGE_NAME}" > ${RESULT}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: Failed to construct Docker run CDI cmd !!!"
        return ${rc}
    }

    return 0
}
