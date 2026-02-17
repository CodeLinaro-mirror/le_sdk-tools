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
        export CFLAGS="-mbranch-protection=standard -fstack-protector-strong -O2 `
            `-D_FORTIFY_SOURCE=2 -Wformat -Wformat-security -Werror=format-security -pipe `
            `-feliminate-unused-debug-types"
        export CXXFLAGS="${CFLAGS}"

        local CMAKE_FLAGS="-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON`
            ` -DSYSROOT_INCDIR=/usr/include`
            ` -DSYSROOT_LIBDIR=/usr/lib`
            ` -DCMAKE_INSTALL_PREFIX=/usr`
            ` -DCMAKE_INSTALL_INCLUDEDIR=include`
            ` -DCMAKE_INSTALL_BINDIR=bin`
            ` -DCMAKE_INSTALL_LIBDIR=lib/aarch64-linux-gnu`
            ` -DCMAKE_INSTALL_SYSCONFDIR=/etc`
            ` -DCMAKE_BUILD_TYPE=Debug`
            ` "${CMAKE_CUSTOM_CONFIG_FLAGS}""

        mkdir -p ${QIMSDK_BUILD_DIR}/${TARGET}

        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        cmake ${CMAKE_FLAGS} "${SOURCE_PATH}"                                                     |&
                tee "${QIMSDK_LOGS_DIR}/cmake_configure_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"

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
    local TARGET=${1}

    [ ! -d ${QIMSDK_BUILD_DIR}/${TARGET} ]                                                      && {
        print-red "No such build dir: ${QIMSDK_BUILD_DIR}/${TARGET}"
        print-red "Compilation will be skipped !"

        return -1
    }

    (
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        cmake --build . -j                                                                        |&
                tee "${QIMSDK_LOGS_DIR}/cmake_compile_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"
    ) || {
        print-red "FAILED: qimsdk-cmake-compile-${TARGET}: cmake compile failed !!!"
        return -1
    }

    print-green "qimsdk ${TARGET} built successfully !!!"
    return 0
}

# Install qimsdk CMake Target
#    ${1} - TARGET - CMake Target
function qimsdk-cmake-install() {
    local TARGET=${1}

    local DATE=$(date "+%Y_%m_%d-%H_%M_%S")
    local LOG_FILE_NAME=${QIMSDK_LOGS_DIR}/cmake_install_${TARGET}_${DATE}.log
    local LOG_FILE_NAME_DBG=${QIMSDK_LOGS_DIR}/cmake_install_${TARGET}_dbg_${DATE}.log

    [ ! -d ${QIMSDK_BUILD_DIR}/${TARGET} ]                                                      && {
        print-red "No such build dir: ${QIMSDK_BUILD_DIR}/${TARGET}"
        print-red "Installation will be skipped !"

        return -1
    }

    (
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail


        cmake --install . --prefix ${QIMSDK_INSTALL_DEBUG_DIR}/usr/                               |&
                tee ${LOG_FILE_NAME_DBG}                                                        && \
        cmake --install . --prefix /usr --strip                                                   |&
                tee ${LOG_FILE_NAME}                                                              |\
                grep -E 'Up-to-date:|Installing:|configuration:' | tail -n +2                     |\
                cut -d ' ' -f 3 | xargs -i rsync -aR {} ${QIMSDK_INSTALL_DIR}/ -f"- *.h"
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
        export GST_PLUGIN_SCANNER=/usr/lib/aarch64-linux-gnu/gstreamer1.0/gstreamer-1.0/`
                `gst-plugin-scanner

        DEB_BUILD_OPTIONS=parallel=$(nproc) debian/rules build binary || {
            print-red "FAILED: qimsdk-debian-rules-build: debian/rules build failed !!!"
            return -1
        }

        # Install debian packages from patched and built gst-plugins-base and gst-plugins-good
        # Installing is done through dpkg instead of apt as dependencies of these packages has
        #   already been installed through 'apt-get build-dep' in qimsdk-build image setup
        # They need to be installed in build image environment as compilation of QTI plugins depend
        #   on these packages' outputs being present in the system
        dpkg -i ${QIMSDK_DOWNLOAD_DIR}/gstreamer1.0-*.deb                                          \
                ${QIMSDK_DOWNLOAD_DIR}/libgstreamer-*.deb                                          \
                ${QIMSDK_DOWNLOAD_DIR}/gir1.2-gst-*.deb || {
            print-red "FAILED: qimsdk-debian-rules-build: dpkg install to root failed !!!"
            return -1
        }
    )
}

# Wrapper function to configure, compile & install qimsdk CMake Target
#    ${1} - SOURCE_PATH - Path to top-level CMake Project Directory
#    ${2} - CMAKE_CUSTOM_CONFIG_FLAGS - plugin specific flags to pass to CMake command
function qimsdk-cmake-build() {
    local SOURCE_PATH=${1}
    local T=$(qimsdk-get-project ${SOURCE_PATH})

    shift

    local CMAKE_CUSTOM_CONFIG_FLAGS=$@

    qimsdk-cmake-configure ${SOURCE_PATH} ${T} ${CMAKE_CUSTOM_CONFIG_FLAGS}                     && \
            qimsdk-cmake-compile ${T}                                                           && \
            qimsdk-cmake-install ${T}
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

# Clean gst-plugins-base
function qimsdk-debian-rules-clean-gst-plugins-base() {
    (
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}
        DEB_BUILD_OPTIONS=parallel=$(nproc) debian/rules clean
    )

    print-green "${FUNCNAME} completed successfully!"
}

# Clean gst-plugins-good
function qimsdk-debian-rules-clean-gst-plugins-good() {
    (
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}
        DEB_BUILD_OPTIONS=parallel=$(nproc) debian/rules clean
    )

    print-green "${FUNCNAME} completed successfully!"
}

# Incremental build all gst-plugins-imsdk
function qimsdk-cmake-build-gst-plugins-imsdk() {
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-imsdk `
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
            `-DENABLE_GST_PLUGIN_MLSNPE=ON `
            `-DENABLE_GST_PLUGIN_MLQNN=ON `
            `-DENABLE_GST_PLUGIN_MLMETAPARSER=ON `
            `-DENABLE_GST_PLUGIN_METATRANSFORM=ON `
            `-DENABLE_GST_PLUGIN_OBJTRACKER=ON `
            `-DENABLE_GST_PLUGIN_MLMETAEXTRACTOR=ON `
            `-DENABLE_GST_PLUGIN_MLPOSTPROCESS=ON `
            `-DENABLE_GST_PLUGIN_MSGBROKER=ON                                                   && \
        print-green "${FUNCNAME} completed successfully!"
}

# Clean gst-plugins-imsdk
function qimsdk-cmake-clean-gst-plugins-imsdk() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-imsdk

    print-green "${FUNCNAME} completed successfully!"
}

# Configure and build gst plugins
function qimsdk-incremental-build() {
    qimsdk-debian-rules-build-gst-plugins-base                                                  && \
            qimsdk-debian-rules-build-gst-plugins-good                                          && \
            qimsdk-cmake-build-gst-plugins-imsdk                                                && \
        print-green "QIMSDK GStreamer targets built successfully !!!"
}

print-green "qimsdk-incremental-build"
echo "    Incremental build of gst plugins"
print-green "qimsdk-cmake-build-gst-plugins-imsdk"
echo "    Incremental build all gst-plugins-imsdk"
