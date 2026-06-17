#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Normalize simple trailing slashes (portable; avoids requiring readlink/realpath)
# e.g., "/a/b///" -> "/a/b"
function tflite-strip-trailing-slashes() {
    echo "${1%/}";
}

# get first subdir after SOURCE_PATH
# Uses env vars: TFLITE_SRC_DIR, TFLITE_DOWNLOAD_DIR
function tflite-get-project() {
    local TFLITE_ARG_COUNT_EXPECTED=1
    ! tflite-arg-count-check $# ${TFLITE_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${TFLITE_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local SOURCE_PATH="${1}"
    local BASES=("${TFLITE_SRC_DIR}" "${TFLITE_DOWNLOAD_DIR}")
    local DIR BASE REST FIRST

    DIR="$(tflite-strip-trailing-slashes "${SOURCE_PATH}")"

    for BASE in "${BASES[@]}"; do
        # Skip empty/unset bases
        [[ -n "${BASE}" ]] || continue
        BASE="$(tflite-strip-trailing-slashes "${BASE}")"

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

# Configure tflite CMake Target
#    ${1} - SOURCE_PATH - Path to top-level CMake Project Directory
#    ${2} - TARGET - CMake Target
#    ${3..} - CMAKE_CUSTOM_CONFIG_FLAGS - plugin specific flags to pass to CMake command
function tflite-cmake-configure() {
    local TFLITE_ARG_COUNT_EXPECTED=2
    ! tflite-arg-count-check $# ${TFLITE_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${TFLITE_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
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
        tflite-setup-crosscompilation

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

        mkdir -p ${TFLITE_BUILD_DIR}/${TARGET}

        cd ${TFLITE_BUILD_DIR}/${TARGET}

        set -o pipefail

        local DATE=$(date "+%Y_%m_%d-%H_%M_%S")

        ln -fs ${TFLITE_LOGS_DIR}/cmake_configure_${TARGET}_${DATE}.log                            \
                ${TFLITE_LOGS_DIR}/cmake_configure_${TARGET}.log

        cmake ${CMAKE_FLAGS} "${SOURCE_PATH}"                                                     |&
                tee "${TFLITE_LOGS_DIR}/cmake_configure_${TARGET}_${DATE}.log"
    ) || {
        print-red "FAILED: tflite-cmake-configure-${TARGET}: cmake configure failed !!!"
        return -1
    }

    print-green "tflite ${TARGET} cmake configured successfully !!!"
    return 0
}

# Compile tflite CMake Target
#    ${1} - TARGET - CMake Target
function tflite-cmake-compile() {
    local TFLITE_ARG_COUNT_EXPECTED=1
    ! tflite-arg-count-check $# ${TFLITE_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${TFLITE_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local TARGET=${1}

    [ ! -d ${TFLITE_BUILD_DIR}/${TARGET} ]                                                      && {
        print-red "No such build dir: ${TFLITE_BUILD_DIR}/${TARGET}"
        print-red "Compilation will be skipped !"

        return -1
    }

    (
        tflite-setup-crosscompilation

        cd ${TFLITE_BUILD_DIR}/${TARGET}

        set -o pipefail

        local DATE=$(date "+%Y_%m_%d-%H_%M_%S")

        ln -fs ${TFLITE_LOGS_DIR}/cmake_compile_${TARGET}_${DATE}.log                              \
                ${TFLITE_LOGS_DIR}/cmake_compile_${TARGET}.log

        cmake --build . -j                                                                        |&
                tee "${TFLITE_LOGS_DIR}/cmake_compile_${TARGET}_${DATE}.log"
    ) || {
        print-red "FAILED: tflite-cmake-compile-${TARGET}: cmake compile failed !!!"
        return -1
    }

    print-green "tflite ${TARGET} built successfully !!!"
    return 0
}

