#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Configure build environment based on current target
function tflite-tools-configure() {
    local LE_TOOLCHAIN

    [ -z "${OE_CMAKE_TOOLCHAIN_FILE}" ]                                                         && \
        LE_TOOLCHAIN=(`${TFLITE_SDK_SETUP} 2>/dev/null ; echo ${OE_CMAKE_TOOLCHAIN_FILE}`)      || \
        LE_TOOLCHAIN="${OE_CMAKE_TOOLCHAIN_FILE}"

    local TFLITE_TARGET=( $(${TFLITE_SDK_SETUP} 2>/dev/null ; echo ${TARGET_PREFIX}) )

    TFLITE_TARGET=$(echo ${TFLITE_TARGET} | rev | cut -c2- | rev)

    local COMMON_CMAKE_FLAGS_le="-DCMAKE_TOOLCHAIN_FILE=${LE_TOOLCHAIN} -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DTFLITE_ENABLE_XNNPACK=${TFLITE_ENABLE_XNNPACK} -DTFLITE_ENABLE_EVALUATION_TOOLS=ON -DTFLITE_ENABLE_NNAPI=OFF -DTFLITE_ENABLE_RUY=ON -DTFLITE_ENABLE_GPU=${TFLITE_ENABLE_GPU} -DTFLITE_ENABLE_HEXAGON=${TFLITE_ENABLE_HEXAGON} -DCMAKE_INSTALL_PREFIX=${TFLITE_DEPLOY_DBG_DIR}/usr -DCMAKE_INSTALL_LIBDIR=lib -DTFLITE_DOWNLOAD_DIR=${TFLITE_DOWNLOAD_DIR} -DTFLITE_TARGET=${TFLITE_TARGET}"
    local COMMON_CMAKE_FLAGS_lu="-DCMAKE_TOOLCHAIN_FILE=${LE_TOOLCHAIN} -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DTFLITE_ENABLE_XNNPACK=${TFLITE_ENABLE_XNNPACK} -DTFLITE_ENABLE_EVALUATION_TOOLS=ON -DTFLITE_ENABLE_NNAPI=OFF -DTFLITE_ENABLE_RUY=ON -DTFLITE_ENABLE_GPU=${TFLITE_ENABLE_GPU} -DTFLITE_ENABLE_HEXAGON=${TFLITE_ENABLE_HEXAGON} -DCMAKE_INSTALL_PREFIX=${TFLITE_DEPLOY_DBG_DIR}/usr -DCMAKE_INSTALL_LIBDIR=lib -DTFLITE_DOWNLOAD_DIR=${TFLITE_DOWNLOAD_DIR} -DTFLITE_TARGET=${TFLITE_TARGET}"

    local COMMON_CMAKE_FLAGS_la="-DCMAKE_TOOLCHAIN_FILE=${TFLITE_NDK_DIR}/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DTFLITE_ENABLE_XNNPACK=${TFLITE_ENABLE_XNNPACK} -DTFLITE_ENABLE_EVALUATION_TOOLS=ON -DTFLITE_ENABLE_NNAPI=OFF -DTFLITE_ENABLE_RUY=ON -DCMAKE_INSTALL_PREFIX=${TFLITE_DEPLOY_DBG_DIR}/vendor -DCMAKE_INSTALL_LIBDIR=lib64 -DTFLITE_ENABLE_GPU=${TFLITE_ENABLE_GPU} -DTFLITE_ENABLE_HEXAGON=${TFLITE_ENABLE_HEXAGON}"

    local CMAKE_FLAGS=COMMON_CMAKE_FLAGS_${TFLITE_OS}

    [ -d ${TFLITE_BUILD_DIR} ] || mkdir -p ${TFLITE_BUILD_DIR}
    pushd ${TFLITE_BUILD_DIR} 1>/dev/null

    (${TFLITE_SDK_SETUP}; cmake ${!CMAKE_FLAGS} ${TFLITE_SRC_DIR})                              || \
        {
            popd 1>/dev/null
            print-red "tflite-tools-configure failed: cmake failed !!!"
            return -1
        }

    popd 1>/dev/null

    return 0
}

# Clean build environment
function tflite-tools-clean() {
    rm -rf ${TFLITE_BUILD_DIR}

    print-green "Clean completed !"
}

