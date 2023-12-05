#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Get all updated packages
#   $1 - (mandatory) /output/ updated packages
#   $2 - (mandatory) package format deb or ipk
function qimsdk-target-get-updated-packages-all() {
    local -n UPDATED_PACKAGES=$1
    local PKG_FORMAT=$2

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*gstreamer*.${PKG_FORMAT}" -o -name "libgst*.${PKG_FORMAT}" -o -name "*liborc*.${PKG_FORMAT}" -o -name "*libdaemon*.${PKG_FORMAT}" -o -name "*libgudev*.${PKG_FORMAT}" -o -name "*libjson-glib*.${PKG_FORMAT}" -o -name "*libmp3lame*.${PKG_FORMAT}" -o -name "*libpsl*.${PKG_FORMAT}" -o -name "*libtheora*.${PKG_FORMAT}" -o -name "*libtag*.${PKG_FORMAT}" -o -name "*libsoup*.${PKG_FORMAT}" -o -name "*libspeex1*.${PKG_FORMAT}" -o -name "mpg123*.${PKG_FORMAT}" \) -print0 )
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*.${PKG_FORMAT}" ! -iname "*gstreamer*.${PKG_FORMAT}" \) -cnewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

# Get updated release packages
#   $1 - (mandatory) /output/ updated packages
#   $2 - (mandatory) package format deb or ipk
function qimsdk-target-get-updated-packages-rel() {
    local -n UPDATED_PACKAGES=$1
    local PKG_FORMAT=$2

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*gstreamer*.${PKG_FORMAT}" ! -iname "*gstreamer*-dev_*" ! -iname "*gstreamer*-staticdev_*" ! -iname "*gstreamer*-doc_*" ! -iname "*gstreamer*-dbg_*" ! -iname "*gstreamer*-locale-*" -o -name "libgst*.${PKG_FORMAT}" -o -name "*liborc*.${PKG_FORMAT}" ! -iname "*liborc*-test-*" -o -name "*libdaemon*.${PKG_FORMAT}" ! -iname "*libdaemon*-dev_*" ! -iname "*libdaemon*-staticdev_*" ! -iname "*libdaemon*-doc_*" ! -iname "*libdaemon*-dbg_*" -o -name "*libgudev*.${PKG_FORMAT}" ! -iname "*libgudev*-dev_*" ! -iname "*libgudev*-dbg_*" -o -name "*libjson-glib*.${PKG_FORMAT}" ! -iname "*libjson-glib*-bin_*" ! -iname "*libjson-glib*-dev_*" ! -iname "*libjson-glib*-dbg_*" ! -iname "*libjson-glib*-locale-*" -o -name "*libmp3lame*.${PKG_FORMAT}" ! -iname "*libmp3lame*-dev_*" -o -name "*libpsl*.${PKG_FORMAT}" ! -iname "*libpsl*-bin_*" ! -iname "*libpsl*-dev_*" ! -iname "*libpsl*-staticdev_*" ! -iname "*libpsl*-doc_*" ! -iname "*libpsl*-dbg_*" -o -name "*libtheora*.${PKG_FORMAT}" ! -iname "*libtheora*-dev_*" ! -iname "*libtheora*-staticdev_*" ! -iname "*libtheora*-dbg_*" -o -name "*libtag*.${PKG_FORMAT}" ! -iname "*libtag*-c0_*" ! -iname "*libtag*-dev_*" ! -iname "*libtag*-dbg_*" -o -name "*libsoup*.${PKG_FORMAT}" ! -iname "*libsoup*-dev_*" ! -iname "*libsoup*-dbg_*" ! -iname "*libsoup*-locale-*" -o -name "*libspeex1*.${PKG_FORMAT}" ! -iname "*libspeex1*-dev_*" ! -iname "*libspeex1*-staticdev_*" ! -iname "*libspeex1*-doc_*" ! -iname "*libspeex1*-dbg_*" -o -name "mpg123*.${PKG_FORMAT}" ! -iname "*mpg123*-dev_*" ! -iname "*mpg123*-doc_*" ! -iname "*mpg123*-dbg_*" \) -print0 )
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*.${PKG_FORMAT}" ! -iname "libspeexdsp1*.${PKG_FORMAT}" ! -iname "qnn*.${PKG_FORMAT}" ! -iname "snpe*.${PKG_FORMAT}" ! -iname  "*gstreamer*.${PKG_FORMAT}" ! -iname "*-dev_*" ! -iname "*-staticdev_*" ! -iname "*-doc_*" ! -iname "*-dbg_*" ! -iname "*-locale-*" \) -cnewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

# Get updated debug packages
#   $1 - (mandatory) /output/ updated packages
#   $2 - (mandatory) package format deb or ipk
function qimsdk-target-get-updated-packages-dbg() {
    local -n UPDATED_PACKAGES=$1
    local PKG_FORMAT=$2

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*gstreamer*-dbg_*.${PKG_FORMAT}" ! -iname "*gstreamer*-dev_*" ! -iname "*gstreamer*-staticdev_*" ! -iname "*gstreamer*-doc_*" -o -name "*libdaemon*-dbg_*.${PKG_FORMAT}" -o -name "*libgudev*-dbg_*.${PKG_FORMAT}" -o -name "*libjson-glib*-dbg_*.${PKG_FORMAT}" -o -name "*libpsl*-dbg_*.${PKG_FORMAT}" -o -name "*libtheora*-dbg_*.${PKG_FORMAT}" -o -name "*libtag*-dbg_*.${PKG_FORMAT}" -o -name "*libsoup*-dbg_*.${PKG_FORMAT}" -o -name "*libspeex1*-dbg_*.${PKG_FORMAT}" -o -name "mpg123*-dbg_*.${PKG_FORMAT}" \) -print0 )
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*-dbg_*.${PKG_FORMAT}" ! -iname "snpe*-dbg_*.${PKG_FORMAT}" ! -iname  "*gstreamer*.${PKG_FORMAT}" ! -iname "*-dev_*" ! -iname "*-staticdev_*" ! -iname "*-doc_*" \) -cnewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

function qimsdk-target-get-updated-packages-dev() {
    local -n UPDATED_PACKAGES=$1
    local PKG_FORMAT=$2

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*gstreamer*-dev_*.${PKG_FORMAT}" ! -iname "*gstreamer*-staticdev_*" ! -iname "*gstreamer*-doc_*" ! -iname "*gstreamer*-dbg_*" -o -name "*libdaemon*-dev_*.${PKG_FORMAT}" -o -name "*libgudev*-dev_*.${PKG_FORMAT}" -o -name "*libjson-glib*-dev_*.${PKG_FORMAT}" -o -name "*libmp3lame-dev_**.${PKG_FORMAT}" -o -name "*libpsl*-dev_*.${PKG_FORMAT}" -o -name "*libtheora*-dev_*.${PKG_FORMAT}" -o -name "*libtag*-dev_*.${PKG_FORMAT}" -o -name "*libsoup*-dev_*.${PKG_FORMAT}" -o -name "*libspeex1*-dev_*.${PKG_FORMAT}" -o -name "mpg123*-dev_*.${PKG_FORMAT}" \) -print0 )
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*-dev_*.${PKG_FORMAT}" ! -iname "snpe*-dev_*.${PKG_FORMAT}" ! -iname  "*gstreamer*.${PKG_FORMAT}" ! -iname "*-dbg_*" ! -iname "*-staticdev_*" ! -iname "*-doc_*" \) -cnewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

function qimsdk-target-get-updated-packages-staticdev() {
    local -n UPDATED_PACKAGES=$1
    local PKG_FORMAT=$2

    # Get packages to install since latest sync
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*gstreamer*-staticdev_*.${PKG_FORMAT}" ! -iname "*gstreamer*-dbg_*" ! -iname "*gstreamer*-doc_*" -o -name "*libdaemon*-staticdev_*.${PKG_FORMAT}" -o -name "*libpsl*-staticdev_*.${PKG_FORMAT}" -o -name "*libtheora*-staticdev_*.${PKG_FORMAT}" -o -name -o -name "*libspeex1*-staticdev_*.${PKG_FORMAT}" \)  -print0 )
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "*-staticdev_*.${PKG_FORMAT}" ! -iname  "*gstreamer*.${PKG_FORMAT}" ! -iname "*-dbg_*" ! -iname "*-doc_*" \) -anewer ${QIMSDK_WORK_DIR}/prepared -print0)
}

# Get target prerequisite packages
#   $1 - (mandatory) /output/ prerequisite package if exest on deploy directory
#   $2 - (mandatory) package format deb or ipk
function qimsdk-target-check-for-prerequisites() {

    local -n UPDATED_PACKAGES=$1
    local PKG_FORMAT=$2

    # Get prerequisite packages to install
    while IFS= read -r -d $'\0'; do
        UPDATED_PACKAGES+=("$REPLY")
    done < <(find ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/${PKG_FORMAT}/ -type f \( -name "libgstreamer1.0-0*" -o -name "libgdk-pixbuf-2.0-0*.${PKG_FORMAT}" -o -name "libjansson*.${PKG_FORMAT}" ! -iname "*-dev_*" ! -iname "*-staticdev_*" ! -iname "*-doc_*" ! -iname "*-dbg_*" \) -print0)
}

# Sync compiled packages with the target
#   $1 - (mandatory) variant: rel or dbg
#   $2 - (mandatory) target: device or remote
#   $3 - (mandatory) format: deb or ipk
function qimsdk-target-sync() {
    local VARIANT=$1
    local TARGET=$2
    local FORMAT=$3
    [ ! "${VARIANT}" == "rel" ] && [ ! "${VARIANT}" == "dbg" ]                                  && \
        [ ! "${VARIANT}" == "dev" ] && [ ! "${VARIANT}" == "staticdev" ]                        && \
        print-red "Variant input argument dbg, rel, dev or staticdev is required" && return -1

    [ ! "${TARGET}" == "device" ] && [ ! "${TARGET}" == "remote" ]                              && \
        print-red "Target input argument device or remote is required" && return -2

    [ ! "${FORMAT}" == "deb" ] && [ ! "${FORMAT}" == "ipk" ]                                    && \
        print-red "Package format argument deb or ipk is required" && return -3

    [ "${TARGET}" == "device" ]                                                                 && \
        {
            adb push ${QIMSDK_BASE_DIR}/qim-sdk.sh /etc/profile.d/ || return -4
            qimsdk-device-command "source /etc/profile.d/qim-sdk.sh" || return -5
            qimsdk-device-command "mkdir -p ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc"

            [ "${FORMAT}" == "ipk" ]                                                            && \
                {
                    qimsdk-device-command "cat /etc/opkg/opkg.conf | grep \"dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}\"" 1>/dev/null || \
                        {
                            qimsdk-device-command 'sed -i '/qimsdk_install_path/d' /etc/opkg/opkg.conf'
                            qimsdk-device-command "echo \"dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}\" >> /etc/opkg/opkg.conf"
                        }
                }
        }

    [ ${TARGET} == "remote" ]                                                                   && \
        {
            rsync -a --progress ${QIMSDK_BASE_DIR}/qim-sdk.sh ${QIMSDK_ESDK_DEPLOY_URL}
            rsync -a --progress ${QIMSDK_BASE_DIR}/qim-sdk-install-prefix.txt ${QIMSDK_ESDK_DEPLOY_URL}
            rsync -a --progress ${QIMSDK_WORK_DIR}/local_md5.log ${QIMSDK_ESDK_DEPLOY_URL}
        }

    # Check whether code was already prepared
    [ ! -f "${QIMSDK_WORK_DIR}/prepared" ] && print-red "Layers are not prepared" && return -6

    local TARGET_PULLED_LOG_FILE="${QIMSDK_WORK_DIR}/${TARGET}_sync.log"
    qimsdk-${TARGET}-pull-log ${VARIANT} || return -7

    # Get updated packages
    local PKGS
    qimsdk-target-get-updated-packages-${VARIANT} PKGS ${FORMAT}                                || \
        {
            print-red "Failed to get updated packages";
            return -8
        }

    # Sync only new packages
    local PKG
    for PKG in "${PKGS[@]}"; do
        local PKG_FILENAME=`echo $(basename ${PKG})`
        local PKG_NAME=`echo ${PKG_FILENAME} | cut -d '_' -f 1`
        local DEV=""

        [ "${VARIANT}" == "dev" ] || [ "${VARIANT}" == "staticdev" ]                            && \
            {
                DEV="-dev"
            }

        [ "${PKG_NAME}" == "librsvg-2-gtk" -o "${PKG_NAME}" == "gstd" -o "${PKG_NAME}" == "qti-gstreamer1.0-plugins-good-v4l2" ] && \
            {
                # Check for prerequisite packages
                local PPKGS
                qimsdk-target-check-for-prerequisites PPKGS ${FORMAT}                           || \
                    {
                        print-red "Failed to check for prerequisite packages";
                    }

                [ -n "${PPKGS}" ]                                                               && \
                    for PPKG in "${PPKGS[@]}"; do
                        qimsdk-${TARGET}-pkg-sync${DEV} ${PPKG} ${FORMAT}
                    done
            }

        qimsdk-${TARGET}-pkg-sync${DEV} ${PKG} ${FORMAT}                                        || \
            {
                qimsdk-${TARGET}-update-log ${VARIANT}
                rm -f ${TARGET_PULLED_LOG_FILE} 2>&1>/dev/null
                return -9
            }
    done

    qimsdk-${TARGET}-update-log ${VARIANT}
    rm -f ${TARGET_PULLED_LOG_FILE} 2>&1>/dev/null

    print-green "Packages synced successfully !!!"
}

# Create packages archive for the target
#   $1 - (mandatory) variant: rel, dev or all
function qimsdk-target-sync-artifacts() {
    local VARIANT=$1

    [ ! "${VARIANT}" == "rel" ] && [ ! "${VARIANT}" == "dev" ] && [ ! "${VARIANT}" == "all" ]   && \
        print-red "Variant input argument dbg, rel, dev or staticdev is required" && return -1

    # Set package format
    local FORMAT=""
    [ "$(qimsdk-get-pkg-format)" == "deb" ] && FORMAT=deb
    [ "$(qimsdk-get-pkg-format)" == "ipk" ] && FORMAT=ipk
    [ -z "${FORMAT}" ] && print-red "FAILED TO GET PACKAGE FORMAT !!!" && return -2

    # Check whether code was already prepared
    [ ! -f "${QIMSDK_WORK_DIR}/prepared" ] && print-red "Layers are not prepared" && return -3

    # Get updated packages
    local PKGS
    qimsdk-target-get-updated-packages-${VARIANT} PKGS ${FORMAT}                                || \
        {
            print-red "Failed to get updated packages";
            return -4;
        }

    # Set variant postfix depending on variant
    [ "${VARIANT}" == "rel" ] && VARIANT="_rel"
    [ "${VARIANT}" == "dev" ] && VARIANT="_dev"
    [ "${VARIANT}" == "all" ] && VARIANT=""

    mkdir -p ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}

    # Sync only new packages
    local PKG
    local SYNC_FILE="${QIMSDK_WORK_DIR}/artifacts_sync${VARIANT}.log"

    for PKG in "${PKGS[@]}"; do
        local DATE=`date -r ${PKG}`
        local LOG="Pushing ${PKG} ${DATE}"
        local PKG_NAME=`echo $(basename ${PKG}) | cut -d '_' -f 1`

        cat ${SYNC_FILE} 2>/dev/null | grep "${LOG}" 1>/dev/null                                || \
            {
                rsync -a --progress ${PKG} ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}      || \
                    {
                        print-red "rsync package ${PKG_NAME} to artifacts dir failed !!!";
                        return -5;
                    }
            }
        PKG=$(basename ${PKG})
        sed -i "/${PKG}/d" ${SYNC_FILE} 2>/dev/null
        echo "${LOG}" >> ${SYNC_FILE}
    done

    # Copy Files needed in install scripts to packages dir to be added to artifacts zip
    cp ${QIMSDK_BASE_DIR}/qim-sdk.sh ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}
    cp ${QIMSDK_BASE_DIR}/qim-sdk-install-prefix.txt ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}
    cp ${QIMSDK_WORK_DIR}/local_md5.log ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}

    # Remove old artifacts archive
    rm -f ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}${QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG}.zip

    # Create new artifacts archive
    pushd ${QIMSDK_WORK_DIR}/artifacts 1>/dev/null
        zip -j packages${VARIANT}${QIMSDK_ESDK_DEPLOY_ARTIFACTS_TAG}.zip ${QIMSDK_WORK_DIR}/artifacts/packages${VARIANT}/*
    popd 1>/dev/null

    print-green "Artifacts synced successfully !!!"
}

function qimsdk-target-sync-artifacts-rel() {
    qimsdk-target-sync-artifacts rel
}

function qimsdk-target-sync-artifacts-dev() {
    qimsdk-target-sync-artifacts dev
}

function qimsdk-target-sync-artifacts-all() {
    qimsdk-target-sync-artifacts rel
    qimsdk-target-sync-artifacts dev
    qimsdk-target-sync-artifacts all
}