# Install tflite CMake Target
#    ${1} - TARGET - CMake Target
#    ${2} - INSTALL_PATH - Path used for install prefix
function tflite-cmake-install() {
    local TFLITE_ARG_COUNT_EXPECTED=2
    ! tflite-arg-count-check $# ${TFLITE_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${TFLITE_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local TARGET=${1}
    local INSTALL_PATH=${2}

    local DATE=$(date "+%Y_%m_%d-%H_%M_%S")
    local LOG_FILE_NAME=${TFLITE_LOGS_DIR}/cmake_install_${TARGET}_${DATE}.log
    local LOG_FILE_NAME_DBG=${TFLITE_LOGS_DIR}/cmake_install_${TARGET}_dbg_${DATE}.log

    [ ! -d ${TFLITE_BUILD_DIR}/${TARGET} ]                                                      && {
        print-red "No such build dir: ${TFLITE_BUILD_DIR}/${TARGET}"
        print-red "Installation will be skipped !"

        return -1
    }

    (
        tflite-setup-crosscompilation

        cd ${TFLITE_BUILD_DIR}/${TARGET}

        set -o pipefail

        ln -fs ${LOG_FILE_NAME} ${TFLITE_LOGS_DIR}/cmake_install_${TARGET}.log

        ln -fs ${LOG_FILE_NAME_DBG} ${TFLITE_LOGS_DIR}/cmake_install_${TARGET}_dbg.log

        cmake --install . --prefix ${TFLITE_INSTALL_DEBUG_DIR}/usr/                               |&
                tee ${LOG_FILE_NAME_DBG}                                                        && \
        cmake --install . --prefix "${INSTALL_PATH}" --strip                                      |&
                tee "${LOG_FILE_NAME}"                                                          && \
        rsync -aR --whole-file                                                                     \
                --files-from=<(grep -vE '\.(h|cmake|pc|inc|a)$' install_manifest.txt)              \
                / "${TFLITE_INSTALL_DIR}/"
    ) || {
        print-red "FAILED: tflite-cmake-install-${TARGET}: cmake install failed !!!"
        return -1
    }

    cat ${LOG_FILE_NAME}

    print-green "tflite ${TARGET} installed successfully !!!"

    return 0
}

# Wrapper function to configure, compile & install tflite CMake Target
#    ${1} - SOURCE_PATH - Path to top-level CMake Project Directory
#    ${2} - INSTALL_PATH - Path used for install prefix
#    ${3..} - CMAKE_CUSTOM_CONFIG_FLAGS - plugin specific flags to pass to CMake command
function tflite-cmake-build() {
    local TFLITE_ARG_COUNT_EXPECTED=2
    ! tflite-arg-count-check $# ${TFLITE_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${TFLITE_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local SOURCE_PATH=${1}
    local INSTALL_PATH=${2}
    local T=$(tflite-get-project ${SOURCE_PATH})

    shift;shift

    local CMAKE_CUSTOM_CONFIG_FLAGS=$@

    tflite-cmake-configure ${SOURCE_PATH} ${T} ${CMAKE_CUSTOM_CONFIG_FLAGS}                     && \
            tflite-cmake-compile ${T}                                                           && \
            tflite-cmake-install ${T} ${INSTALL_PATH}
}

# CMake Build abseil-cpp
tflite-cmake-build-abseil-cpp() {
    tflite-cmake-build ${TFLITE_ABSEIL_CPP_DIR} /usr `
            `-DBUILD_SHARED_LIBS=ON `
            `-DABSL_BUILD_STATIC=OFF `
            `-DABSL_ENABLE_INSTALL=ON `
            `-DABSL_USE_GOOGLETEST_HEAD=OFF `
            `-DCMAKE_SYSTEM_NAME=Linux `
            `-DCMAKE_SYSTEM_PROCESSOR=aarch64 `
            `-DABSL_BUILD_TESTING=OFF `
            `-DABSL_RUN_TESTS=OFF                                                               && \
        print-green "${FUNCNAME} completed successfully!"
}

# CMake Build flatbuffers
tflite-cmake-build-flatbuffers-v23-5-26() {
    tflite-cmake-build ${TFLITE_FLATBUFFERS_23_5_26_SRC_DIR} `
            `${TFLITE_FLATBUFFERS_23_5_26_INSTALL_DIR} `
            `-DFLATBUFFERS_BUILD_TESTS=OFF `
            `-DFLATBUFFERS_BUILD_SHAREDLIB=OFF                                                  && \
        print-green "${FUNCNAME} completed successfully!"
}

