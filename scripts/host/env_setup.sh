#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

echo "Docker environemnt setup"
echo "========================"

function print-red()
{
    tput setaf 1 && echo $1 && tput sgr0
}

function print-green()
{
    tput setaf 2 && echo $1 && tput sgr0
}

function print-blue()
{
    tput setaf 4 && echo $1 && tput sgr0
}

# Build docker image based on Dockerfile in folder $QIMSDK_DOCKER_FOLDER
#   $1 - (mandatory) path to target config json that contains the following:
#           - (mandatory) image os - ubuntu18 or ubuntu20
#           - (optional) additional name suffix
#           - (mandatory) path to esdk dir (found in <path-to-workspace>/build-qti-distro-fullstack-debug/tmp-glibc/deploy/sdk)
#           - (mandatory) esdk shell file (from esdk dir)
#           - (optional) path to directory to be mounted in docker container
#           - (optional) sync url prefix - url from which to sync repositories
function qimsdk-docker-build-image() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local QIMSDK_ARG_IMAGE_OS=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local QIMSDK_ESDK_PATH=`cat ${PATH_TO_CONFIG_JSON} |  jq '.eSDK_path' | tr -d '"'`
    local QIMSDK_ARG_ESDK_SH=`cat ${PATH_TO_CONFIG_JSON} |  jq '.eSDK_shell_file' | tr -d '"'`
    [ ! "${QIMSDK_ARG_IMAGE_OS}" == "ubuntu18" ] && [ ! "${QIMSDK_ARG_IMAGE_OS}" == "ubuntu20" ] && \
        print-red "Wrong OS name - Avaliable OS are ubuntu18 and ubuntu20 !!!" && return -2
    [ ! -d "${QIMSDK_ESDK_PATH}" ] && print-red "Path to ESDK Directory does not exist !!!" && return -3
    [ -z "${QIMSDK_ARG_IMAGE_OS}" ] && print-red "Image OS name (ubuntu18 or ubuntu20) must be provided as an argument of config json !!!" && return -4
    [ -z "${QIMSDK_ESDK_PATH}" ] && print-red "ESDK path must be provided as an argument of config json !!!" && return -5
    [ -z "${QIMSDK_ARG_ESDK_SH}" ] && print-red "ESDK shell file must be provided as an argument of config json !!!" && return -6
    [ ! -f ${QIMSDK_ESDK_PATH}/${QIMSDK_ARG_ESDK_SH} ] && print-red "Could not find ESDK_SH !!!" && return -7

    local TAG="${QIMSDK_ARG_IMAGE_OS}"
    local QIMSDK_ARG_BASE_FOLDER=/mnt/qimsdk
    local GROUP=$(getent group $(id -g ${USER}) | cut -d ':' -f 1)

    mkdir -p ${QIMSDK_DOCKER_FOLDER}/tmp
    ln ${QIMSDK_ESDK_PATH}/${QIMSDK_ARG_ESDK_SH} ${QIMSDK_DOCKER_FOLDER}/tmp/                   || \
        rsync -a ${QIMSDK_ESDK_PATH}/${QIMSDK_ARG_ESDK_SH} ${QIMSDK_DOCKER_FOLDER}/tmp/         || \
        {
            print-red "Cannot add sdk sh file to tmp folder !!!"
            return -8
        }

    local TFLITE_FILE_PATH=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Tflite_path' | tr -d '"'`
    local TFLITE_FILENAME=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Tflite_prebuilt_file' | tr -d '"'`
    local TFLITE_FILE=${TFLITE_FILE_PATH}/${TFLITE_FILENAME}
    [ -f "${TFLITE_FILE}" ]                                                                     && \
        local QIMSDK_ARG_TFLITE_FILE=${TFLITE_FILENAME}                                         && \
            ( ln ${TFLITE_FILE} ${QIMSDK_DOCKER_FOLDER}/tmp/                                    || \
                rsync -a ${TFLITE_FILE} ${QIMSDK_DOCKER_FOLDER}/tmp/                            || \
                {
                    print-red "Cannot add tflite dev archive to tmp folder !!!"
                    return -9
                }
            )                                                                                   || \
                local QIMSDK_ARG_TFLITE_FILE=no-tflite-dev-archive-available                    && \
                touch ${QIMSDK_DOCKER_FOLDER}/tmp/${QIMSDK_ARG_TFLITE_FILE}

    local SYNC_URL_PREFIX=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Sync_URL_prefix' | tr -d '"'`
    local QIMSDK_ARG_SYNC_URL_PREFIX="https://git.codelinaro.org/clo/le"
    [ ! -z "${SYNC_URL_PREFIX}" ] && QIMSDK_ARG_SYNC_URL_PREFIX="${SYNC_URL_PREFIX}"

    local QIMSDK_ARG_DEPLOY_URL=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Deploy_URL' | tr -d '"'`
    QIMSDK_ARG_DEPLOY_URL=`echo ${QIMSDK_ARG_DEPLOY_URL}/ | sed 's/\/\//\//g'`

    DOCKER_BUILDKIT=1 docker build                                                                 \
            --build-arg QIMSDK_ARG_HOST_USER_ID=$(id -u ${USER})                                   \
            --build-arg QIMSDK_ARG_HOST_GROUP_ID=$(id -g ${USER})                                  \
            --build-arg QIMSDK_ARG_HOST_USER=${USER}                                               \
            --build-arg QIMSDK_ARG_HOST_GROUP=${GROUP}                                             \
            --build-arg QIMSDK_ARG_IMAGE_OS=${QIMSDK_ARG_IMAGE_OS}                                 \
            --build-arg QIMSDK_ARG_ESDK_SH=${QIMSDK_ARG_ESDK_SH}                                   \
            --build-arg QIMSDK_ARG_BASE_FOLDER=${QIMSDK_ARG_BASE_FOLDER}                           \
            --build-arg QIMSDK_ARG_SYNC_URL_PREFIX=${QIMSDK_ARG_SYNC_URL_PREFIX}                   \
            --build-arg QIMSDK_ARG_TFLITE_FILE=${QIMSDK_ARG_TFLITE_FILE}                           \
            --build-arg QIMSDK_ARG_DEPLOY_URL=${QIMSDK_ARG_DEPLOY_URL}                             \
            --progress=plain --target qimsdk ${QIMSDK_DOCKER_FOLDER} -t qimsdk:${TAG}

    local rc=$?
    rm -rf ${QIMSDK_DOCKER_FOLDER}/tmp
    [ $rc -ne 0 ] && print-red "Build image failed !!!" && return -10

    print-green "Build image completed successfully !!!"
}

