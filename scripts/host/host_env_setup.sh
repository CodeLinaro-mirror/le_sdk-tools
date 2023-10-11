#!/bin/bash

# Copyright (c) 2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Parse json configuraiton
#   $1 - (mandatory) path to target config json
function qimsdk-host-parse-json() {
    local PATH_TO_CONFIG_JSON=$1

    [ ! -f "${PATH_TO_CONFIG_JSON}" ]                                                           && \
        print-red "Path to config json must be provided as first argument !!!"                  && \
        return -1

    local BUFFER=`cat ${PATH_TO_CONFIG_JSON}`

    eSDK_SHELL_FILE=`echo ${BUFFER} | jq '.eSDK_shell_file' | tr -d '"'`
    eSDK_NAME=`basename ${eSDK_SHELL_FILE%.*}`

    BASE_DIR_LOCATION=`echo ${BUFFER} | jq '.Base_Dir_Location' | tr -d '"'`

    QIMSDK_ESDK_TFLITE_FILE=`echo ${BUFFER} | jq '.Tflite_prebuilt_file' | tr -d '"'`
    QIMSDK_ESDK_TFLITE_FILENAME="no-tflite-dev-archive-available"

    [ -f "${QIMSDK_ESDK_TFLITE_FILE}" ]                                                         && \
        QIMSDK_ESDK_TFLITE_FILENAME=`basename ${QIMSDK_ESDK_TFLITE_FILE}`

    QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES=(`echo ${BUFFER} | jq '.Acceleration_engines[] | .Acceleration_engine' | tr -d '"'`)
    QIMSDK_ACCELERATION_ENGINE_PATHS=(`echo ${BUFFER} | jq '.Acceleration_engines[] | .Acceleration_engine_path' | tr -d '"'`)
    QIMSDK_ACCELERATION_ENGINE_COUNT=`echo ${BUFFER} | jq '.Acceleration_engines[] | .Acceleration_engine' | wc -l`

    QIMSDK_ESDK_DEPLOY_URL=`echo ${BUFFER} | jq '.Deploy_URL' | tr -d '"'`
    [ -z "${QIMSDK_ESDK_DEPLOY_URL}" ]                                                          || \
        {
            QIMSDK_ESDK_DEPLOY_URL=`echo ${QIMSDK_ESDK_DEPLOY_URL}/ | sed 's/\/\//\//g'`
        }

    QIMSDK_ESDK_DEPLOY_URL_DEV=`echo ${BUFFER} | jq '.Deploy_dev_URL' | tr -d '"'`
    [ -z "${QIMSDK_ESDK_DEPLOY_URL_DEV}" ]                                                      || \
        {
            QIMSDK_ESDK_DEPLOY_URL_DEV=`echo ${QIMSDK_ESDK_DEPLOY_URL_DEV}/ | sed 's/\/\//\//g'`
        }

    QIMSDK_ESDK_DEPLOY_ARTIFACTS=`echo ${BUFFER} |  jq '.Deploy_QIMSDK_Artifacts_URL' | tr -d '"'`
    [ ! -d "${QIMSDK_ESDK_DEPLOY_ARTIFACTS}" ]                                                  && \
        QIMSDK_ESDK_DEPLOY_ARTIFACTS=no-artifacts-dir-provided                                  || \
        {
            QIMSDK_ESDK_DEPLOY_ARTIFACTS=`echo ${QIMSDK_ESDK_DEPLOY_ARTIFACTS}/ | sed 's/\/\//\//g'`
        }

    QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG=`echo ${BUFFER} |  jq '.Deploy_QIMSDK_Artifacts_tag' | tr -d '"'`
    [ -z "${QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG}" ]                                                || \
        {
            QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG="_${QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG}"
        }

    QIMSDK_ESDK_GST_PACKAGE_GROUP=`cat ${PATH_TO_CONFIG_JSON} | jq '.Gst_package_group' | tr -d '"'`
    [ "${QIMSDK_ESDK_GST_PACKAGE_GROUP}" != "packagegroup-qti-gst" ]                            && \
        [ "${QIMSDK_ESDK_GST_PACKAGE_GROUP}" != "packagegroup-qti-gst-basic" ]                  && \
        print-red "Gst package group is not packagegroup-qti-gst or packagegroup-qti-gst-basic !!!" && \
        return -2

    QIMSDK_ESDK_GST_PLUGINS_QTI_OSS_DEPENDENCIES=`echo ${BUFFER} | jq '.Gst_plugins_qti_oss_dependencies[]' | tr -d '"'`

    QIMSDK_ESDK_DEVICE_INSTALL_PREFIX=`echo ${BUFFER} | jq '.Device_install_prefix' | tr -d '"'`
    QIMSDK_ESDK_DEVICE_INSTALL_PREFIX=`echo ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/ | tr -s '/'`
    [ "${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}" == "/" ]                                            && \
        {
            print-red "Prefix to install qimsdk packages in must be provided as an argument of config json !!!"
            return -2
        }

    [ -z "${eSDK_SHELL_FILE}" ] && print-red "ESDK shell file must be provided as an argument of config json !!!" && return -3
    [ ! -f "${eSDK_SHELL_FILE}" ] && print-red "Could not find ESDK_SH !!!" && return -4
    [ ! -d "${BASE_DIR_LOCATION}" ] && print-red "Path to the directory where the project is initialized must be provided as an argument of config json !!!" && return -5

    local ESDK_JSON="${eSDK_SHELL_FILE%.*}"
    ESDK_JSON="${ESDK_JSON}.testdata.json"
    [ ! -f "${ESDK_JSON}" ] && print-red "Could not find ESDK json file !!!" && return -6

    local ENV_SCRIPT_VAR_SUFFIX=""
    cat ${ESDK_JSON} | grep env_setup_script_llvm > /dev/null && ENV_SCRIPT_VAR_SUFFIX="_llvm"
    local ENV_SCRIPT_VAR="env_setup_script${ENV_SCRIPT_VAR_SUFFIX}"

    QIMSDK_ENV_SETUP_SCRIPT=$(cat ${ESDK_JSON} | grep "${ENV_SCRIPT_VAR}")
    QIMSDK_ENV_SETUP_SCRIPT=${QIMSDK_ENV_SETUP_SCRIPT#*$ENV_SCRIPT_VAR}
    QIMSDK_ENV_SETUP_SCRIPT=$(echo ${QIMSDK_ENV_SETUP_SCRIPT} | cut -d '\' -f 2 | cut -d '/' -f 2)

    return 0
}

# Build IM SDK in host machine
#   $1 - (mandatory) path to target config json
function qimsdk-setup() {
    local rc

    local PATH_TO_CONFIG_JSON=$1

    qimsdk-host-env-setup ${PATH_TO_CONFIG_JSON}
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-host-env-setup"
        return ${rc}
    }

    qimsdk-common
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-common"
        return ${rc}
    }

    qimsdk-fetch-scripts-src-poky
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-fetch-scripts-src-poky"
        return ${rc}
    }

    qimsdk-builder
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-builder"
        return ${rc}
    }

    print-green "QIM SDK setup completed !!!"

    return 0
}

