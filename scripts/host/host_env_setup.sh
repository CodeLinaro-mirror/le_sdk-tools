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

    QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES=(`echo ${BUFFER} | jq '.Acceleration_engines[] | .Acceleration_engine' | tr -d '"'`)
    QIMSDK_ACCELERATION_ENGINE_PATHS=(`echo ${BUFFER} | jq '.Acceleration_engines[] | .Acceleration_engine_path' | tr -d '"'`)
    QIMSDK_ACCELERATION_ENGINE_COUNT=`echo ${BUFFER} | jq '.Acceleration_engines[] | .Acceleration_engine' | wc -l`

    QIMSDK_ESDK_DEPLOY_URL=`echo ${BUFFER} | jq '.Deploy_URL' | tr -d '"'`
    QIMSDK_ESDK_DEPLOY_URL=`echo ${QIMSDK_ESDK_DEPLOY_URL}/ | sed 's/\/\//\//g'`

    QIMSDK_ESDK_DEPLOY_URL_DEV=`echo ${BUFFER} | jq '.Deploy_dev_URL' | tr -d '"'`
    QIMSDK_ESDK_DEPLOY_URL_DEV=`echo ${QIMSDK_ESDK_DEPLOY_URL_DEV}/ | sed 's/\/\//\//g'`

    QIMSDK_ESDK_DEPLOY_ARTIFACTS=`echo ${BUFFER} |  jq '.Deploy_QIMSDK_Artifacts_URL' | tr -d '"'`
    [ -z ${QIMSDK_ESDK_DEPLOY_ARTIFACTS} ] || [ ! -d ${QIMSDK_ESDK_DEPLOY_ARTIFACTS} ]          && \
        QIMSDK_ESDK_DEPLOY_ARTIFACTS=no-artifacts-dir-provided                                  || \
        {
            QIMSDK_ESDK_DEPLOY_ARTIFACTS=`echo ${QIMSDK_ESDK_DEPLOY_ARTIFACTS}/ | sed 's/\/\//\//g'`
        }

    QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL=`echo ${BUFFER} |  jq '.Deploy_QIMSDK_Artifacts_URL_rel' | tr -d '"'`
    [ -z ${QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL} ] || [ ! -d ${QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL} ]  && \
        QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL=no-artifacts-rel-dir-provided                          || \
        {
            QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL=`echo ${QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL}/ | sed 's/\/\//\//g'`
        }

    QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV=`echo ${BUFFER} |  jq '.Deploy_QIMSDK_Artifacts_URL_dev' | tr -d '"'`
    [ -z ${QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV} ] || [ ! -d ${QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV} ]  && \
        QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV=no-artifacts-dev-dir-provided                          || \
        {
            QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV=`echo ${QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV}/ | sed 's/\/\//\//g'`
        }

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
    export QIMSDK_ESDK_DEPLOY_ARTIFACTS
    export QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL
    export QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV
    export QIMSDK_WORK_DIR
    export QIMSDK_ESDK_TFLITE_FILE
    export QIMSDK_ESDK_TFLITE_FILENAME
    export QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES
    export QIMSDK_ACCELERATION_ENGINE_PATHS
    export QIMSDK_ACCELERATION_ENGINE_COUNT
    export ACCELERATION_ENGINE_DIR
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

    export QIMSDK_ESDK_TFLITE_FILENAME

    qimsdk-setup-acceleration-engines
    rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: qimsdk-setup-acceleration-engines"
        popd 1>/dev/null
        return $rc
    }

    export QIMSDK_ESDK_ACCELERATION_ENGINE_DIR

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

# Sync QIMSDK artifacts to directory specified in config json
function qimsdk-host-sync-artifacts-all() {
    ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-target-sync-artifacts-all                             || \
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
            rsync -a ${QIMSDK_WORK_DIR}/artifacts/packages.zip ${QIMSDK_ESDK_DEPLOY_ARTIFACTS}  || \
                {
                    print-red "Syncing QIMSDK artifacts from host environment failed !!!"
                    return -3
                }
        }
}

# Sync QIMSDK release artifacts to directory specified in config json
function qimsdk-host-sync-artifacts-rel() {
    ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-target-sync-artifacts-rel                             || \
        {
            print-red "qimsdk-target-sync-artifacts-rel function failed !!!"
            return -1
        }

    [ "${QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL}" == "no-artifacts-rel-dir-provided" ]                && \
        {
            print-red "Release artifacts dir must be provided in config json !!!"
            return -2
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_WORK_DIR}/artifacts/packages_rel.zip ${QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL} || \
                {
                    print-red "Syncing QIMSDK release artifacts from host environment failed !!!"
                    return -3
                }
        }
}

# Sync QIMSDK development artifacts to directory specified in config json
function qimsdk-host-sync-artifacts-dev() {
    ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-target-sync-artifacts-dev                             || \
        {
            print-red "qimsdk-target-sync-artifacts-dev function failed !!!"
            return -1
        }

    [ "${QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV}" == "no-artifacts-dev-dir-provided" ]                && \
        {
            print-red "Development artifacts dir must be provided in config json !!!"
            return -2
        }                                                                                       || \
        {
            rsync -a ${QIMSDK_WORK_DIR}/artifacts/packages_dev.zip ${QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV} || \
                {
                    print-red "Syncing QIMSDK development artifacts from host environment failed !!!"
                    return -3
                }
        }
}

QIMSDK_TOOLS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/../../ && pwd )"
source ${QIMSDK_TOOLS_DIR}/scripts/image/common/tools.sh

print-green "qimsdk-setup                                             <path/to/targets/.json>"
echo "    Build IM SDK in host machine"
print-green "qimsdk-remove                                            <path/to/targets/.json>"
echo "    Remove IM SDK from host machine"
