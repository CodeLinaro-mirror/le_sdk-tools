#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Normalize simple trailing slashes (portable; avoids requiring readlink/realpath)
# e.g., "/a/b///" -> "/a/b"
function qimsdk-strip-trailing-slashes() {
    echo "${1%/}";
}

# get first subdir after SOURCE_PATH
# Uses env vars: QIMSDK_SRC_DIR, QIMSDK_DOWNLOAD_DIR
function qimsdk-get-project() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local SOURCE_PATH="${1}"
    local BASES=("${QIMSDK_SRC_DIR}" "${QIMSDK_DOWNLOAD_DIR}")
    local DIR BASE REST FIRST

    DIR="$(qimsdk-strip-trailing-slashes "${SOURCE_PATH}")"

    for BASE in "${BASES[@]}"; do
        # Skip empty/unset bases
        [[ -n "${BASE}" ]] || continue
        BASE="$(qimsdk-strip-trailing-slashes "${BASE}")"

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
function qimsdk-cmake-configure() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
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
        qimsdk-setup-crosscompilation

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
        print-red "FAILED: qimsdk-cmake-configure-${TARGET}: cmake configure failed !!!"
        return -1
    }

    print-green "qimsdk ${TARGET} cmake configured successfully !!!"
    return 0
}

# Compile qimsdk CMake Target
#    ${1} - TARGET - CMake Target
function qimsdk-cmake-compile() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local TARGET=${1}

    [ ! -d ${QIMSDK_BUILD_DIR}/${TARGET} ]                                                      && {
        print-red "No such build dir: ${QIMSDK_BUILD_DIR}/${TARGET}"
        print-red "Compilation will be skipped !"

        return -1
    }

    (
        qimsdk-setup-crosscompilation
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        local DATE=$(date "+%Y_%m_%d-%H_%M_%S")

        ln -fs ${QIMSDK_LOGS_DIR}/cmake_compile_${TARGET}_${DATE}.log                              \
                ${QIMSDK_LOGS_DIR}/cmake_compile_${TARGET}.log

        cmake --build . -j${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}                                 |&
                tee "${QIMSDK_LOGS_DIR}/cmake_compile_${TARGET}_${DATE}.log"
    ) || {
        print-red "FAILED: qimsdk-cmake-compile-${TARGET}: cmake compile failed !!!"
        return -1
    }

    print-green "qimsdk ${TARGET} built successfully !!!"
    return 0
}

# Install qimsdk CMake Target
#    ${1} - TARGET - CMake Target
#    ${2} - INSTALL_PATH - Path used for install prefix
function qimsdk-cmake-install() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
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
        qimsdk-setup-crosscompilation

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
        print-red "FAILED: qimsdk-cmake-install-${TARGET}: cmake install failed !!!"
        return -1
    }

    cat ${LOG_FILE_NAME}

    print-green "qimsdk ${TARGET} installed successfully !!!"

    return 0
}

# Wrapper function to configure, compile, install & clean qimsdk debian/rules Target
function qimsdk-debian-rules-build() {
    (
        # Cross architecture
        export DEB_HOST_ARCH=arm64
        # Ensure users respect the optional QIMSDK_MAX_JOBS cpu jobs limitation
        export CMAKE_BUILD_PARALLEL_LEVEL=${QIMSDK_MAX_JOBS:-$(nproc)}
        # Skip tests: Docker build lacks GPU for GL tests and QEMU affects audio timing
        export DEB_BUILD_OPTIONS="parallel=${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)} nocheck"

        # GCC/G++ cross toolchain (optional but helps many builds)
        export CC=aarch64-linux-gnu-gcc
        export CXX=aarch64-linux-gnu-g++

        # GStreamer ARM64 plugin scanner
        export GST_PLUGIN_SCANNER=/usr/lib/aarch64-linux-gnu/gstreamer1.0/gstreamer-1.0/`
                `gst-plugin-scanner

        fakeroot debian/rules build binary || {
            echo "FAILED: qimsdk-debian-rules-build: debian/rules build failed!"
            return 1
        }

        # Install debian packages from patched and built gst-plugins-base and gst-plugins-good
        # Installing is done through dpkg instead of apt as dependencies of these packages has
        #   already been installed through 'apt-get build-dep -a arm64' in qimsdk_build image setup
        # They need to be installed in build image environment as compilation of QTI plugins depend
        #   on these packages' outputs being present in the system
        dpkg -i ${QIMSDK_DOWNLOAD_DIR}/gstreamer1.0-*.deb                                          \
                ${QIMSDK_DOWNLOAD_DIR}/libgstreamer-*.deb                                          \
                ${QIMSDK_DOWNLOAD_DIR}/gir1.2-gst-*.deb || {
            echo "FAILED: qimsdk-debian-rules-build: dpkg installation failed!"
            apt-get remove -y $(dpkg-deb -f ${QIMSDK_DOWNLOAD_DIR}/gstreamer1.0-*.deb Package)  || {
                echo "$(dpkg-deb -f ${QIMSDK_DOWNLOAD_DIR}/gstreamer1.0-*.deb Package) remove error!"
            }
            apt-get remove -y $(dpkg-deb -f ${QIMSDK_DOWNLOAD_DIR}/libgstreamer-*.deb Package)  || {
                echo "$(dpkg-deb -f ${QIMSDK_DOWNLOAD_DIR}/libgstreamer-*.deb Package) remove error!"
            }
            apt-get remove -y $(dpkg-deb -f ${QIMSDK_DOWNLOAD_DIR}/gir1.2-gst-*.deb Package)    || {
                echo "$(dpkg-deb -f ${QIMSDK_DOWNLOAD_DIR}/gir1.2-gst-*.deb Package) remove error!"
            }
            return 1
        }

        echo "=== DONE: ARM64 build completed ==="
    )
}