# Remove IM SDK from host machine
#   $1 - (mandatory) path to target config json
function qimsdk-remove() {
    local PATH_TO_CONFIG_JSON=$1
    local rc

    qimsdk-host-env-setup ${PATH_TO_CONFIG_JSON}
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-host-env-setup"
        return ${rc}
    }

    rm -rf $BASE_DIR_LOCATION

    print-green "QIM SDK removed !!!"

    return 0
}

# Prepare directories
function qimsdk-common() {
    local rc

    qimsdk-create-dirs
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-create-dirs"
        popd 1>/dev/null
        return ${rc}
    }

    pushd ${QIMSDK_DOWNLOAD_DIR} 1>/dev/null

    qimsdk-install-esdk
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-install-esdk"
        popd 1>/dev/null
        return ${rc}
    }

    qimsdk-setup-tflite
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-setup-tflite"
        popd 1>/dev/null
        return ${rc}
    }

    qimsdk-setup-acceleration-engines
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-setup-acceleration-engines"
        popd 1>/dev/null
        return ${rc}
    }

    popd 1>/dev/null

    return 0
}

# Prepare, build and package all layers
function qimsdk-builder() {
    local rc

    (source ${QIMSDK_SCRIPTS}/env_setup.sh && qimsdk-layers-prepare-build-package)

    return 0
}

