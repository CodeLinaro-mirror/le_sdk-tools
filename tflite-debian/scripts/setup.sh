#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Export cross-compilation environment variables
function tflite-setup-crosscompilation() {
    local TARGET_ARCH_VAL=$(uname -m)

    # Set value for build machine architecture for CONFIGURE_FLAGS
    local TFLITE_TARGET_ARCH=""
    [ "${TARGET_ARCH_VAL}" == "x86_64" ]  && TFLITE_TARGET_ARCH="${TARGET_ARCH_VAL}-linux"
    [ "${TARGET_ARCH_VAL}" == "aarch64" ] && TFLITE_TARGET_ARCH="${TARGET_ARCH_VAL}-linux-gnu"

    export CC="aarch64-linux-gnu-gcc  -march=armv8.2-a+crypto -mbranch-protection=standard `
            `-fstack-protector-strong  -O2 -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security `
            `-Werror=format-security --sysroot=${TFLITE_TARGET_SYSROOT}"
    export CXX="aarch64-linux-gnu-g++  -march=armv8.2-a+crypto -mbranch-protection=standard `
            `-fstack-protector-strong  -O2 -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security `
            `-Werror=format-security --sysroot=${TFLITE_TARGET_SYSROOT}"
    export CPP="aarch64-linux-gnu-gcc -E  -march=armv8.2-a+crypto -mbranch-protection=standard `
            `-fstack-protector-strong  -O2 -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security `
            `-Werror=format-security --sysroot=${TFLITE_TARGET_SYSROOT}"
    export AS="aarch64-linux-gnu-as "
    export LD="aarch64-linux-gnu-ld  --sysroot=${TFLITE_TARGET_SYSROOT}"
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
            `--build=${TFLITE_TARGET_ARCH} --with-libtool-sysroot=${TFLITE_TARGET_SYSROOT}"
    export CFLAGS=" -O2 -pipe -g -feliminate-unused-debug-types "
    export CXXFLAGS=" -O2 -pipe -g -feliminate-unused-debug-types "
    export LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed  -Wl,-z,relro,-z,now"
    export CPPFLAGS=""
    export KCFLAGS="--sysroot=${TFLITE_TARGET_SYSROOT}"
    export ARCH="arm64"

    # Set library/pkgconfig path for cross compilation binaries (it is not set for root user)
    export LD_LIBRARY_PATH="/usr/aarch64-linux-gnu/lib/:/usr/lib/aarch64-linux-gnu/"
    export LIBRARY_PATH="/usr/aarch64-linux-gnu/lib/:/usr/lib/aarch64-linux-gnu/"
    export PKG_CONFIG_PATH="/usr/lib/aarch64-linux-gnu/pkgconfig"
}