# Wrapper function to configure, compile & install qimsdk CMake Target
#    ${1} - SOURCE_PATH - Path to top-level CMake Project Directory
#    ${2} - INSTALL_PATH - Path used for install prefix
#    ${3..} - CMAKE_CUSTOM_CONFIG_FLAGS - plugin specific flags to pass to CMake command
function qimsdk-cmake-build() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local SOURCE_PATH=${1}
    local INSTALL_PATH=${2}
    local T=$(qimsdk-get-project ${SOURCE_PATH})

    shift;shift

    local CMAKE_CUSTOM_CONFIG_FLAGS=$@

    qimsdk-cmake-configure ${SOURCE_PATH} ${T} ${CMAKE_CUSTOM_CONFIG_FLAGS}                     && \
            qimsdk-cmake-compile ${T}                                                           && \
            qimsdk-cmake-install ${T} ${INSTALL_PATH}
}

###########################################################

# debian/rules build gst-plugins-base
qimsdk-debian-rules-build-gst-plugins-base() {
    (
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}
        qimsdk-debian-rules-build
    )
}

# debian/rules build gst-plugins-good
qimsdk-debian-rules-build-gst-plugins-good() {
    (
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}
        qimsdk-debian-rules-build
    )
}

# debian/rules build gst-plugins-bad
qimsdk-debian-rules-build-gst-plugins-bad() {
    (
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}
        qimsdk-debian-rules-build
    )
}

# Clean gst-plugins-base
function qimsdk-debian-rules-clean-gst-plugins-base() {
    (
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}
        DEB_BUILD_OPTIONS=parallel=${QIMSDK_MAX_JOBS:-$(nproc)} debian/rules clean
    )

    print-green "${FUNCNAME} completed successfully!"
}

# Clean gst-plugins-good
function qimsdk-debian-rules-clean-gst-plugins-good() {
    (
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}
        DEB_BUILD_OPTIONS=parallel=${QIMSDK_MAX_JOBS:-$(nproc)} debian/rules clean
    )

    print-green "${FUNCNAME} completed successfully!"
}

# Clean gst-plugins-bad
function qimsdk-debian-rules-clean-gst-plugins-bad() {
    (
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}
        DEB_BUILD_OPTIONS=parallel=${QIMSDK_MAX_JOBS:-$(nproc)} debian/rules clean
    )

    print-green "${FUNCNAME} completed successfully!"
}

# CMake Build camera metadata
function qimsdk-cmake-build-camera-metadata() {
    qimsdk-cmake-build ${QIMSDK_DOWNLOAD_DIR}/media /usr                                        && \
        print-green "${FUNCNAME} completed successfully!"
}

# CMake Clean camera metadata
function qimsdk-cmake-clean-metadata() {
    rm -rf ${QIMSDK_BUILD_DIR}/media                                                            && \
        print-green "${FUNCNAME} completed successfully!"
}

# CMake Build camera-service
function qimsdk-cmake-build-camera-service () {
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/camera-service /usr `
            `-DBUILD_CATEGORY=CLIENT                                                            && \
        print-green "${FUNCNAME} completed successfully!"
}

# CMake Clean camera-service
function qimsdk-cmake-clean-camera-service () {
    rm -rf ${QIMSDK_BUILD_DIR}/camera-service                                                   && \
        print-green "${FUNCNAME} completed successfully!"
}