# CMake Build tflite
function tflite-cmake-build-tflite() {
    (
        tflite-cmake-build ${TFLITE_DOWNLOAD_DIR}/tensorflow/tensorflow/lite/c /usr `
                `-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="${TFLITE_DOWNLOAD_DIR}/cmake/force-system-protobuf.cmake" `
                `-DCMAKE_POLICY_DEFAULT_CMP0135=OLD `
                `-DCMAKE_POLICY_DEFAULT_CMP0169=OLD `
                `-DCMAKE_POLICY_DEFAULT_CMP0077=OLD `
                `-DCMAKE_POLICY_DEFAULT_CMP0177=OLD `
                `-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON `
                `-DCMAKE_POLICY_VERSION_MINIMUM=3.5 `
                `-DCMAKE_SYSTEM_NAME=Linux `
                `-DCPUINFO_BUILD_UNIT_TESTS=OFF `
                `-DCPUINFO_SUPPORTED_PLATFORM=ON `
                `-DCMAKE_SYSTEM_PROCESSOR=arm64 `
                `-DProtobuf_PROTOC_EXECUTABLE=/usr/bin/protoc `
                `-DTF_MAJOR_VERSION=${TFLITE_TF_LITE_MAJOR} `
                `-DTF_MINOR_VERSION=${TFLITE_TF_LITE_MINOR} `
                `-DTF_PATCH_VERSION=${TFLITE_TF_LITE_PATCH} `
                `-DTFLITE_ENABLE_INSTALL=ON `
                `-DTFLITE_ENABLE_LABEL_IMAGE=ON `
                `-DTFLITE_ENABLE_BENCHMARK_MODEL=ON `
                `-DTFLITE_ENABLE_XNNPACK=ON `
                `-DTFLITE_ENABLE_NNAPI=OFF `
                `-DTFLITE_ENABLE_RUY=ON `
                `-DTFLITE_ENABLE_GPU=ON                                                         && (
            cd ${TFLITE_BUILD_DIR}/tensorflow

            # Install manually tflite apps to workaround tflite cmake file issues
            cmake -DCMAKE_INSTALL_PREFIX=${TFLITE_INSTALL_DEBUG_DIR}/usr/ -P                       \
                    tensorflow-lite/tools/benchmark/cmake_install.cmake                         && \
            cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_DO_STRIP=ON -P                       \
                    tensorflow-lite/tools/benchmark/cmake_install.cmake                         && \
            cmake -DCMAKE_INSTALL_PREFIX=${TFLITE_INSTALL_DIR}/usr -DCMAKE_INSTALL_DO_STRIP=ON -P  \
                    tensorflow-lite/tools/benchmark/cmake_install.cmake                         && \

            cmake -DCMAKE_INSTALL_PREFIX=${TFLITE_INSTALL_DEBUG_DIR}/usr/ -P                       \
                    tensorflow-lite/examples/label_image/cmake_install.cmake                    && \
            cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_DO_STRIP=ON -P                       \
                    tensorflow-lite/examples/label_image/cmake_install.cmake                    && \
            cmake -DCMAKE_INSTALL_PREFIX=${TFLITE_INSTALL_DIR}/usr -DCMAKE_INSTALL_DO_STRIP=ON -P  \
                    tensorflow-lite/examples/label_image/cmake_install.cmake
        )                                                                                       && \
        print-green "${FUNCNAME} completed successfully!"
    )
}

# Configure and build gst plugins
function tflite-incremental-build() {
    tflite-cmake-build-abseil-cpp                                                               && \
    tflite-cmake-build-flatbuffers-v23-5-26                                                     && \
    tflite-cmake-build-tflite                                                                   && \
    print-green "TFLITE built successfully !!!"
}

print-green "tflite-incremental-build"
echo "    Incremental build of Tflite"
