#!/bin/bash

# Copyright (c) 2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Parse json configuraiton
#   $1 - (mandatory) path to target config json
function qimsdk-host-parse-json() {
    PATH_TO_CONFIG_JSON=$1

    [ ! -f "${PATH_TO_CONFIG_JSON}" ]                                                           && \
        print-red "Path to config json must be provided as first argument !!!"                  && \
        return -1

    local BUFFER=`cat ${PATH_TO_CONFIG_JSON}`

    eSDK_PATH=`echo ${BUFFER} | jq '.eSDK_path' | tr -d '"'`
    eSDK_NAME=`echo ${BUFFER} | jq '.eSDK_shell_file' | tr -d '"'`

    BASE_DIR_LOCATION=`echo ${BUFFER} | jq '.Base_Dir_Location' | tr -d '"'`

    QIMSDK_ESDK_TFLITE_FILE_PATH=`echo ${BUFFER} | jq '.Tflite_path' | tr -d '"'`
    QIMSDK_ESDK_TFLITE_FILENAME=`echo ${BUFFER} | jq '.Tflite_prebuilt_file' | tr -d '"'`
    QIMSDK_ESDK_TFLITE_FILE=${QIMSDK_ESDK_TFLITE_FILE_PATH}/${QIMSDK_ESDK_TFLITE_FILENAME}

    [ -z "${QIMSDK_ESDK_TFLITE_FILE_PATH}" ] || [ -z "${QIMSDK_ESDK_TFLITE_FILENAME}" ] || [ ! -f ${QIMSDK_ESDK_TFLITE_FILE} ] && \
        {
            QIMSDK_ESDK_TFLITE_FILENAME="no-tflite-dev-archive-available"
        }

    QIMSDK_ESDK_DEPLOY_URL=`echo ${BUFFER} | jq '.Deploy_URL' | tr -d '"'`
    QIMSDK_ESDK_DEPLOY_URL=`echo ${QIMSDK_ESDK_DEPLOY_URL}/ | sed 's/\/\//\//g'`

    QIMSDK_ESDK_DEPLOY_URL_DEV=`echo ${BUFFER} | jq '.Deploy_dev_URL' | tr -d '"'`
    QIMSDK_ESDK_DEPLOY_URL_DEV=`echo ${QIMSDK_ESDK_DEPLOY_URL_DEV}/ | sed 's/\/\//\//g'`

    QIMSDK_ESDK_GST_PLUGINS_QTI_OSS_DEPENDENCIES=`echo ${BUFFER} | jq '.Gst_plugins_qti_oss_dependencies[]' | tr -d '"'`

    [ ! -d "${eSDK_PATH}" ] && print-red "Path to ESDK Directory does not exist !!!" && return -1
    [ -z "${eSDK_PATH}" ] && print-red "ESDK path must be provided as an argument of config json !!!" && return -2
    [ -z "${eSDK_NAME}" ] && print-red "ESDK shell file must be provided as an argument of config json !!!" && return -3
    [ ! -f ${eSDK_PATH}/${eSDK_NAME} ] && print-red "Could not find ESDK_SH !!!" && return -4
    [ ! -d "${BASE_DIR_LOCATION}" ] && print-red "Path to the directory where the project is initialized must be provided as an argument of config json !!!" && return -5

    return 0
}