# Check if default system shell is pointing to bash
function qimsdk-check-system-shell() {
    [ "$(readlink -f $(which sh))" != "/bin/bash" -a "$(readlink -f $(which sh))" != "/usr/bin/bash" ] && \
    {
        print-red "Please change the default command interpreter for shell scripts to bash";
        print-blue sudo ln -sf /bin/bash /bin/sh;
        return -1
    }

    return 0
}

# Check for necessary packages
function qimsdk-check-required-packages() {
    local NOT_INSTALLED_PKGS=""
    local REQUIRED_PKGS="sudo python3 python3-pip zip unzip curl wget gnupg flex bison             \
        build-essential zlib1g-dev zstd gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev-i386 \
        libncurses5 cpio lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libxml2-utils  \
        libgl1-mesa-dev xsltproc fontconfig cmake texinfo chrpath diffstat xmlstarlet ssh uuid-dev \
        libarchive-dev libselinux1-dev g++ gawk gcc make libwayland-dev fakeroot libpam0g-dev git  \
        jq binutils-dev openjdk-8-jdk-headless util-linux whiptail libxml-simple-perl openssl gdb  \
        bash-completion software-properties-common locales lcov libbz2-dev libffi-dev libgdbm-dev  \
        usbutils file libgdbm-compat-dev liblzma-dev libncurses5-dev libreadline-dev libssl-dev    \
        libsqlite3-dev lzma lzma-dev tk-dev android-tools-adb android-tools-fastboot fakechroot    \
        language-pack-en-base libiberty-dev qemu-user-static"

    for PKG in ${REQUIRED_PKGS[@]}; do
        dpkg-query -s ${PKG} > /dev/null 2>&1 || NOT_INSTALLED_PKGS+=${PKG}" "
    done

    [ -n "${NOT_INSTALLED_PKGS}" ] && {
        print-red "THESE PACKAGES NEED TO BE INSTALLED:"
        echo ${NOT_INSTALLED_PKGS}
        print-blue "sudo apt install ${NOT_INSTALLED_PKGS}"
        return -1
    }

    return 0
}

# Sync QIMSDK artifacts to directory specified in config json
function qimsdk-host-sync-artifacts-all() {
    source ${QIMSDK_SCRIPTS}/env_setup.sh && qimsdk-target-sync-artifacts-all                   || \
        {
            print-red "qimsdk-target-sync-artifacts-all function failed !!!"
            return -1
        }

    [ "${QIMSDK_ESDK_DEPLOY_ARTIFACTS}" == "no-artifacts-dir-provided" ]                        && \
        {
            print-red "Artifacts dir must be provided in config json !!!"
            return -2
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_WORK_DIR}/artifacts/packages${QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG}.zip ${QIMSDK_ESDK_DEPLOY_ARTIFACTS}  || \
                {
                    print-red "Syncing QIMSDK artifacts from host environment failed !!!"
                    return -3
                }
        }
}

# Setup environment variables
#   $1 - (mandatory) path to target config json
function qimsdk-host-env-setup() {
    local rc

    local PATH_TO_CONFIG_JSON=$1

    qimsdk-check-system-shell
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-check-system-shell"
        return ${rc}
    }

    qimsdk-check-required-packages
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-check-required-packages"
        return ${rc}
    }

    qimsdk-host-parse-json ${PATH_TO_CONFIG_JSON}
    rc=$?
    [ "${rc}" -ne 0 ] && {
        print-red "FAILED: qimsdk-host-parse-json"
        return ${rc}
    }

    local BASE_DIR="${BASE_DIR_LOCATION}/base_dir"
    local COMMON_DIR="common"

    QIMSDK_BASE_DIR="${BASE_DIR_LOCATION}/${eSDK_NAME}"
    QIMSDK_DOWNLOAD_DIR=${BASE_DIR}/${COMMON_DIR}/download
    QIMSDK_STATUS=${BASE_DIR}/${COMMON_DIR}/.status
    QIMSDK_ESDK_BASE_DIR=${QIMSDK_BASE_DIR}/esdk
    QIMSDK_WORK_DIR=${QIMSDK_BASE_DIR}/work
    QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/scripts

    # shift removes one input argument to avoid using it by env_setup.sh
    shift
    source ${QIMSDK_SCRIPTS}/env_setup.sh

    print-green "Environment variables setup completed !!!"
}

