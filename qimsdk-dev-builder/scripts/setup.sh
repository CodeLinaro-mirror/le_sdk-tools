#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Export cross-compilation environment variables
function builder-setup-crosscompilation() {
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
function builder-apply-patch() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
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
function builder-apply-patches() {
    builder-apply-patches-gst-plugins-base                                                      && \
            builder-apply-patches-gst-plugins-good                                              && \
            builder-apply-patches-gst-plugins-bad
}

# Apply patches to gst-plugins-base
function builder-apply-patches-gst-plugins-base() {
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
            builder-apply-patch ${PATCH} || return -1
        done
    )
}

# Apply patches to gst-plugins-good
function builder-apply-patches-gst-plugins-good() {

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
            builder-apply-patch ${PATCH} || return -1
        done
    )
}

# Apply patches to gst-plugins-bad
function builder-apply-patches-gst-plugins-bad() {
    [ ! -d "${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}" ]             && {
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
            builder-apply-patch ${PATCH} || return -1
        done
    )
}