# Build IM SDK in host machine
#   $1 - (mandatory) path to target config json
function qimsdk-setup() {
    local rc

    local PATH_TO_CONFIG_JSON=$1

    qimsdk-check-system-shell
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-check-system-shell"
        return $rc
    }

    qimsdk-check-required-packages
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-check-required-packages"
        return $rc
    }

    qimsdk-check-python-version
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-check-python-version"
        return $rc
    }

    qimsdk-host-parse-json ${PATH_TO_CONFIG_JSON}
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-host-parse-json"
        return $rc
    }

    export eSDK_PATH
    export eSDK_NAME
    export BASE_DIR_LOCATION
    export QIMSDK_ESDK_BASE_DIR
    export QIMSDK_ESDK_DEPLOY_URL
    export QIMSDK_ESDK_DEPLOY_URL_DEV
    export QIMSDK_WORK_DIR
    export QIMSDK_ESDK_TFLITE_FILE
    export QIMSDK_ESDK_TFLITE_FILENAME
    export QIMSDK_ESDK_SNPE_DIR
    export QIMSDK_ESDK_GST_PLUGINS_QTI_OSS_DEPENDENCIES

    qimsdk-common
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-common"
        return $rc
    }

    ln -sf ${BASE_DIR_LOCATION}/src/* ${QIMSDK_SRC_DIR}

    qimsdk-builder
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-builder"
        return $rc
    }

    return 0
}

# Remove IM SDK from host machine
#   $1 - (mandatory) path to target config json
function qimsdk-remove() {
    local PATH_TO_CONFIG_JSON=$1
    local rc

    qimsdk-host-parse-json ${PATH_TO_CONFIG_JSON}
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-host-parse-json"
        return $rc
    }

    rm -rf $BASE_DIR_LOCATION

    print-green "IM SDK removed"
    return 0
}

# Prepare directories
function qimsdk-common() {
    local rc

    source ${QIMSDK_TOOLS_DIR}/scripts/host/qimsdk-common.sh

    qimsdk-create-dirs
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-create-dirs"
        popd 1>/dev/null
        return $rc
    }

    pushd ${QIMSDK_DOWNLOAD_DIR} 1>/dev/null

    qimsdk-install-esdk
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-install-esdk"
        popd 1>/dev/null
        return $rc
    }

    qimsdk-setup-tflite
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-setup-tflite"
        popd 1>/dev/null
        return $rc
    }

    qimsdk-setup-snpe
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-setup-snpe"
        popd 1>/dev/null
        return $rc
    }

    popd 1>/dev/null

    return 0
}

# Prepare, build and package all layers
function qimsdk-builder() {
    local rc

    ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-layers-prepare-build-package

    return 0
}

# Check if default system shell is pointing to bash
function qimsdk-check-system-shell()
{
    [ $(readlink -f $(which sh)) != "/bin/bash" ]                                                 &&
    {
        print-red "Please change the default command interpreter for shell scripts to bash";
        print-blue sudo ln -sf /bin/bash /bin/sh;
        return -1
    }

    return 0
}

# Check for necessary packages
function qimsdk-check-required-packages() {
    source ${QIMSDK_TOOLS_DIR}/scripts/image/common/tools.sh

    local NOT_INSTALLED_PKGS=""
    local REQUIRED_PKGS="sudo python2.7 python3 python3-pip zip unzip curl wget gnupg flex bison   \
        build-essential zlib1g-dev zstd gcc-multilib g++-multilib libc6-dev-i386 libncurses5 cpio  \
        lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils   \
        xsltproc fontconfig cmake texinfo chrpath diffstat xmlstarlet libarchive-dev ssh uuid-dev  \
        libselinux1-dev g++ gawk gcc make libwayland-dev fakeroot libpam0g-dev binutils-dev git jq \
        openjdk-8-jdk-headless util-linux whiptail libxml-simple-perl bash-completion openssl gdb  \
        software-properties-common locales lcov libbz2-dev libffi-dev libgdbm-dev usbutils file    \
        libgdbm-compat-dev liblzma-dev libncurses5-dev libreadline-dev libsqlite3-dev libssl-dev   \
        lzma lzma-dev tk-dev language-pack-en-base android-tools-adb android-tools-fastboot        \
        fakechroot libiberty-dev"

    for PKG in ${REQUIRED_PKGS[@]}; do
        dpkg-query -s ${PKG} > /dev/null 2>&1 || NOT_INSTALLED_PKGS+=${PKG}" "
    done

    [ -n "${NOT_INSTALLED_PKGS}" ] && {
        print-red "THESE PACKAGES NEED TO BE INSTALLED:"
        echo ${NOT_INSTALLED_PKGS}
        print-blue "sudo apt install ${NOT_INSTALLED_PKGS}"
        return -1
    } || print-green "All the system required packages are installed!"

    return 0
}

# Check python version
function qimsdk-check-python-version()
{
    [ $(python --version 2>&1 | awk '{print $2}'| cut -c1-3) != "2.7" ]                          &&
    {
        print-red "Python version 2.7 is required";
        return -1;
    }

    return 0
}

QIMSDK_TOOLS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/../../ && pwd )"
source ${QIMSDK_TOOLS_DIR}/scripts/image/common/tools.sh

print-green "qimsdk-setup                                             <path/to/targets/.json>"
echo "    Build IM SDK in host machine"
print-green "qimsdk-remove                                            <path/to/targets/.json>"
echo "    Remove IM SDK from host machine"