# Build tf lite
function tflite-tools-build() {
    pushd ${TFLITE_BUILD_DIR} 1>/dev/null

    (${TFLITE_SDK_SETUP}; cmake --build . -j${TF_LITE_NUM_CPU})                                 || \
        {
            popd 1>/dev/null
            print-red "tflite-tools-build failed: cmake build failed !!!"
            return -1
        }

    popd 1>/dev/null

    print-green "tflite built successfully !!!"
    return 0
}

# Build tflite target given as first argument
#   $1 - (mandatory) specify which target to be built
function tflite-tools-build-target() {
    local TARGET=$1
    [ -z "${TARGET}" ]                                                                          && \
        {
            print-red "tf lite target must be provided as first argument"
            return -1
        }

    pushd ${TFLITE_BUILD_DIR} 1>/dev/null

    (${TFLITE_SDK_SETUP}; cmake --build . -j${TF_LITE_NUM_CPU} -t ${TARGET})                    || \
        {
            popd 1>/dev/null
            print-red "tflite-tools-build-${TARGET} failed: cmake build failed !!!"
            return -1
        }

    popd 1>/dev/null

    return 0
}

# Build benchmark model
function tflite-tools-build-benchmark-model() {
    tflite-tools-build-target benchmark_model
}

# Build label image
function tflite-tools-build-label-image() {
    tflite-tools-build-target label_image
}

# Build multimodel label image
function tflite-tools-build-multimodel-label-image() {
    tflite-tools-build-target multimodel_label_image
}

# Build inference diff tool
function tflite-tools-build-inference-diff-tool() {
    tflite-tools-build-target inf_diff_run_eval
}

# Build image classify tool
function tflite-tools-build-image-classify-tool() {
    tflite-tools-build-target image_classify_run_eval
}

# Build object detect tool
function tflite-tools-build-object-detect-tool() {
    tflite-tools-build-target object_detect_run_eval
}

# Build all tf lite targets
function tflite-tools-build-all() {
    tflite-tools-build                                                                          && \
        tflite-tools-build-label-image                                                          && \
        tflite-tools-build-multimodel-label-image                                               && \
        tflite-tools-build-benchmark-model                                                      && \
        tflite-tools-build-inference-diff-tool                                                  && \
        tflite-tools-build-image-classify-tool                                                  && \
        tflite-tools-build-object-detect-tool
}

# Install libs and executables
function tflite-tools-install() {
    pushd ${TFLITE_BUILD_DIR} 1>/dev/null

    cmake --install .                                                                           || \
        {
            popd 1>/dev/null
            print-red "tflite-tools-install failed: cmake install failed !!!"
            return -1
        }

    find ${TFLITE_DEPLOY_DBG_DIR} -type f -name *.a | xargs rm -f

    rm -rf ${TFLITE_DEPLOY_DIR} && cp -r ${TFLITE_DEPLOY_DBG_DIR} ${TFLITE_DEPLOY_DIR}

    [ -z "${STRIP}" ]                                                                           && \
        local STRIP=(`${TFLITE_SDK_SETUP} 2>/dev/null ; echo ${STRIP}`)

    local STRIP_le=${STRIP}
    local STRIP_lu=${STRIP}
    local STRIP_la=${TFLITE_NDK_DIR}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip
    local LIB_PATH_le=${TFLITE_DEPLOY_DIR}/usr/lib
    local LIB_PATH_lu=${TFLITE_DEPLOY_DIR}/usr/lib
    local LIB_PATH_la=${TFLITE_DEPLOY_DIR}/vendor/lib64
    local BIN_PATH_le=${TFLITE_DEPLOY_DIR}/usr/bin
    local BIN_PATH_lu=${TFLITE_DEPLOY_DIR}/usr/bin
    local BIN_PATH_la=${TFLITE_DEPLOY_DIR}/vendor/bin

    local STRIP=STRIP_${TFLITE_OS}
    local LIB_PATH=LIB_PATH_${TFLITE_OS}
    local BIN_PATH=BIN_PATH_${TFLITE_OS}

    local NATIVE_SYSROOT=""
    local STRIP_PATH=""

    [[ "${TFLITE_OS}" == "le" ]] || [[ "${TFLITE_OS}" == "lu" ]] && which ${!STRIP} > /dev/null || {
        NATIVE_SYSROOT=(`${TFLITE_SDK_SETUP} 2>/dev/null ; echo ${OECORE_NATIVE_SYSROOT}`)
        STRIP_PATH=${NATIVE_SYSROOT}/usr/bin/${TFLITE_TARGET_SYS}/
    }

    find ${!LIB_PATH} -type f | xargs ${STRIP_PATH}${!STRIP} -s ||
    {
        popd 1>/dev/null
        print-red "tflite-tools-install failed: lib stripping failed !!!"
        return -2
    }
    find ${!BIN_PATH} -type f | xargs ${STRIP_PATH}${!STRIP} -s ||
    {
        popd 1>/dev/null
        print-red "tflite-tools-install failed: bin stripping failed !!!"
        return -3
    }

    popd 1>/dev/null
}