# Remove environment variables
function qimsdk-host-env-remove() {
    unset QIMSDK_BASE_DIR QIMSDK_DOWNLOAD_DIR QIMSDK_STATUS QIMSDK_ESDK_BASE_DIR QIMSDK_WORK_DIR   \
            QIMSDK_SCRIPTS eSDK_SHELL_FILE eSDK_NAME BASE_DIR_LOCATION QIMSDK_ESDK_TFLITE_FILE     \
            QIMSDK_ESDK_TFLITE_FILENAME QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES                      \
            QIMSDK_ACCELERATION_ENGINE_PATHS QIMSDK_ACCELERATION_ENGINE_COUNT                      \
            QIMSDK_ESDK_DEPLOY_URL QIMSDK_ESDK_DEPLOY_URL_DEV QIMSDK_ESDK_DEPLOY_ARTIFACTS         \
            QIMSDK_ESDK_GST_PLUGINS_QTI_OSS_DEPENDENCIES QIMSDK_ESDK_DEVICE_INSTALL_PREFIX         \
            QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG QIMSDK_TOOLS_DIR                                   && \
        print-green "Environment variables removed !!!"
}

# Sync QIMSDK release artifacts to directory specified in config json
function qimsdk-host-sync-artifacts-rel() {
    source ${QIMSDK_SCRIPTS}/env_setup.sh && qimsdk-target-sync-artifacts-rel                   || \
        {
            print-red "qimsdk-target-sync-artifacts-rel function failed !!!"
            return -1
        }

    [ "${QIMSDK_ESDK_DEPLOY_ARTIFACTS}" == "no-artifacts-dir-provided" ]                        && \
        {
            print-red "Release artifacts dir must be provided in config json !!!"
            return -2
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_WORK_DIR}/artifacts/packages_rel${QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG}.zip ${QIMSDK_ESDK_DEPLOY_ARTIFACTS} || \
                {
                    print-red "Syncing QIMSDK release artifacts from host environment failed !!!"
                    return -3
                }
        }
}

# Sync QIMSDK development artifacts to directory specified in config json
function qimsdk-host-sync-artifacts-dev() {
    source ${QIMSDK_SCRIPTS}/env_setup.sh && qimsdk-target-sync-artifacts-dev                   || \
        {
            print-red "qimsdk-target-sync-artifacts-dev function failed !!!"
            return -1
        }

    [ "${QIMSDK_ESDK_DEPLOY_ARTIFACTS}" == "no-artifacts-dir-provided" ]                        && \
        {
            print-red "Development artifacts dir must be provided in config json !!!"
            return -2
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_WORK_DIR}/artifacts/packages_dev${QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG}.zip ${QIMSDK_ESDK_DEPLOY_ARTIFACTS} || \
                {
                    print-red "Syncing QIMSDK development artifacts from host environment failed !!!"
                    return -3
                }
        }
}

QIMSDK_TOOLS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/../../ && pwd )"
[ -f "${QIMSDK_TOOLS_DIR}/Dockerfile" ] || QIMSDK_TOOLS_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )"/sdk-tools && pwd )"

source ${QIMSDK_TOOLS_DIR}/scripts/image/common/tools.sh
source ${QIMSDK_TOOLS_DIR}/scripts/host/qimsdk-common.sh

print-green "qimsdk-setup                                             <path/to/targets/.json>"
echo "    Build IM SDK in host machine"
print-green "qimsdk-host-env-setup                                    <path/to/targets/.json>"
echo "    Setup environment variables"
print-red "qimsdk-remove                                            <path/to/targets/.json>"
echo "    Remove IM SDK from host machine"
print-red "qimsdk-host-env-remove"
echo "    Remove environment variables"
