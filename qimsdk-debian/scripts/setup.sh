#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Export cross-compilation environment variables
function qimsdk-setup-crosscompilation() {
    local TARGET_ARCH_VAL=$(uname -m)

    # Set value for build machine architecture for CONFIGURE_FLAGS
    local QIMSDK_TARGET_ARCH=""
    [ "${TARGET_ARCH_VAL}" == "x86_64" ]  && QIMSDK_TARGET_ARCH="${TARGET_ARCH_VAL}-linux"
    [ "${TARGET_ARCH_VAL}" == "aarch64" ] && QIMSDK_TARGET_ARCH="${TARGET_ARCH_VAL}-linux-gnu"

    export CC="aarch64-linux-gnu-gcc  -march=armv8.2-a+crypto -mbranch-protection=standard `
            `-fstack-protector-strong  -O2 -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security `
            `-Werror=format-security --sysroot=${QIMSDK_TARGET_SYSROOT}"
    export CXX="aarch64-linux-gnu-g++  -march=armv8.2-a+crypto -mbranch-protection=standard `
            `-fstack-protector-strong  -O2 -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security `
            `-Werror=format-security --sysroot=${QIMSDK_TARGET_SYSROOT}"
    export CPP="aarch64-linux-gnu-gcc -E  -march=armv8.2-a+crypto -mbranch-protection=standard `
            `-fstack-protector-strong  -O2 -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security `
            `-Werror=format-security --sysroot=${QIMSDK_TARGET_SYSROOT}"
    export AS="aarch64-linux-gnu-as "
    export LD="aarch64-linux-gnu-ld  --sysroot=${QIMSDK_TARGET_SYSROOT}"
    export GDB=aarch64-linux-gnu-gdb
    export STRIP=aarch64-linux-gnu-strip
    export RANLIB=aarch64-linux-gnu-ranlib
    export OBJCOPY=aarch64-linux-gnu-objcopy
    export OBJDUMP=aarch64-linux-gnu-objdump
    export READELF=aarch64-linux-gnu-readelf
    export AR=aarch64-linux-gnu-ar
    export NM=aarch64-linux-gnu-nm
    export M4=m4
    export TARGET_PREFIX=aarch64-linux-gnu-
    export CONFIGURE_FLAGS="--target=aarch64-linux-gnu --host=aarch64-linux-gnu `
            `--build=${QIMSDK_TARGET_ARCH} --with-libtool-sysroot=${QIMSDK_TARGET_SYSROOT}"
    export CFLAGS=" -O2 -pipe -g -feliminate-unused-debug-types "
    export CXXFLAGS=" -O2 -pipe -g -feliminate-unused-debug-types "
    export LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed  -Wl,-z,relro,-z,now"
    export CPPFLAGS=""
    export KCFLAGS="--sysroot=${QIMSDK_TARGET_SYSROOT}"
    export ARCH="arm64"

    # Set library/pkgconfig path for cross compilation binaries (it is not set for root user)
    export LD_LIBRARY_PATH="/usr/aarch64-linux-gnu/lib/:/usr/lib/aarch64-linux-gnu/"
    export LIBRARY_PATH="/usr/aarch64-linux-gnu/lib/:/usr/lib/aarch64-linux-gnu/"
    export PKG_CONFIG_PATH="/usr/lib/aarch64-linux-gnu/pkgconfig"
    # Ensure users respect the optional QIMSDK_MAX_JOBS cpu jobs limitation
    export CMAKE_BUILD_PARALLEL_LEVEL=${QIMSDK_MAX_JOBS:-$(nproc)}
}

# git am wrapper function
#   $1 - Path to patch file
function qimsdk-apply-patch() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATCH_FILE=${1}

    # Legal notices are present in QTI specific .patch files, so they could gain legal approval
    # They need to be removed to avoid trouble with git am
    # This is done by removing all leading comment lines from the patch file and then applying it
    sed -i '1,/^[^+#]/ { /^[+]*#/d; }' ${PATCH_FILE}                                            && \
            git am ${PATCH_FILE}                                                                || {
        echo "Failed to apply patch ${PATCH_FILE}!"
        return -1
    }
}

# Wrapper function to apply qti patches to all needed opensource libs
function qimsdk-apply-patches() {
    qimsdk-apply-patches-gst-plugins-base                                                       && \
            qimsdk-apply-patches-gst-plugins-good                                               && \
            qimsdk-apply-patches-gst-plugins-bad
}

# Apply patches to gst-plugins-base
function qimsdk-apply-patches-gst-plugins-base() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}" ]           && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/`
                `gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION} !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GST_META}/gstreamer1.0-plugins-base/"

        [ ! -d ${PATH_TO_PATCHES} ]                                                             && {
            print-red "gstreamer-plugins-base's patches NOT found in  ${PATH_TO_PATCHES} !!!"
            return -1
        }

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}

        for PATCH in ${PATH_TO_PATCHES}*.patch; do
            qimsdk-apply-patch ${PATCH} || return -1
        done
    )
}

# Apply patches to gst-plugins-good
function qimsdk-apply-patches-gst-plugins-good() {

    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}" ]           && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/`
                `gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION} !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GST_META}/gstreamer1.0-plugins-good/"

        [ ! -d ${PATH_TO_PATCHES} ]                                                             && {
            print-red "gstreamer-plugins-good's patches NOT found in ${PATH_TO_PATCHES}!!!"
            return -1
        }

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}

        for PATCH in ${PATH_TO_PATCHES}*.patch; do
            qimsdk-apply-patch ${PATCH} || return -1
        done
    )
}

# Apply patches to gst-plugins-bad
function qimsdk-apply-patches-gst-plugins-bad() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}" ]           && {
        echo "No such file or directory: ${QIMSDK_DOWNLOAD_DIR}/`
                `gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION} !"
        return -1
    }

    (
        local PATH_TO_PATCHES="${QIMSDK_PATH_TO_GST_META}/gstreamer1.0-plugins-bad/"

        [ ! -d ${PATH_TO_PATCHES} ]                                                             && {
            print-red "gstreamer-plugins-bad's patches NOT found in  ${PATH_TO_PATCHES} !!!"
            return -1
        }

        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}

        for PATCH in ${PATH_TO_PATCHES}*.patch; do
            qimsdk-apply-patch ${PATCH} || return -1
        done
    )
}

# Copy the Tensorflow Lite's headers and dependent headers to the sysroot
function qimsdk-copy-tf-lite-headers-to-sysroot() {
    local SRC_DIR=${QIMSDK_TF_SRC_DIR}
    local DST_INC_DIR="/usr/include/"

    local PENDING_LIST_INIT=""

    local QIMSDK_QTI_SRC_DIR=${QIMSDK_SRC_DIR}/gst-plugins-imsdk
    local ML_TFLITE_ENGINE_CC=$(find "${QIMSDK_QTI_SRC_DIR}" -name "ml-tflite-engine-c-api.cc")
    local ML_TFLITE_ENGINE_H=$(find "${QIMSDK_QTI_SRC_DIR}" -name "ml-tflite-engine.h")

    local ML_TFLITE_ENGINE_CC_INCS=""

    ML_TFLITE_ENGINE_CC_INCS=$(
        cat ${ML_TFLITE_ENGINE_CC} |grep "include.*.tensorflow" | cut -f2 -d "<" | rev |
                cut -f2 -d ">" | rev
    )

    PENDING_LIST_INIT+="${ML_TFLITE_ENGINE_CC_INCS}"
    PENDING_LIST_INIT+=$'\n'

    local ML_TFLITE_ENGINE_H_INCS=""

    ML_TFLITE_ENGINE_H_INCS=$(
        cat ${ML_TFLITE_ENGINE_H} | grep "include.*.tensorflow" | cut -f2 -d "<" | rev |
                cut -f2 -d ">" | rev
    )

    PENDING_LIST_INIT+="${ML_TFLITE_ENGINE_H_INCS}"
    PENDING_LIST_INIT+=$'\n'

    local PENDING_LIST=()

    for i in ${PENDING_LIST_INIT}; do
        PENDING_LIST+=($i)
    done

    # Remove the header from pending_list if it doesn't exist
    for HEADER in "${!PENDING_LIST[@]}"; do
        [ ! -f "${QIMSDK_TF_SRC_DIR}/${PENDING_LIST[${HEADER}]}" ]                              && {
            unset 'PENDING_LIST[HEADER]'
        }
    done

    local PROCESSED_LIST=()

    while [ ${#PENDING_LIST[@]} -gt 0 ]; do
        # Get next file to be processed
        local H_FILE=${PENDING_LIST[0]}

        [ -z ${H_FILE} ]                                                                        && {
            # Remove file from pending list
            PENDING_LIST=( "${PENDING_LIST[@]:1}" )
            continue
        }

        local H_FILE_PATH_tensorflow="${SRC_DIR}"
        local H_FILE_LIB=$(echo ${H_FILE} | cut -d '/' -f 1)
        local H_FILE_PATH=H_FILE_PATH_${H_FILE_LIB}
        local H_FILE_SRC="${!H_FILE_PATH}/${H_FILE}"

        # Find next set of included files
        local NEXT_H_FILES=(
            $(grep "#include" ${H_FILE_SRC} | grep -E 'tensorflow' | cut -d "\"" -f 2)
        )

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
}
