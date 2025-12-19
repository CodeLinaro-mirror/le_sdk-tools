#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Configure qimsdk meson Target
#    ${1} - SOURCE_PATH - Path to top-level Meson Project Directory
#    ${2} - TARGET - meson Target
#    ${3..} - MESON_CONFIG_FLAGS - flags to pass to meson configure
function qimsdk-meson-configure() {
    local SOURCE_PATH=${1}
    local TARGET=${2}

    shift;shift

    local MESON_CONFIG_FLAGS=$@

    (
        export CFLAGS="-mbranch-protection=standard -fstack-protector-strong -O2 `
            `-D_FORTIFY_SOURCE=2 -Wformat -Wformat-security -Werror=format-security -pipe `
            `-feliminate-unused-debug-types -Wno-incompatible-pointer-types"
        export CXXFLAGS="${CFLAGS}"

        mkdir -p ${QIMSDK_BUILD_DIR}
        cd ${QIMSDK_BUILD_DIR}
        set -o pipefail

        meson setup ${MESON_CONFIG_FLAGS} ${TARGET} ${SOURCE_PATH}                              && \
                cd ${TARGET}                                                                    && \
                meson configure ${MESON_CONFIG_FLAGS}                                             |&
                tee "${QIMSDK_LOGS_DIR}/meson_configure_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"
    ) || {
        print-red "FAILED: qimsdk-meson-configure-${TARGET}: meson configure failed !!!"
        return -1
    }

    print-green "qimsdk ${TARGET} meson configured successfully !!!"
    return 0
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
            ` -DGST_PLUGINS_QTI_OSS_VERSION=1.26`
            ` -DGST_VERSION_REQUIRED=1.26`
            ` -DSYSROOT_INCDIR=/usr/include`
            ` -DSYSROOT_LIBDIR=/usr/lib`
            ` -DGST_PLUGINS_QTI_OSS_INSTALL_INCDIR=/usr/include`
            ` -DGST_PLUGINS_QTI_OSS_INSTALL_BINDIR=/usr/bin`
            ` -DGST_PLUGINS_QTI_OSS_INSTALL_LIBDIR=/usr/lib/aarch64-linux-gnu`
            ` -DGST_PLUGINS_QTI_OSS_INSTALL_CONFIG=/etc/configs/`
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

# Compile qimsdk meson Target
#    ${1} - TARGET - meson Target
function qimsdk-meson-compile() {
    local TARGET=${1}
    (
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        meson compile -v                                                                          |&
                tee "${QIMSDK_LOGS_DIR}/meson_compile_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"
    ) || {
        print-red "FAILED: qimsdk-meson-compile-${TARGET}: meson compile failed !!!"
        return -1
    }

    print-green "qimsdk ${TARGET} built successfully !!!"
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

        cmake --build .                                                                           |&
                tee "${QIMSDK_LOGS_DIR}/cmake_compile_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"
    ) || {
        print-red "FAILED: qimsdk-cmake-compile-${TARGET}: cmake compile failed !!!"
        return -1
    }

    print-green "qimsdk ${TARGET} built successfully !!!"
    return 0
}

# Install qimsdk meson Target
#    ${1} - TARGET - meson Target
#    ${2} - DESTINATION - meson install destination directory
function qimsdk-meson-install() {
    local TARGET=${1}
    local DESTINATION=${2}
    local INSTALL_TIME=$(date "+%Y_%m_%d-%H_%M_%S")
    local INSTALL_LOG="${QIMSDK_LOGS_DIR}/meson_install_${TARGET}_${INSTALL_TIME}.log"
    local FILEPATH_LOG="/tmp/${INSTALL_TIME}_filepath.log"
    local PATHS_LOG="/tmp/${INSTALL_TIME}_paths.log"
    local FILES_LOG="/tmp/${INSTALL_TIME}_files.log"

    # Install to dev container root to be used by other dev container projects
    (
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        meson install --destdir ${QIMSDK_INSTALL_DEBUG_DIR}                                       |&
                tee "${QIMSDK_LOGS_DIR}/meson_install_${TARGET}_${INSTALL_TIME}`
                `_dbg.log"                                                                      && \
                meson install --destdir / --strip |& tee ${INSTALL_LOG}
    ) || {
        print-red "FAILED: qimsdk-meson-install-${TARGET}: meson install to root failed !!!"
        return -1
    }

    # Propagate minimal needed files to device container deploy dir
    (
        set -o pipefail

        cat ${INSTALL_LOG} | grep -E '^Installing'                                                |\
                grep -Ev '^Installing symlink|^Installing subdir|^Installing new directory'        \
                    > ${FILEPATH_LOG}                                                           && \
                sed -e 's/$/\//' -i ${FILEPATH_LOG}                                             && \
                cut -d ' ' -f 4 ${FILEPATH_LOG} > ${PATHS_LOG}                                  && \
                cut -d ' ' -f 2 ${FILEPATH_LOG} | xargs -i basename {} > ${FILES_LOG}           && \
                paste -d '' ${PATHS_LOG} ${FILES_LOG}                                             |\
                xargs -i rsync -aR {} ${QIMSDK_INSTALL_DIR}/ -f"- *.h" -f"- *.pc"
    ) || {
        print-red "FAILED: qimsdk-meson-install-${TARGET}: meson install to deploy dir failed !!!"
        rm -f ${FILEPATH_LOG}
        rm -f ${PATHS_LOG}
        rm -f ${FILES_LOG}
        return -1
    }

    rm -f ${FILEPATH_LOG}
    rm -f ${PATHS_LOG}
    rm -f ${FILES_LOG}

    # Propagate symlinks to device container deploy dir
    (
        set -o pipefail

        cat ${INSTALL_LOG} | grep -E '^Installing symlink' > ${FILEPATH_LOG}
        cut -d ' ' -f 7 ${FILEPATH_LOG} | xargs -i rsync -aR {} ${QIMSDK_INSTALL_DIR}/
    ) || {
        print-red "FAILED: qimsdk-meson-install-${TARGET}: meson symlinks in deploy dir failed !!!"
        rm -f ${FILEPATH_LOG}
        return -1
    }

    rm -f ${FILEPATH_LOG}

    print-green "qimsdk ${TARGET} installed successfully !!!"

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

# Wrapper function to configure, compile & install qimsdk meson Target
#    ${1} - SOURCE_PATH - Path to top-level Meson Project Directory
#    ${2} - DESTINATION_DIR - meson destination directory
#    ${3} - MESON_CONFIG_FLAGS - meson configure flags
function qimsdk-meson-build() {
    local SOURCE_PATH=${1}
    local T=`basename ${SOURCE_PATH}`
    local DESTINATION_DIR=${2}

    shift;shift;

    local MESON_CONFIG_FLAGS=$@

    qimsdk-meson-configure ${SOURCE_PATH} ${T} ${MESON_CONFIG_FLAGS}                            && \
            qimsdk-meson-compile ${T}                                                           && \
            qimsdk-meson-install ${T} ${DESTINATION_DIR}
}

# Wrapper function to configure, compile & install qimsdk CMake Target
#    ${1} - SOURCE_PATH - Path to top-level CMake Project Directory
#    ${2} - CMAKE_CUSTOM_CONFIG_FLAGS - plugin specific flags to pass to CMake command
function qimsdk-cmake-build() {
    local SOURCE_PATH=${1}
    local T=`basename ${SOURCE_PATH}`

    shift

    local CMAKE_CUSTOM_CONFIG_FLAGS=$@

    qimsdk-cmake-configure ${SOURCE_PATH} ${T} ${CMAKE_CUSTOM_CONFIG_FLAGS}                     && \
            qimsdk-cmake-compile ${T}                                                           && \
            qimsdk-cmake-install ${T}
}

###########################################################

# Meson build gst-plugins-base-1.26.1
qimsdk-meson-build-gst-plugins-base() {
    local CONFIG_FLAGS="--prefix /usr --buildtype debug --bindir bin --sbindir sbin                \
            --datadir share --libdir lib/aarch64-linux-gnu --libexecdir libexec                    \
            --includedir include --mandir share/man --infodir share/info --sysconfdir /etc         \
            --localstatedir /var --sharedstatedir /com --wrap-mode nodownload                      \
            -Dintrospection=enabled -Dexamples=disabled -Dnls=enabled -Ddoc=disabled               \
            -Dgl_api=gles2 -Dgl_platform=egl -Dgl_winsys=egl,wayland -Dalsa=enabled                \
            -Dcdparanoia=disabled -Dgl-graphene=disabled -Dgl-jpeg=enabled -Dogg=enabled           \
            -Dopus=disabled -Dorc=enabled -Dpango=enabled -Dgl-png=enabled -Dqt5=disabled          \
            -Dtheora=enabled -Dtremor=disabled -Dlibvisual=disabled -Dvorbis=enabled               \
            -Dx11=disabled -Dxvideo=disabled -Dxshm=disabled -Dbuild-all-plugins=false"
    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.26.1 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build gst-plugins-good-1.26.1
qimsdk-meson-build-gst-plugins-good() {
    local CONFIG_FLAGS="--prefix /usr --buildtype debug --bindir bin --sbindir sbin                \
            --datadir share --libdir lib/aarch64-linux-gnu --libexecdir libexec                    \
            --includedir include --mandir share/man --infodir share/info --sysconfdir /etc         \
            --localstatedir /var --sharedstatedir /com --wrap-mode nodownload                      \
            -Dexamples=disabled -Dnls=enabled -Ddoc=disabled -Daalib=disabled                      \
            -Ddirectsound=disabled -Ddv=disabled -Dlibcaca=disabled -Doss=enabled -Doss4=disabled  \
            -Dosxaudio=disabled -Dosxvideo=disabled -Dshout2=disabled -Dtwolame=disabled           \
            -Dwaveform=disabled -Damrnb=disabled -Damrwbdec=disabled -Dasm=disabled -Dbz2=enabled  \
            -Dcairo=enabled -Ddv1394=disabled -Dflac=enabled -Dgdk-pixbuf=enabled -Dgtk3=disabled  \
            -Dv4l2-gudev=enabled -Djack=disabled -Djpeg=enabled -Dlame=enabled -Dpng=enabled       \
            -Dv4l2-libv4l2=disabled -Dmpg123=enabled -Dorc=enabled -Dpulse=enabled -Dqt5=disabled  \
            -Drpicamsrc=disabled -Dsoup=enabled -Dspeex=disabled -Dtaglib=enabled -Dv4l2=enabled   \
            -Dv4l2-probe=true -Dvpx=enabled -Dwavpack=disabled -Dximagesrc=disabled                \
            -Dximagesrc-xshm=disabled -Dximagesrc-xfixes=disabled -Dximagesrc-xdamage=disabled     \
            -Dadaptivedemux2=disabled -Dbuild-all-plugins=false"
    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.26.1 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Clean meson gst-plugins-base build directory
function qimsdk-meson-clean-gst-plugins-base() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-base-1.26.1

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson gst-plugins-good build directory
function qimsdk-meson-clean-gst-plugins-good() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-good-1.26.1

    print-green "${FUNCNAME} completed successfully!"
}

# CMake Build qcom-gstreamer1.0-plugins-oss plugin
#    ${1} - PLUGIN_DIR_NAME - Name of top-level plugin directory under gst-plugins-qti-oss
function qimsdk-cmake-build-qcom-gstreamer1.0-plugins-oss () {
    local PLUGIN_DIR_NAME="${1}"

    [ -z "${PLUGIN_DIR_NAME}" ]                                                                 && {
        print-red "QTI Plugin directory name must be provided as first argument!"
        return -1
    }

    # Extract plugin basename by removing gst-plugin- prefix
    local PLUGIN_NAME=$(echo ${PLUGIN_DIR_NAME} | sed 's/gst-plugin-//')

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/${PLUGIN_DIR_NAME}                    \
        -DGST_PLUGINS_QTI_OSS_SUMMARY='Qualcomm open-source multimedia GStreamer plugin'           \
        -DGST_PLUGINS_QTI_OSS_LICENSE=BSD                                                          \
        -DGST_PLUGINS_QTI_OSS_PACKAGE=qcom-gstreamer1.0-plugins-oss-${PLUGIN_NAME}                 \
        -DGST_PLUGINS_QTI_OSS_ORIGIN='Unknown package origin'                                   && \
            print-green "${FUNCNAME} ${PLUGIN_DIR_NAME} completed successfully!"
}

# CMake Clean qcom-gstreamer1.0-plugins-oss plugin
#    ${1} - PLUGIN_DIR_NAME - Name of top-level plugin directory under gst-plugins-qti-oss
function qimsdk-cmake-clean-qcom-gstreamer1.0-plugins-oss () {
    local PLUGIN_DIR_NAME="${1}"

    [ -z "${PLUGIN_DIR_NAME}" ]                                                                 && {
        print-red "QTI Plugin directory name must be provided as first argument!"
        return -1
    }

    rm -rf ${QIMSDK_BUILD_DIR}/${PLUGIN_DIR_NAME}                                               && \
            print-green "${FUNCNAME} ${PLUGIN_DIR_NAME} completed successfully!"
}

# Wrapper function to build all QTI gstreamer plugins incrementally
function qimsdk-incremental-build-qti() {
    local QIMSDK_BASE_QTI_PLUGINS_LIST="gst-plugin-base"
    local QIMSDK_QTI_PLUGINS_LIST="`
            `gst-plugin-batch `
            `gst-plugin-metamux `
            `gst-plugin-metatransform `
            `gst-plugin-mlaconverter `
            `gst-plugin-mlaclassification `
            `gst-plugin-mldemux `
            `gst-plugin-mlmetaparser `
            `gst-plugin-mlvconverter `
            `gst-plugin-mlvclassification `
            `gst-plugin-mlvsuperresolution `
            `gst-plugin-mlvdetection `
            `gst-plugin-mlvpose `
            `gst-plugin-mlvsegmentation `
            `gst-plugin-msgbroker `
            `gst-plugin-objtracker `
            `gst-plugin-overlay `
            `gst-plugin-redissink `
            `gst-plugin-restricted-zone `
            `gst-plugin-rtspbin `
            `gst-plugin-socket `
            `gst-plugin-vcomposer `
            `gst-plugin-videotemplate `
            `gst-plugin-voverlay `
            `gst-plugin-vsplit `
            `gst-plugin-vtransform `
            `gst-plugin-mlmetaextractor `
            `gst-plugin-mlpostprocess `
            `gst-plugin-mltflite"

    # Build Base QTI Gstreamer plugins first as the rest depend on them
    for BASE_PLUGIN in ${QIMSDK_BASE_QTI_PLUGINS_LIST[@]}; do
        qimsdk-cmake-build-qcom-gstreamer1.0-plugins-oss ${BASE_PLUGIN}
    done

    # Build remaining QTI Gstreamer plugins in paralel
    (
        trap 'kill 0' SIGINT;
        for QTI_PLUGIN in ${QIMSDK_QTI_PLUGINS_LIST[@]}; do
            qimsdk-cmake-build-qcom-gstreamer1.0-plugins-oss ${QTI_PLUGIN} || kill 0 &
        done
        wait
    )

    echo "QTI build completed !!!"
}

# Configure and build gst plugins
function qimsdk-incremental-build() {
    qimsdk-meson-build-gst-plugins-base                                                         && \
            qimsdk-meson-build-gst-plugins-good                                                 && \
            qimsdk-incremental-build-qti                                                        && \
            print-green "QIMSDK GStreamer targets built successfully !!!"
}

print-green "qimsdk-incremental-build"
echo "    Incremental build of gst plugins"
print-green "qimsdk-incremental-build-qti"
echo "    Incremental build of all QTI gst plugins"
print-yellow "qimsdk-cmake-build-qcom-gstreamer1.0-plugins-oss \${QTI_PLUGIN_DIR_NAME}"
echo "    CMake build of a QTI gst plugin. Plugin directory name under gst-plugins-qti-oss `
            `must be provided as first argument"
print-red "qimsdk-cmake-clean-qcom-gstreamer1.0-plugins-oss \${QTI_PLUGIN_DIR_NAME}"
echo "    Clean QTI gst plugin build dir. Plugin directory name under gst-plugins-qti-oss `
            `must be provided as first argument"
