#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Normalize simple trailing slashes (portable; avoids requiring readlink/realpath)
# e.g., "/a/b///" -> "/a/b"
function builder-strip-trailing-slashes() {
    echo "${1%/}";
}

# get first subdir after SOURCE_PATH
# Uses env vars: QIMSDK_SRC_DIR, QIMSDK_DOWNLOAD_DIR
function builder-get-project() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local SOURCE_PATH="${1}"
    local BASES=("${QIMSDK_SRC_DIR}" "${QIMSDK_DOWNLOAD_DIR}")
    local DIR BASE REST FIRST

    DIR="$(builder-strip-trailing-slashes "${SOURCE_PATH}")"

    for BASE in "${BASES[@]}"; do
        # Skip empty/unset bases
        [[ -n "${BASE}" ]] || continue
        BASE="$(builder-strip-trailing-slashes "${BASE}")"

        # Match only if path starts with base path boundary (so /foo/bar doesn't match /fo)
        # Two cases: exact match, or base + "/" + rest
        if [[ "${DIR}" == "${BASE}" ]]; then
            # SOURCE_PATH equals base, so there's no subdir after it
            printf '%s\n' ""
            return 0
        elif [[ "${DIR}" == "${BASE}/"* ]]; then
            # Trim the base + slash
            REST="${DIR#"${BASE}/"}"
            # Extract first component after base
            FIRST="${REST%%/*}"
            printf '%s\n' "${FIRST}"
            return 0
        fi
    done

    # No base matched: return basename of SOURCE_PATH
    printf '%s\n' "${DIR##*/}"
}