# Incremental build and install
function tflite-tools-incremental-build-install() {
    tflite-tools-configure                                                                      && \
        tflite-tools-build-all                                                                  && \
        tflite-tools-install
}

# Clean, Configure, Build and Install
function tflite-tools-clean-build-install() {
    tflite-tools-clean                                                                          && \
        tflite-tools-incremental-build-install
}

# General package generation function
#   $1 - (mandatory) specify which folder to add to package
#   $2 - (mandatory) package file
function tflite-tools-ipk-pkg() {
    tflite-tools-platform-check-os                                                              || \
    {                                                                                              \
        tflite-tools-platform-check-image-build                                                 && \
        return 0                                                                                || \
        {
            print-red "tflite-tools-ipk-pkg failed: tflite-tools-platform-check-os failed !!!"
            return -1
        }
    }

    local DIR_TO_BE_PACKAGED=$1
    [ ! -d "${DIR_TO_BE_PACKAGED}" ]                                                            && \
        print-red "Path to deploy dir must be provided as first argument !!!"                   && \
        return -2

    local PACKAGE_FILE=$2
    [ -z "${PACKAGE_FILE}" ]                                                                    && \
        print-red "Package name must be specified !!!"                                          && \
        return -3

    # Create directories for package
    local TMP_PKG_DIR=`mktemp -d`
    mkdir -p ${TMP_PKG_DIR}/control ${TMP_PKG_DIR}/data
    echo 2.0 > ${TMP_PKG_DIR}/debian-binary
    cp -r ${DIR_TO_BE_PACKAGED}/* ${TMP_PKG_DIR}/data
    cat <<- EOT >> ${TMP_PKG_DIR}/control/control
Package: tflite
Maintainer: IOTCC
Architecture: aarch64
Section: Applications
Version: ${TFLITE_VERSION}
Description: TFLite binaries and libraries
EOT

    pushd ${TMP_PKG_DIR}/control 1>/dev/null
    tar --numeric-owner --group=0 --owner=0 -czf ../control.tar.gz ./*                          || \
        {
            popd 1>/dev/null
            rm -rf ${TMP_PKG_DIR}
            print-red "zipping control.tar.gz failed !!!"
            return -4
        }
    cd  ${TMP_PKG_DIR}/data
    tar --numeric-owner --group=0 --owner=0 -czf ../data.tar.gz ./*                             || \
        {
            popd 1>/dev/null
            rm -rf ${TMP_PKG_DIR}
            print-red "zipping data.tar.gz failed !!!"
            return -5
        }
    cd  ${TMP_PKG_DIR}
    ar rv ${PACKAGE_FILE} ./debian-binary ./data.tar.gz ./control.tar.gz                        || \
        {
            popd 1>/dev/null
            rm -rf ${TMP_PKG_DIR}
            print-red "${PACKAGE_FILE} archive creation failed !!!"
            return -6
        }

    popd 1>/dev/null
    rm -rf ${TMP_PKG_DIR}

    tflite-tools-update-local-hash ${PACKAGE_FILE}

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-tools-update-local-hash ${PACKAGE_FILE}"
        return -7
    }

    return 0
}

# General package generation function
#   $1 - (mandatory) specify which folder to add to package
#   $2 - (mandatory) package file
function tflite-tools-deb-pkg() {
    tflite-tools-platform-check-os                                                              || \
    {                                                                                              \
        tflite-tools-platform-check-image-build                                                 && \
        return 0                                                                                || \
        {
            print-red "tflite-tools-deb-pkg failed: tflite-tools-platform-check-os failed !!!"
            return -1
        }
    }

    local DIR_TO_BE_PACKAGED=$1
    [ ! -d "${DIR_TO_BE_PACKAGED}" ]                                                            && \
        print-red "Path to deploy dir must be provided as first argument !!!"                   && \
        return -2

    local PACKAGE_FILE=$2
    [ -z "${PACKAGE_FILE}" ]                                                                    && \
        print-red "Package name must be specified !!!"                                          && \
        return -3

    # Create directories for package
    local TMP_PKG_DIR=`mktemp -d`
    mkdir -p ${TMP_PKG_DIR}/control ${TMP_PKG_DIR}/data
    echo 2.0 > ${TMP_PKG_DIR}/debian-binary
    cp -r ${DIR_TO_BE_PACKAGED}/* ${TMP_PKG_DIR}/data
    cat <<- EOT >> ${TMP_PKG_DIR}/control/control
Package: tflite
Maintainer: IOTCC
Architecture: arm64
Section: Applications
Version: ${TFLITE_VERSION}
Description: TFLite binaries and libraries
EOT

    pushd ${TMP_PKG_DIR}/control 1>/dev/null
    tar --numeric-owner --group=0 --owner=0 -czf ../control.tar.gz ./*                          || \
        {
            popd 1>/dev/null
            rm -rf ${TMP_PKG_DIR}
            print-red "zipping control.tar.gz failed !!!"
            return -4
        }
    cd  ${TMP_PKG_DIR}/data
    tar --numeric-owner --group=0 --owner=0 -czf ../data.tar.gz ./*                             || \
        {
            popd 1>/dev/null
            rm -rf ${TMP_PKG_DIR}
            print-red "zipping data.tar.gz failed !!!"
            return -5
        }
    cd  ${TMP_PKG_DIR}
    ar rv ${PACKAGE_FILE} ./debian-binary ./control.tar.gz ./data.tar.gz                        || \
        {
            popd 1>/dev/null
            rm -rf ${TMP_PKG_DIR}
            print-red "${PACKAGE_FILE} archive creation failed !!!"
            return -6
        }

    popd 1>/dev/null
    rm -rf ${TMP_PKG_DIR}

    tflite-tools-update-local-hash ${PACKAGE_FILE}

    local rc=$?
    [ $rc -ne 0 ] && {
        print-red "FAILED: tflite-tools-update-local-hash ${PACKAGE_FILE}"
        return -7
    }

    return 0
}

# Update md5 hash for current package
function tflite-tools-update-local-hash() {
    local PATH_TO_CURRENT_PACKAGE=$1

    [ ! -f "${PATH_TO_CURRENT_PACKAGE}" ] && {
        print-red "No such package: ${PATH_TO_CURRENT_PACKAGE}"
        return -1
    }

    local SYNC_FILE="${TFLITE_PKG_DIR}/local_md5.log"

    [ -f "${SYNC_FILE}" ] || touch ${SYNC_FILE}

    local PKG_FILENAME=$(echo $(basename ${PATH_TO_CURRENT_PACKAGE}))
    local LOG=$(md5sum ${PATH_TO_CURRENT_PACKAGE})

    grep -q "${LOG}" ${SYNC_FILE} 1>/dev/null                                                   || \
        {
            sed -i "/\/${PKG_FILENAME}/d" ${SYNC_FILE} 2>/dev/null
            echo ${LOG} >> ${SYNC_FILE}
        }

    return 0
}

# Package build artifacts as ipk debug package
function tflite-tools-ipk-dbg-pkg() {
    tflite-tools-ipk-pkg ${TFLITE_DEPLOY_DBG_DIR} ${TFLITE_PKG_DIR}/tflite-dbg_${TFLITE_VERSION}.ipk
}

# Package build artifacts as deb debug package
function tflite-tools-deb-dbg-pkg() {
    tflite-tools-deb-pkg ${TFLITE_DEPLOY_DBG_DIR} ${TFLITE_PKG_DIR}/tflite-dbg_${TFLITE_VERSION}.deb
}

# Deploy ipk debug package to the device
function tflite-tools-ipk-dbg-pkg-deploy() {
    tflite-tools-device-pkg-deploy ${TFLITE_PKG_DIR}/tflite-dbg_${TFLITE_VERSION}.ipk
}

# Deploy deb debug package to the device
function tflite-tools-deb-dbg-pkg-deploy() {
    tflite-tools-device-deb-deploy ${TFLITE_PKG_DIR}/tflite-dbg_${TFLITE_VERSION}.deb
}

# Package build artifacts as ipk release package
function tflite-tools-ipk-rel-pkg() {
    tflite-tools-ipk-pkg ${TFLITE_DEPLOY_DIR} ${TFLITE_PKG_DIR}/tflite_${TFLITE_VERSION}.ipk
}

# Package build artifacts as deb release package
function tflite-tools-deb-rel-pkg() {
    tflite-tools-deb-pkg ${TFLITE_DEPLOY_DIR} ${TFLITE_PKG_DIR}/tflite_${TFLITE_VERSION}.deb
}

# Deploy ipk release package to the device
function tflite-tools-ipk-rel-pkg-deploy() {
    tflite-tools-device-pkg-deploy ${TFLITE_PKG_DIR}/tflite_${TFLITE_VERSION}.ipk
}

# Deploy deb release package to the device
function tflite-tools-deb-rel-pkg-deploy() {
    tflite-tools-device-deb-deploy ${TFLITE_PKG_DIR}/tflite_${TFLITE_VERSION}.deb
}

# Create dev package with interface headers and libraries
function tflite-tools-dev-pkg() {
    local SRC_DIR=${TFLITE_TF_SRC_DIR}
    local TFLITE_BUILD_DIR=${TFLITE_BUILD_DIR}
    local DST_DIR=${TFLITE_DEPLOY_DEV_DIR}
    local LIB_PREFIX_DIR_le="usr"
    local LIB_PREFIX_DIR_lu="usr"
    local LIB_PREFIX_DIR_la="vendor"
    local LIB_PREFIX_DIR=LIB_PREFIX_DIR_${TFLITE_OS}
    local LIB_DIR_le="${LIB_PREFIX_DIR_le}/lib"
    local LIB_DIR_lu="${LIB_PREFIX_DIR_lu}/lib"
    local LIB_DIR_la="${LIB_PREFIX_DIR_la}/lib64"
    local LIB_DIR=LIB_DIR_${TFLITE_OS}
    local DST_INC_DIR=${TFLITE_DEPLOY_DEV_DIR}/${!LIB_PREFIX_DIR}/include

    local PENDING_LIST=(
        "tensorflow/lite/model.h"
        "tensorflow/lite/interpreter.h"
        "tensorflow/lite/kernels/register.h"
        "tensorflow/lite/tools/evaluation/utils.h"
        "tensorflow/lite/delegates/nnapi/nnapi_delegate.h"
        "tensorflow/lite/delegates/hexagon/hexagon_delegate.h"
        "tensorflow/lite/delegates/gpu/delegate.h"
        "tensorflow/lite/delegates/xnnpack/xnnpack_delegate.h"
        "tensorflow/lite/examples/label_image/get_top_n.h"
        "tensorflow/lite/examples/label_image/get_top_n_impl.h"
        "tensorflow/lite/kernels/register.h"
        "tensorflow/core/public/version.h"
        "tensorflow/lite/version.h"
        "tensorflow/lite/delegates/external/external_delegate.h"
        "tensorflow/lite/delegates/external/external_delegate_interface.h"
    )

    # Remove the header from pending_list if it doesn't exist
    for HEADER in "${!PENDING_LIST[@]}"; do
        [ ! -f "${TFLITE_TF_SRC_DIR}/${PENDING_LIST[${HEADER}]}" ] && {
            unset -v 'PENDING_LIST[$HEADER]'
        }
    done

    local PROCESSED_LIST=()

    rm -rf ${DST_INC_DIR}
    mkdir -p ${DST_INC_DIR}

    while [ ${#PENDING_LIST[@]} -gt 0 ]; do
        # Get next file to be processed
        local H_FILE="${PENDING_LIST[0]}"
        local H_FILE_PATH_flatbuffers="${TFLITE_BUILD_DIR}/flatbuffers/include"
        local H_FILE_PATH_tensorflow="${SRC_DIR}"
        local H_FILE_LIB=`echo ${H_FILE} | cut -d '/' -f 1`
        local H_FILE_PATH=H_FILE_PATH_${H_FILE_LIB}
        local H_FILE_SRC="${!H_FILE_PATH}/${H_FILE}"

        # Find next set of included files
        local NEXT_H_FILES=($(grep "#include" ${H_FILE_SRC} | grep -E 'tensorflow|flatbuffers' | cut -d "\"" -f 2))

        # Append file to processed list
        PROCESSED_LIST+=("${H_FILE}")

        # Remove file from pending list
        PENDING_LIST=( "${PENDING_LIST[@]:1}" )

        # Check whether next files needs to be appended to pending list
        for NEXT_H_FILE in "${NEXT_H_FILES[@]}"; do
            if [[ ! " ${PENDING_LIST[*]} " =~ " ${NEXT_H_FILE} " ]]; then
                if [[ ! " ${PROCESSED_LIST[*]} " =~ " ${NEXT_H_FILE} " ]]; then
                    PENDING_LIST+=( "${NEXT_H_FILE}" )
                fi
            fi
        done

        # Copy file from src to destination
        local H_FILE_SRC="${!H_FILE_PATH}/./${H_FILE}"
        rsync -a --relative "${H_FILE_SRC}" "${DST_INC_DIR}"
    done

    # Add tensor flow shared library
    rsync -a --relative "${TFLITE_DEPLOY_DIR}/./${!LIB_DIR}/libtensorflowlite_c.so" "${DST_DIR}"

    # Add package config file
    mkdir -p ${DST_DIR}/${!LIB_DIR}/pkgconfig
    rsync -a ${TFLITE_DOWNLOAD_DIR}/tf-lite-${TFLITE_VERSION}/tensorflow-lite.pc ${DST_DIR}/${!LIB_DIR}/pkgconfig/tensorflow-lite-prebuilt.pc

    # Update install lib foder in the package config
    sed -i "s|\/usr\/lib|${TFLITE_DEVICE_INSTALL_PREFIX}\/usr/lib|g" ${DST_DIR}/${!LIB_DIR}/pkgconfig/tensorflow-lite-prebuilt.pc

    # Generate dev package
    pushd ${DST_DIR} 1>/dev/null
    tar -czf tflite-dev-${TFLITE_VERSION}.tar.gz ${!LIB_PREFIX_DIR}
    popd 1>/dev/null

    tflite-tools-ipk-pkg ${TFLITE_DEPLOY_DEV_DIR} ${TFLITE_PKG_DIR}/tflite-dev_${TFLITE_VERSION}.ipk
    tflite-tools-deb-pkg ${TFLITE_DEPLOY_DEV_DIR} ${TFLITE_PKG_DIR}/tflite-dev_${TFLITE_VERSION}.deb
}

# Deploy ipk dev package to the device
function tflite-tools-ipk-dev-pkg-deploy() {
    tflite-tools-device-pkg-deploy ${TFLITE_PKG_DIR}/tflite-dev_${TFLITE_VERSION}.ipk
}

# Deploy deb dev package to the device
function tflite-tools-deb-dev-pkg-deploy() {
    tflite-tools-device-deb-deploy ${TFLITE_PKG_DIR}/tflite-dev_${TFLITE_VERSION}.deb
}

TF_LITE_NUM_CPU=`cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1`

print-red "tflite-tools-clean-build-install"
echo "    Clean, Configure, Build and Install"
print-red "tflite-tools-incremental-build-install"
echo "    Incremental build and install"
print-red "tflite-tools-build-<tflite-target>"
echo "    Build desired tf lite target (benchmark-model/label-image/multimodel-label-image)"
print-red "tflite-tools-build-all"
echo "    Build all tf lite targets"
print-red "tflite-tools-clean"
echo "    Environment cleanup"
print-red "tflite-tools-dev-pkg"
echo "    Create dev package with interface headers and libraries"
print-red "tflite-tools-ipk-dev-pkg-deploy"
echo "    Deploy ipk dev package to the device"
print-red "tflite-tools-deb-dev-pkg-deploy"
echo "    Deploy deb dev package to the device"
print-red "tflite-tools-ipk-dbg-pkg"
echo "    Package build artifacts as ipk debug package"
print-red "tflite-tools-deb-dbg-pkg"
echo "    Package build artifacts as deb debug package"
print-red "tflite-tools-ipk-dbg-pkg-deploy"
echo "    Deploy ipk debug package to the device"
print-red "tflite-tools-deb-dbg-pkg-deploy"
echo "    Deploy deb debug package to the device"
print-red "tflite-tools-ipk-rel-pkg"
echo "    Package build artifacts as ipk release package"
print-red "tflite-tools-deb-rel-pkg"
echo "    Package build artifacts as deb release package"
print-red "tflite-tools-ipk-rel-pkg-deploy"
echo "    Deploy ipk release package to the device"
print-red "tflite-tools-deb-rel-pkg-deploy"
echo "    Deploy deb release package to the device"
