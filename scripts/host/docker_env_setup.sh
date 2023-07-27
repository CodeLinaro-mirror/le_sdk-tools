#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

echo "Docker build environment setup"
echo "=============================="

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

function print-yellow() {
    tput setaf 3 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

function print-blue() {
    tput setaf 4 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

# Build docker image based on Dockerfile in $QIMSDK_DOCKER_DIR directory
#   $1 - (mandatory) path to target config json
function qimsdk-docker-build-image() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local QIMSDK_ARG_IMAGE_OS=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local QIMSDK_ARG_ESDK_SH=`cat ${PATH_TO_CONFIG_JSON} |  jq '.eSDK_shell_file' | tr -d '"'`
    [ ! "${QIMSDK_ARG_IMAGE_OS}" == "ubuntu18" ] && [ ! "${QIMSDK_ARG_IMAGE_OS}" == "ubuntu20" ] && \
        print-red "Wrong OS name - Avaliable OS are ubuntu18 and ubuntu20 !!!" && return -2
    [ -z "${QIMSDK_ARG_IMAGE_OS}" ] && print-red "Image OS name (ubuntu18 or ubuntu20) must be provided as an argument of config json !!!" && return -3
    [ -z "${QIMSDK_ARG_ESDK_SH}" ] && print-red "ESDK shell file must be provided as an argument of config json !!!" && return -4
    [ ! -f "${QIMSDK_ARG_ESDK_SH}" ] && print-red "Could not find ESDK_SH !!!" && return -5

    local TAG="${QIMSDK_ARG_IMAGE_OS}"
    local QIMSDK_ARG_BASE_DIR=/mnt/qimsdk
    local GROUP=$(getent group $(id -g ${USER}) | cut -d ':' -f 1)

    local QIMSDK_REPO_BASE_DIR=${QIMSDK_DOCKER_DIR}/..
    local QIMSDK_TMP_DIR=${QIMSDK_REPO_BASE_DIR}/tmp

    rm -rf ${QIMSDK_TMP_DIR}
    mkdir -p ${QIMSDK_TMP_DIR}
    ln ${QIMSDK_ARG_ESDK_SH} ${QIMSDK_TMP_DIR}/ 2>/dev/null                                     || \
        rsync -a ${QIMSDK_ARG_ESDK_SH} ${QIMSDK_TMP_DIR}/                                       || \
            {
                print-red "Cannot add sdk sh file to tmp dir !!!"
                rm -rf ${QIMSDK_TMP_DIR}
                return -6
            }

    QIMSDK_ARG_ESDK_SH=`basename ${QIMSDK_ARG_ESDK_SH}`

    local TFLITE_FILE=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Tflite_prebuilt_file' | tr -d '"'`
    local QIMSDK_ARG_TFLITE_FILENAME=no-tflite-dev-archive-available

    [ -f "${TFLITE_FILE}" ]                                                                     && \
            {
                ln ${TFLITE_FILE} ${QIMSDK_TMP_DIR}/ 2>/dev/null                                || \
                rsync -a ${TFLITE_FILE} ${QIMSDK_TMP_DIR}/                                      || \
                    {
                        print-red "Cannot add tflite dev archive to tmp directory !!!"
                        rm -rf ${QIMSDK_TMP_DIR}
                        return -7
                    }
                QIMSDK_ARG_TFLITE_FILENAME=`basename ${TFLITE_FILE}`
            }                                                                                   || \
                {
                    touch ${QIMSDK_TMP_DIR}/${QIMSDK_ARG_TFLITE_FILENAME}
                }

    local QIMSDK_ACCELERATION_ENGINE_TMP_DIR=${QIMSDK_REPO_BASE_DIR}/tmp/acceleration_engines
    rm -rf ${QIMSDK_ACCELERATION_ENGINE_TMP_DIR}
    mkdir -p ${QIMSDK_ACCELERATION_ENGINE_TMP_DIR}

    local QIMSDK_ARG_ACCELERATION_ENGINE_NAMES=(`cat ${PATH_TO_CONFIG_JSON} | jq '.Acceleration_engines[] | .Acceleration_engine' | tr -d '"'`)
    local QIMSDK_ACCELERATION_ENGINE_PATHS=(`cat ${PATH_TO_CONFIG_JSON} | jq '.Acceleration_engines[] | .Acceleration_engine_path' | tr -d '"'`)
    local QIMSDK_ACCELERATION_ENGINE_COUNT=`cat ${PATH_TO_CONFIG_JSON} | jq '.Acceleration_engines[] | .Acceleration_engine' | wc -l`

    for ((i=0 ; i<${QIMSDK_ACCELERATION_ENGINE_COUNT} ; i++)); do
        local ACCELERATION_ENGINE=${QIMSDK_ARG_ACCELERATION_ENGINE_NAMES[${i}]}
        local ACCELERATION_ENGINE_DIR=${QIMSDK_ACCELERATION_ENGINE_PATHS[${i}]}
        local ENGINE_INDEX=$(( $i + 1 ))
        [ -d "${ACCELERATION_ENGINE_DIR}" ]                                                     && \
            local ACCELERATION_ENGINE_TMP_PATH=${ACCELERATION_ENGINE}                           && \
                { rsync -a ${ACCELERATION_ENGINE_DIR}/* ${QIMSDK_ACCELERATION_ENGINE_TMP_DIR}/${ACCELERATION_ENGINE_TMP_PATH}/ || \
                    {
                        print-red "Cannot add ${ACCELERATION_ENGINE} dir to tmp folder !!!"
                        rm -rf ${QIMSDK_ACCELERATION_ENGINE_TMP_DIR}
                        return -8
                    }
                    rm -f ${QIMSDK_ACCELERATION_ENGINE_TMP_DIR}/${ACCELERATION_ENGINE_TMP_PATH}/lib/aarch64-oe-linux-gcc8.2/libatomic.so.1
                }                                                                               || \
                    {
                        ACCELERATION_ENGINE_TMP_PATH="no-acceleration-engine-${ENGINE_INDEX}-dir-available"
                        touch ${QIMSDK_ACCELERATION_ENGINE_TMP_DIR}/${ACCELERATION_ENGINE_TMP_PATH}
                    }
    done

    QIMSDK_ARG_ACCELERATION_ENGINE_NAMES=`cat ${PATH_TO_CONFIG_JSON} | jq '.Acceleration_engines[] | .Acceleration_engine' | tr -d '"'`

    local QIMSDK_ARG_DEPLOY_URL=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Deploy_URL' | tr -d '"'`
    QIMSDK_ARG_DEPLOY_URL=`echo ${QIMSDK_ARG_DEPLOY_URL}/ | sed 's/\/\//\//g'`

    local QIMSDK_ARG_DEPLOY_URL_DEV=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Deploy_dev_URL' | tr -d '"'`
    QIMSDK_ARG_DEPLOY_URL_DEV=`echo ${QIMSDK_ARG_DEPLOY_URL_DEV}/ | sed 's/\/\//\//g'`

    QIMSDK_ARG_DEPLOY_ARTIFACTS=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Deploy_QIMSDK_Artifacts_URL' | tr -d '"'`
    [ ! -d "${QIMSDK_ARG_DEPLOY_ARTIFACTS}" ]                                                   && \
        QIMSDK_ARG_DEPLOY_ARTIFACTS=no-artifacts-dir-provided                                   || \
        {
            QIMSDK_ARG_DEPLOY_ARTIFACTS=`echo ${QIMSDK_ARG_DEPLOY_ARTIFACTS}/ | sed 's/\/\//\//g'`
        }

    local QIMSDK_ARG_GST_PLUGINS_QTI_OSS_DEPENDENCIES=`cat ${PATH_TO_CONFIG_JSON} | jq '.Gst_plugins_qti_oss_dependencies[]' | tr -d '"'`

    DOCKER_BUILDKIT=1 docker build                                                                 \
            --build-arg QIMSDK_ARG_HOST_USER_ID=$(id -u ${USER})                                   \
            --build-arg QIMSDK_ARG_HOST_GROUP_ID=$(id -g ${USER})                                  \
            --build-arg QIMSDK_ARG_HOST_USER=${USER}                                               \
            --build-arg QIMSDK_ARG_HOST_GROUP=${GROUP}                                             \
            --build-arg QIMSDK_ARG_IMAGE_OS=${QIMSDK_ARG_IMAGE_OS}                                 \
            --build-arg QIMSDK_ARG_ESDK_SH=${QIMSDK_ARG_ESDK_SH}                                   \
            --build-arg QIMSDK_ARG_BASE_DIR=${QIMSDK_ARG_BASE_DIR}                                 \
            --build-arg QIMSDK_ARG_TFLITE_FILENAME=${QIMSDK_ARG_TFLITE_FILENAME}                   \
            --build-arg QIMSDK_ARG_ACCELERATION_ENGINE_NAMES="${QIMSDK_ARG_ACCELERATION_ENGINE_NAMES}" \
            --build-arg QIMSDK_ARG_DEPLOY_URL=${QIMSDK_ARG_DEPLOY_URL}                             \
            --build-arg QIMSDK_ARG_DEPLOY_URL_DEV=${QIMSDK_ARG_DEPLOY_URL_DEV}                     \
            --build-arg QIMSDK_ARG_GST_PLUGINS_QTI_OSS_DEPENDENCIES="${QIMSDK_ARG_GST_PLUGINS_QTI_OSS_DEPENDENCIES}" \
            -f ${QIMSDK_DOCKER_DIR}/Dockerfile                                                     \
            --progress=plain --target qimsdk ${QIMSDK_REPO_BASE_DIR} -t qimsdk:${TAG}

    local rc=$?
    rm -rf ${QIMSDK_TMP_DIR}
    [ "${rc}" -ne 0 ] && print-red "Build image failed !!!" && return -9

    print-green "Build image completed successfully !!!"
    return 0;
}

# Docker run container based on compiled docker image
#   $1 - (mandatory) path to target config json
function qimsdk-docker-run-container() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local ADDITIONAL_TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Additional_tag' | tr -d '"'`
    [ -z "${TAG}" ] && print-red "Image name must be provided as first argument of json !!!" && return -2
    [[ ! -z "${ADDITIONAL_TAG}" ]] && ADDITIONAL_TAG="-${ADDITIONAL_TAG}"

    local CONTAINER_NAME="qimsdk-${TAG}${ADDITIONAL_TAG}"
    local GROUP=$(getent group $(id -g ${USER}) | cut -d ':' -f 1)

    local DIR_TO_BE_MOUNTED=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Host_dir_mounted_in_container' | tr -d '"'`
    [[ ! -z "${DIR_TO_BE_MOUNTED}" ]] && DIR_TO_BE_MOUNTED="-v ${DIR_TO_BE_MOUNTED}:/home/${USER}/work"

    local QIMSDK_ARG_BASE_DIR=/mnt/qimsdk
    local QIMSDK_REPO_BASE_DIR=${QIMSDK_DOCKER_DIR}/..

    docker run ${DIR_TO_BE_MOUNTED}                                                                \
        -v /dev/bus/usb:/dev/bus/usb:ro                                                            \
        -v /etc/timezone:/etc/timezone:ro                                                          \
        -v /etc/localtime:/etc/localtime:ro                                                        \
        -it -d --privileged -h qimsdk-${TAG} --user ${USER}                                        \
        --name ${CONTAINER_NAME} qimsdk:${TAG} bash                                                  || \
        {
            print-red "Docker run failed !!!"
            return -3
        }

    # Propagate ssh and gitconfig to container
    docker exec --user ${USER} ${CONTAINER_NAME} mkdir /home/${USER}/.ssh                                           || \
        {
            print-red "docker mkdir ~/.ssh failed !!!"
            return -4
        }

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp ${f} ${CONTAINER_NAME}:/home/${USER}/.ssh/${BASE_NAME}                                        || \
                {
                    print-red "Propagating .ssh/ to docker failed !!!"
                    return -5
                }
        done
        docker exec --user root ${CONTAINER_NAME} chown -R ${USER}:${GROUP} /home/${USER}/.ssh                      || \
            {
                print-red "Propagating .ssh/ to docker failed !!!"
                return -6
            }
    fi

    if [ -f ~/.gitconfig ]; then
        docker cp ~/.gitconfig ${CONTAINER_NAME}:/home/${USER}/.gitconfig                                           && \
            docker exec --user root ${CONTAINER_NAME} chown -R ${USER}:${GROUP} /home/${USER}/.gitconfig            || \
                {
                    print-red "Propagating .gitconfig to docker failed !!!"
                    return -7
                }
    fi

    if [ -f /etc/gitconfig ]; then
        docker cp /etc/gitconfig ${CONTAINER_NAME}:/etc/gitconfig                                                   || \
            {
                print-red "Propagating .gitconfig to docker failed !!!"
                return -8
            }
    fi

    print-green "Docker run successful !!!"
    print-green "docker attach to ${CONTAINER_NAME} !!!"
}

# Docker remove container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-rm-container() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local ADDITIONAL_TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Additional_tag' | tr -d '"'`
    [ -z "${TAG}" ] && print-red "Image name must be provided as first argument of json !!!" && return -2
    [[ ! -z "${ADDITIONAL_TAG}" ]] && ADDITIONAL_TAG="-${ADDITIONAL_TAG}"

    docker rm qimsdk-${TAG}${ADDITIONAL_TAG}
    local rc=$?
    [ "${rc}" -ne 0 ] && print-red "Container removal failed !!!" && return -3

    print-green "Remove container completed successfully !!!"
}

# Docker start container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-start-container() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local ADDITIONAL_TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Additional_tag' | tr -d '"'`
    [ -z "${TAG}" ] && print-red "Image name must be provided as first argument of json !!!" && return -2
    [[ ! -z "${ADDITIONAL_TAG}" ]] && ADDITIONAL_TAG="-${ADDITIONAL_TAG}"

    docker start qimsdk-${TAG}${ADDITIONAL_TAG}
    local rc=$?
    [ "${rc}" -ne 0 ] && print-red "parsing json failed !!!" && return -3

    docker start ${CONTAINER_NAME}                                                                                  || \
        {
            print-red "Start container failed !!!"
            return -4
        }

    print-green "Container started successfully !!!"
}

# Docker stop container
#   $1 - (mandatory) path to target config json
function qimsdk-docker-stop-container() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local ADDITIONAL_TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Additional_tag' | tr -d '"'`
    [ -z "${TAG}" ] && print-red "Image name must be provided as first argument of json !!!" && return -2
    [[ ! -z "${ADDITIONAL_TAG}" ]] && ADDITIONAL_TAG="-${ADDITIONAL_TAG}"

    docker stop qimsdk-${TAG}${ADDITIONAL_TAG}
    local rc=$?
    [ "${rc}" -ne 0 ] && print-red "Container stop failed !!!" && return -3

    print-green "Stop container completed successfully !!!"
}

# Clean up old docker images and build cache
function qimsdk-docker-cleanup() {
    docker rmi $(docker images | grep "^<none>" | awk '{print $3}' )
    docker builder prune -a -f

    print-green "Clean up old docker images and build cache completed successfully !!!"
}

# Wrapper function to build docker image and extract QIMSDK Artifacts to user specified directory in host machine
#   $1 - (mandatory) path to target config json
function qimsdk-docker-build-and-sync-artifacts-all() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local QIMSDK_ARG_IMAGE_OS=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local TAG="${QIMSDK_ARG_IMAGE_OS}"

    qimsdk-docker-build-image "${PATH_TO_CONFIG_JSON}"

    [ "${QIMSDK_ARG_DEPLOY_ARTIFACTS}" == "no-artifacts-dir-provided" ]                         && \
        {
            print-red "No Deploy_QIMSDK_Artifacts_URL dir provided in config json !!!"
            return -2
        }                                                                                       || \
        {
            local ID=$(docker create --name tempcontainer qimsdk:${TAG});
            [ ! -z "${ID}" ]                                                                    && \
                {
                    docker cp ${ID}:/mnt/qimsdk/work/artifacts/packages.zip ${QIMSDK_ARG_DEPLOY_ARTIFACTS};
                    docker rm tempcontainer;
                }                                                                               || \
                {
                    print-red "Syncing QIMSDK artifacts from docker image failed !!!"
                    return -3
                }
        }

    print-green "Artifacts synced succesfully to ${QIMSDK_ARG_DEPLOY_ARTIFACTS}"
    return 0
}

# Wrapper function to build docker image and extract QIMSDK Release Artifacts to user specified directory in host machine
#   $1 - (mandatory) path to target config json
function qimsdk-docker-build-and-sync-artifacts-rel() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local QIMSDK_ARG_IMAGE_OS=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local TAG="${QIMSDK_ARG_IMAGE_OS}"

    qimsdk-docker-build-image "${PATH_TO_CONFIG_JSON}"

    [ "${QIMSDK_ARG_DEPLOY_ARTIFACTS}" == "no-artifacts-dir-provided" ]                         && \
        {
            print-red "No Deploy_QIMSDK_Artifacts_URL dir provided in config json !!!"
            return -2
        }                                                                                       || \
        {
            local ID=$(docker create --name tempcontainer qimsdk:${TAG});
            [ ! -z "${ID}" ]                                                                    && \
                {
                    docker cp ${ID}:/mnt/qimsdk/work/artifacts/packages_rel.zip ${QIMSDK_ARG_DEPLOY_ARTIFACTS};
                    docker rm tempcontainer;
                }                                                                               || \
                {
                    print-red "Syncing QIMSDK release artifacts from docker image failed !!!"
                    return -3
                }
        }

    print-green "Artifacts synced succesfully to ${QIMSDK_ARG_DEPLOY_ARTIFACTS}"
    return 0
}

# Wrapper function to build docker image and extract QIMSDK Development Artifacts to user specified directory in host machine
#   $1 - (mandatory) path to target config json
function qimsdk-docker-build-and-sync-artifacts-dev() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local QIMSDK_ARG_IMAGE_OS=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local TAG="${QIMSDK_ARG_IMAGE_OS}"

    qimsdk-docker-build-image "${PATH_TO_CONFIG_JSON}"

    [ "${QIMSDK_ARG_DEPLOY_ARTIFACTS}" == "no-artifacts-dir-provided" ]                         && \
        {
            print-red "No Deploy_QIMSDK_Artifacts_URL dir provided in config json !!!"
            return -2
        }                                                                                       || \
        {
            local ID=$(docker create --name tempcontainer qimsdk:${TAG});
            [ ! -z "${ID}" ]                                                                    && \
                {
                    docker cp ${ID}:/mnt/qimsdk/work/artifacts/packages_dev.zip ${QIMSDK_ARG_DEPLOY_ARTIFACTS};
                    docker rm tempcontainer;
                }                                                                               || \
                {
                    print-red "Syncing QIMSDK development artifacts from docker image failed !!!"
                    return -3
                }
        }

    print-green "Artifacts synced succesfully to ${QIMSDK_ARG_DEPLOY_ARTIFACTS}"
    return 0
}

QIMSDK_DOCKER_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/../.. && pwd )"
[ -f ${QIMSDK_DOCKER_DIR}/Dockerfile ] || QIMSDK_DOCKER_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/sdk-tools && pwd )"

echo -e "Docker environment setup ready !!!\n"

print-green "qimsdk-docker-build-image <path-to-config-json>"
echo "    Build docker image based on Dockerfile in $QIMSDK_DOCKER_DIR"
print-green "qimsdk-docker-run-container <path-to-config-json>"
echo "    Run docker container based on compiled docker image"
print-blue "qimsdk-docker-rm-container <path-to-config-json>"
echo "    Remove docker container based on compiled docker image"
print-blue "qimsdk-docker-start-container <path-to-config-json>"
echo "    Start docker container based on compiled docker image"
print-blue "qimsdk-docker-stop-container <path-to-config-json>"
echo "    Stop docker container based on compiled docker image"
print-yellow "qimsdk-docker-build-and-sync-artifacts-all <path-to-config-json>"
echo "    Build docker image and extract QIMSDK Artifacts to user specified directory in host machine"
print-yellow "qimsdk-docker-build-and-sync-artifacts-rel <path-to-config-json>"
echo "    Build docker image and extract QIMSDK Release Artifacts to user specified directory in host machine"
print-yellow "qimsdk-docker-build-and-sync-artifacts-dev <path-to-config-json>"
echo "    Build docker image and extract QIMSDK Development Artifacts to user specified directory in host machine"
print-red "qimsdk-docker-cleanup"
echo "    Clean up old docker images and build cache"