# CMake Build abseil-cpp
qimsdk-cmake-build-abseil-cpp() {
    qimsdk-cmake-build ${QIMSDK_ABSEIL_CPP_DIR} /usr `
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

# CMake Clean abseil-cpp
function qimsdk-cmake-clean-abseil-cpp() {
    rm -rf ${QIMSDK_BUILD_DIR}/abseil-cpp                                                       && \
            print-green "${FUNCNAME} completed successfully!"
}

# CMake Build flatbuffers
function qimsdk-cmake-build-flatbuffers-v23-5-26() {
    qimsdk-cmake-build ${QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR} `
            `${QIMSDK_FLATBUFFERS_23_5_26_INSTALL_DIR} `
            `-DFLATBUFFERS_BUILD_TESTS=OFF `
            `-DFLATBUFFERS_BUILD_SHAREDLIB=OFF                                                  && \
        print-green "${FUNCNAME} completed successfully!"
}

# CMake Clean flatbuffers
function qimsdk-cmake-clean-flatbuffers-v23-5-26() {
    rm -rf ${QIMSDK_BUILD_DIR}/flatbuffersflatbuffers_23.4.26                                   && \
            print-green "${FUNCNAME} completed successfully!"
}

# CMake Build tflite
function qimsdk-cmake-build-tflite() {
    (
        qimsdk-cmake-build ${QIMSDK_DOWNLOAD_DIR}/tensorflow/tensorflow/lite/c /usr `
                `-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="${QIMSDK_DOWNLOAD_DIR}/cmake/force-system-protobuf.cmake" `
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
                `-DTF_MAJOR_VERSION=${QIMSDK_TF_LITE_MAJOR} `
                `-DTF_MINOR_VERSION=${QIMSDK_TF_LITE_MINOR} `
                `-DTF_PATCH_VERSION=${QIMSDK_TF_LITE_PATCH} `
                `-DTFLITE_ENABLE_INSTALL=ON `
                `-DTFLITE_ENABLE_LABEL_IMAGE=ON `
                `-DTFLITE_ENABLE_BENCHMARK_MODEL=ON `
                `-DTFLITE_ENABLE_XNNPACK=ON `
                `-DTFLITE_ENABLE_NNAPI=OFF `
                `-DTFLITE_ENABLE_RUY=ON `
                `-DTFLITE_ENABLE_GPU=ON                                                         && (
            cd ${QIMSDK_BUILD_DIR}/tensorflow

            # Install manually tflite apps to workaround tflite cmake file issues
            cmake -DCMAKE_INSTALL_PREFIX=${QIMSDK_INSTALL_DEBUG_DIR}/usr/ -P                       \
                    tensorflow-lite/tools/benchmark/cmake_install.cmake                         && \
            cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_DO_STRIP=ON -P                       \
                    tensorflow-lite/tools/benchmark/cmake_install.cmake                         && \
            cmake -DCMAKE_INSTALL_PREFIX=${QIMSDK_INSTALL_DIR}/usr -DCMAKE_INSTALL_DO_STRIP=ON -P  \
                    tensorflow-lite/tools/benchmark/cmake_install.cmake                         && \

            cmake -DCMAKE_INSTALL_PREFIX=${QIMSDK_INSTALL_DEBUG_DIR}/usr/ -P                       \
                    tensorflow-lite/examples/label_image/cmake_install.cmake                    && \
            cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_DO_STRIP=ON -P                       \
                    tensorflow-lite/examples/label_image/cmake_install.cmake                    && \
            cmake -DCMAKE_INSTALL_PREFIX=${QIMSDK_INSTALL_DIR}/usr -DCMAKE_INSTALL_DO_STRIP=ON -P  \
                    tensorflow-lite/examples/label_image/cmake_install.cmake
        )                                                                                       && \
        print-green "${FUNCNAME} completed successfully!"
    )
}

# CMake Clean tflite
function qimsdk-cmake-clean-tflite() {
    rm -rf ${QIMSDK_BUILD_DIR}/tensorflow                                                       && \
            print-green "${FUNCNAME} completed successfully!"
}

# Incremental build all gst-plugins-imsdk
function qimsdk-cmake-build-gst-plugins-imsdk() {
    (
        local IS_QNP_ENABLED=$( [ -n "${QIMSDK_QNP_VERSION:-}" ] && echo ON || echo OFF )

        # Set ${PYTHON_DIR} for the according python version for this shell
        #     (needed for site-packages dir during build)
        export PYTHON_DIR=python3.13

        # Build qti plugins
        qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-imsdk /usr `
                `-DPYTHON_SITEPACKAGES_DIR=lib/${PYTHON_DIR}/site-packages `
                `-DENABLE_GST_PLUGIN_BASE=ON `
                `-DENABLE_GST_PLUGIN_VCOMPOSER=ON `
                `-DENABLE_GST_PLUGIN_BATCH=ON `
                `-DENABLE_GST_PLUGIN_METAMUX=ON `
                `-DENABLE_GST_PLUGIN_SOCKET=ON `
                `-DENABLE_GST_PLUGIN_VSPLIT=ON `
                `-DENABLE_GST_PLUGIN_VTRANSFORM=ON `
                `-DENABLE_GST_PLUGIN_VOVERLAY=ON `
                `-DENABLE_GST_PLUGIN_RESTRICTED_ZONE=ON `
                `-DENABLE_GST_PLUGIN_RTSPBIN=ON `
                `-DENABLE_GST_PLUGIN_REDISSINK=ON `
                `-DENABLE_GST_PLUGIN_VIDEOTEMPLATE=ON `
                `-DENABLE_GST_PLUGIN_MLACONVERTER=ON `
                `-DENABLE_GST_PLUGIN_MLACLASSIFICATION=ON `
                `-DENABLE_GST_PLUGIN_MLDEMUX=ON `
                `-DENABLE_GST_PLUGIN_MLVCONVERTER=ON `
                `-DENABLE_GST_PLUGIN_MLVCLASSIFICATION=ON `
                `-DENABLE_GST_PLUGIN_MLVSUPERRESOLUTION=ON `
                `-DENABLE_GST_PLUGIN_MLVDETECTION=ON `
                `-DENABLE_GST_PLUGIN_MLVPOSE=ON `
                `-DENABLE_GST_PLUGIN_MLVSEGMENTATION=ON `
                `-DENABLE_GST_PLUGIN_MLTFLITE=ON `
                `-DENABLE_GST_PLUGIN_MLSNPE=${IS_QNP_ENABLED} `
                `-DENABLE_GST_PLUGIN_MLQNN=${IS_QNP_ENABLED} `
                `-DENABLE_GST_PLUGIN_MLMETAPARSER=ON `
                `-DENABLE_GST_PLUGIN_METATRANSFORM=ON `
                `-DENABLE_GST_PLUGIN_OBJTRACKER=ON `
                `-DENABLE_GST_PLUGIN_MLMETAEXTRACTOR=ON `
                `-DENABLE_GST_PLUGIN_MLPOSTPROCESS=ON `
                `-DENABLE_GST_PLUGIN_MSGBROKER=ON `
                `-DENABLE_GST_PLUGIN_QMMFSRC=ON `
                `-DENABLE_GST_PLUGIN_SMARTVENCBIN=ON `
                `-DENABLE_GST_PLUGIN_URIDECODEBIN=ON `
                `-DENABLE_GST_SAMPLE_APPS=ON `
                `-DENABLE_GST_SAMPLE_APPS_CAMERA=ON `
                `-DENABLE_GST_PYTHON_EXAMPLES=ON                                                && \
            print-green "${FUNCNAME} completed successfully!"
    )
}

# Clean gst-plugins-imsdk
function qimsdk-cmake-clean-gst-plugins-imsdk() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-imsdk                                                && \
            print-green "${FUNCNAME} completed successfully!"
}

# CMake Build solutions-microservices
qimsdk-cmake-build-solutions-microservices() {
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/solutions-microservices/microservices/qimsdk /usr      && \
        print-green "${FUNCNAME} completed successfully!"
}

# CMake Clean solutions-microservices
function qimsdk-cmake-clean-solutions-microservices() {
    rm -rf ${QIMSDK_BUILD_DIR}/solutions-microservices                                          && \
            print-green "${FUNCNAME} completed successfully!"
}

# Configure and build gst plugins
function qimsdk-incremental-build() {
    qimsdk-debian-rules-build-gst-plugins-base                                                  && \
            qimsdk-debian-rules-build-gst-plugins-good                                          && \
            qimsdk-debian-rules-build-gst-plugins-bad                                           && \
            qimsdk-cmake-build-camera-metadata                                                  && \
            qimsdk-cmake-build-camera-service                                                   && \
            qimsdk-cmake-build-abseil-cpp                                                       && \
            qimsdk-cmake-build-flatbuffers-v23-5-26                                             && \
            qimsdk-cmake-build-tflite                                                           && \
            qimsdk-cmake-build-gst-plugins-imsdk                                                && \
            qimsdk-cmake-build-solutions-microservices                                          && \
        print-green "QIMSDK GStreamer targets built successfully !!!"
}

print-green "qimsdk-incremental-build"
echo "    Incremental build of gst plugins"
print-green "qimsdk-cmake-build-gst-plugins-imsdk"
echo "    Incremental build all gst-plugins-imsdk"