# Docker run container based on compiled docker image
#   $1 - (mandatory) path to target config json that contains the following:
#           - (mandatory) image os - ubuntu18 or ubuntu20
#           - (optional) additional name suffix
#           - (mandatory) path to esdk dir (found in <path-to-workspace>/build-qti-distro-fullstack-debug/tmp-glibc/deploy/sdk)
#           - (mandatory) esdk shell file (from esdk dir)
#           - (optional) path to directory to be mounted in docker container
#           - (optional) sync url prefix - url from which to sync repositories
function qimsdk-docker-run-container() {
    local PATH_TO_CONFIG_JSON=$1
    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && \
        print-red "Path to target configuration json must be provided as first argument !!!" && return -1

    local TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Image_OS' | tr -d '"'`
    local ADDITIONAL_TAG=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Additional_tag' | tr -d '"'`
    [ -z "${TAG}" ] && print-red "Image name must be provided as first argument of json !!!" && return -2
    [[ ! -z "${ADDITIONAL_TAG}" ]] && ADDITIONAL_TAG="-${ADDITIONAL_TAG}"

    local CONTAINER="qimsdk-${TAG}${ADDITIONAL_TAG}"
    local GROUP=$(getent group $(id -g ${USER}) | cut -d ':' -f 1)

    local DIR_TO_BE_MOUNTED=`cat ${PATH_TO_CONFIG_JSON} |  jq '.Host_dir_mounted_in_container' | tr -d '"'`
    [[ ! -z "${DIR_TO_BE_MOUNTED}" ]] && DIR_TO_BE_MOUNTED="-v ${DIR_TO_BE_MOUNTED}:/home/${USER}/work"

    local QIMSDK_ARG_BASE_FOLDER=/mnt/qimsdk
    local QIMSDK_REPO_BASE_FOLDER=${QIMSDK_DOCKER_FOLDER}/..

    docker run ${DIR_TO_BE_MOUNTED}                                                                \
        -v /dev/bus/usb:/dev/bus/usb:ro                                                            \
        -v /etc/timezone:/etc/timezone:ro                                                          \
        -v /etc/localtime:/etc/localtime:ro                                                        \
        -v ${QIMSDK_REPO_BASE_FOLDER}:${QIMSDK_ARG_BASE_FOLDER}/repo                               \
        -it -d --privileged -h qimsdk-${TAG} --user ${USER}                                        \
        --name ${CONTAINER} qimsdk:${TAG}

    local rc=$?
    [ $rc -ne 0 ] && print-red "docker run failed !!!" && return -3

    # Add soft link to src and poky
    docker exec --user ${USER} ${CONTAINER} ln -s ${QIMSDK_ARG_BASE_FOLDER}/repo/src ${QIMSDK_ARG_BASE_FOLDER}/esdk/layers/src
    rc=$?
    [ $rc -ne 0 ] && print-red "docker ln -s ${QIMSDK_ARG_BASE_FOLDER}/repo/src ${QIMSDK_ARG_BASE_FOLDER}/esdk/layers/src !!!" && return -4
    docker exec --user ${USER} ${CONTAINER} ln -s ${QIMSDK_ARG_BASE_FOLDER}/repo/poky ${QIMSDK_ARG_BASE_FOLDER}/poky
    rc=$?
    [ $rc -ne 0 ] && print-red "docker ln -s ${QIMSDK_ARG_BASE_FOLDER}/repo/poky ${QIMSDK_ARG_BASE_FOLDER}/poky !!!" && return -5

    # Propagate ssh and gitconfig to container
    docker exec --user ${USER} ${CONTAINER} mkdir /home/${USER}/.ssh
    rc=$?
    [ $rc -ne 0 ] && print-red "docker mkdir ~/.ssh failed !!!" && return -6

    if [ -d ~/.ssh/ ]; then
        local f
        for f in ~/.ssh/*; do
            local BASE_NAME=`basename $f`
            test "${f}" = ~/.ssh/known_hosts && continue
            docker cp $f ${CONTAINER}:/home/${USER}/.ssh/${BASE_NAME}
            rc=$?
            [ $rc -ne 0 ] && print-red "Propagating .ssh/ to docker failed !!!" && return -7
        done
        docker exec --user root ${CONTAINER} chown -R ${USER}:${GROUP} /home/${USER}/.ssh
        rc=$?
        [ $rc -ne 0 ] && print-red "Propagating .ssh/ to docker failed !!!" && return -8
    fi

    if [ -f ~/.gitconfig ]; then
        docker cp ~/.gitconfig ${CONTAINER}:/home/${USER}/.gitconfig                            && \
            docker exec --user root ${CONTAINER} chown -R ${USER}:${GROUP} /home/${USER}/.gitconfig
        rc=$?
        [ $rc -ne 0 ] && print-red "Propagating .gitconfig to docker failed !!!" && return -9
    fi

    if [ -f /etc/gitconfig ]; then
        docker cp /etc/gitconfig ${CONTAINER}:/etc/gitconfig
        rc=$?
        [ $rc -ne 0 ] && print-red "Propagating .gitconfig to docker failed !!!" && return -10
    fi

    docker exec --user ${USER} ${CONTAINER} mkdir -p /mnt/qimsdk/targets
    docker cp ${PATH_TO_CONFIG_JSON} ${CONTAINER}:/mnt/qimsdk/targets/config.json               && \
        docker exec --user root ${CONTAINER} chown -R ${USER}:${GROUP} /mnt/qimsdk/targets      || \
        {
            print-red "Propagating config json to docker failed !!!"
            return -11
        }

    print-green "Docker ${CONTAINER} run successfull !!!"
    print-green "Please attach to docker container with name: ${CONTAINER}"
}

# Docker remove container
#   $1 - (mandatory) path to target config json that contains the following:
#           - (mandatory) image os - ubuntu18 or ubuntu20
#           - (optional) additional name suffix
#           - (mandatory) path to esdk dir (found in <path-to-workspace>/build-qti-distro-fullstack-debug/tmp-glibc/deploy/sdk)
#           - (mandatory) esdk shell file (from esdk dir)
#           - (optional) path to directory to be mounted in docker container
#           - (optional) sync url prefix - url from which to sync repositories
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
    [ $rc -ne 0 ] && print-red "Container removal failed !!!" && return -3

    print-green "Remove container completed successfully !!!"
}

# Docker start container
#   $1 - (mandatory) path to target config json that contains the following:
#           - (mandatory) image os - ubuntu18 or ubuntu20
#           - (optional) additional name suffix
#           - (mandatory) path to esdk dir (found in <path-to-workspace>/build-qti-distro-fullstack-debug/tmp-glibc/deploy/sdk)
#           - (mandatory) esdk shell file (from esdk dir)
#           - (optional) path to directory to be mounted in docker container
#           - (optional) sync url prefix - url from which to sync repositories
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
    [ $rc -ne 0 ] && print-red "Container start failed !!!" && return -3

    print-green "Start container completed successfully !!!"
}

# Docker stop container
#   $1 - (mandatory) path to target config json that contains the following:
#           - (mandatory) image os - ubuntu18 or ubuntu20
#           - (optional) additional name suffix
#           - (mandatory) path to esdk dir (found in <path-to-workspace>/build-qti-distro-fullstack-debug/tmp-glibc/deploy/sdk)
#           - (mandatory) esdk shell file (from esdk dir)
#           - (optional) path to directory to be mounted in docker container
#           - (optional) sync url prefix - url from which to sync repositories
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
    [ $rc -ne 0 ] && print-red "Container stop failed !!!" && return -3

    print-green "Stop container completed successfully !!!"
}

# Clean up old docker images and build cache
function qimsdk-docker-cleanup() {
    docker rmi $(docker images | grep "^<none>" | awk '{print $3}' )
    docker builder prune -a -f

    print-green "Clean up old docker images and build cache completed successfully !!!"
}

QIMSDK_DOCKER_FOLDER="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/../.. && pwd )"

echo -e "Docker environment setup ready !!!\n"

print-green "qimsdk-docker-build-image <path-to-config-json>"
echo "    Build docker image based on Dockerfile in $QIMSDK_DOCKER_FOLDER"
print-green "qimsdk-docker-run-container <path-to-config-json>"
echo "    Run docker container based on compiled docker image"
print-blue "qimsdk-docker-rm-container <path-to-config-json>"
echo "    Remove docker container based on compiled docker image"
print-blue "qimsdk-docker-start-container <path-to-config-json>"
echo "    Start docker container based on compiled docker image"
print-blue "qimsdk-docker-stop-container <path-to-config-json>"
echo "    Stop docker container based on compiled docker image"
print-red "qimsdk-docker-cleanup"
echo "    Clean up old docker images and build cache"