# Configure qimsdk CMake Target
#    ${1} - SOURCE_PATH - Path to top-level CMake Project Directory
#    ${2} - TARGET - CMake Target
#    ${3..} - CMAKE_CUSTOM_CONFIG_FLAGS - plugin specific flags to pass to CMake command
function builder-cmake-configure() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local SOURCE_PATH=${1}
    local TARGET=${2}

    [ ! -d ${SOURCE_PATH} ]                                                                     && {
        print-red "No such source: ${SOURCE_PATH}"
        print-red "Configuration will be skipped !"

        return -1
    }

    shift;shift

    local CMAKE_CUSTOM_CONFIG_FLAGS=$@

    (
        builder-setup-crosscompilation

        export CFLAGS="-mbranch-protection=standard -fstack-protector-strong -O2 `
                `-D_FORTIFY_SOURCE=2 -Wformat -Wformat-security -Werror=format-security -pipe `
                `-feliminate-unused-debug-types"
        export CXXFLAGS="${CFLAGS}"

        local CMAKE_FLAGS="-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON `
                `-DCMAKE_INSTALL_DATAROOTDIR=share `
                `-DCMAKE_INSTALL_PREFIX=/usr `
                `-DCMAKE_INSTALL_INCLUDEDIR=include `
                `-DCMAKE_INSTALL_BINDIR=bin `
                `-DCMAKE_INSTALL_SBINDIR=sbin `
                `-DCMAKE_INSTALL_LIBDIR=lib/aarch64-linux-gnu `
                `-DCMAKE_INSTALL_LIBEXECDIR=libexec `
                `-DCMAKE_INSTALL_SYSCONFDIR=/etc `
                `-DCMAKE_INSTALL_LOCALSTATEDIR=/var `
                `-DCMAKE_BUILD_TYPE=Debug `
                `"${CMAKE_CUSTOM_CONFIG_FLAGS}""

        mkdir -p ${QIMSDK_BUILD_DIR}/${TARGET}

        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        local DATE=$(date "+%Y_%m_%d-%H_%M_%S")

        ln -fs ${QIMSDK_LOGS_DIR}/cmake_configure_${TARGET}_${DATE}.log                            \
                ${QIMSDK_LOGS_DIR}/cmake_configure_${TARGET}.log

        cmake ${CMAKE_FLAGS} "${SOURCE_PATH}"                                                     |&
                tee "${QIMSDK_LOGS_DIR}/cmake_configure_${TARGET}_${DATE}.log"
    ) || {
        print-red "FAILED: builder-cmake-configure-${TARGET}: cmake configure failed !!!"
        return -1
    }

    print-green "qimsdk ${TARGET} cmake configured successfully !!!"
    return 0
}

# Compile qimsdk CMake Target
#    ${1} - TARGET - CMake Target
function builder-cmake-compile() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local TARGET=${1}

    [ ! -d ${QIMSDK_BUILD_DIR}/${TARGET} ]                                                      && {
        print-red "No such build dir: ${QIMSDK_BUILD_DIR}/${TARGET}"
        print-red "Compilation will be skipped !"

        return -1
    }

    (
        builder-setup-crosscompilation
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        local DATE=$(date "+%Y_%m_%d-%H_%M_%S")

        ln -fs ${QIMSDK_LOGS_DIR}/cmake_compile_${TARGET}_${DATE}.log                              \
                ${QIMSDK_LOGS_DIR}/cmake_compile_${TARGET}.log

        cmake --build . -j${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}                                 |&
                tee "${QIMSDK_LOGS_DIR}/cmake_compile_${TARGET}_${DATE}.log"
    ) || {
        print-red "FAILED: builder-cmake-compile-${TARGET}: cmake compile failed !!!"
        return -1
    }

    print-green "qimsdk ${TARGET} built successfully !!!"
    return 0
}

# Install qimsdk CMake Target
#    ${1} - TARGET - CMake Target
#    ${2} - INSTALL_PATH - Path used for install prefix
function builder-cmake-install() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local TARGET=${1}
    local INSTALL_PATH=${2}

    local DATE=$(date "+%Y_%m_%d-%H_%M_%S")
    local LOG_FILE_NAME=${QIMSDK_LOGS_DIR}/cmake_install_${TARGET}_${DATE}.log
    local LOG_FILE_NAME_DBG=${QIMSDK_LOGS_DIR}/cmake_install_${TARGET}_dbg_${DATE}.log

    [ ! -d ${QIMSDK_BUILD_DIR}/${TARGET} ]                                                      && {
        print-red "No such build dir: ${QIMSDK_BUILD_DIR}/${TARGET}"
        print-red "Installation will be skipped !"

        return -1
    }

    (
        builder-setup-crosscompilation

        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        ln -fs ${LOG_FILE_NAME} ${QIMSDK_LOGS_DIR}/cmake_install_${TARGET}.log

        ln -fs ${LOG_FILE_NAME_DBG} ${QIMSDK_LOGS_DIR}/cmake_install_${TARGET}_dbg.log

        cmake --install . --prefix ${QIMSDK_INSTALL_DEBUG_DIR}/usr/                               |&
                tee ${LOG_FILE_NAME_DBG}                                                        && \
        cmake --install . --prefix "${INSTALL_PATH}" --strip                                      |&
                tee "${LOG_FILE_NAME}"                                                          && \
        rsync -aR --whole-file                                                                     \
                --files-from=<(grep -vE '\.(h|cmake|pc|inc|a)$' install_manifest.txt)              \
                / "${QIMSDK_INSTALL_DIR}/"
    ) || {
        print-red "FAILED: builder-cmake-install-${TARGET}: cmake install failed !!!"
        return -1
    }

    cat ${LOG_FILE_NAME}

    print-green "qimsdk ${TARGET} installed successfully !!!"

    return 0
}

# Wrapper function to configure, compile & install qimsdk CMake Target
#    ${1} - SOURCE_PATH - Path to top-level CMake Project Directory
#    ${2} - INSTALL_PATH - Path used for install prefix
#    ${3..} - CMAKE_CUSTOM_CONFIG_FLAGS - plugin specific flags to pass to CMake command
function builder-cmake-build() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! builder-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                   && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local SOURCE_PATH=${1}
    local INSTALL_PATH=${2}
    local T=$(builder-get-project ${SOURCE_PATH})

    shift;shift

    local CMAKE_CUSTOM_CONFIG_FLAGS=$@

    builder-cmake-configure ${SOURCE_PATH} ${T} ${CMAKE_CUSTOM_CONFIG_FLAGS}                    && \
            builder-cmake-compile ${T}                                                          && \
            builder-cmake-install ${T} ${INSTALL_PATH}
}

###########################################################

# Incremental build qimsdk project set containing:
#   - plugins base
#   - sample apps utils
#   - cpp app builder sdk
function builder-cmake-build-qimsdk() {
    builder-cmake-build ${QIMSDK_SRC_DIR}/qimsdk /usr `
            `-DENABLE_GST_PLUGIN_BASE=ON `
            `-DENABLE_GST_SAMPLE_APPS_UTILS=ON `
            `-DENABLE_APP_BUILDER_CPP=ON `
            `-DENABLE_APP_BUILDER_CPP_EXAMPLES=OFF                                              && \
        print-green "${FUNCNAME} completed successfully!"
}

# Clean qimsdk
function builder-cmake-clean-qimsdk() {
    # Remove both the plugins base and plugins build directories.
    rm -rf ${QIMSDK_BUILD_DIR}/qimsdk

    print-green "${FUNCNAME} completed successfully!"
}

# Configure and build gst plugins
function builder-incremental-build() {
            builder-cmake-build-qimsdk                                                          && \
        print-green "QIMSDK GStreamer targets built successfully !!!"
}

print-green "builder-incremental-build"
echo "    Incremental build of gst plugins"
print-green "builder-cmake-build-qimsdk"
echo "    Incremental build all qimsdk"
