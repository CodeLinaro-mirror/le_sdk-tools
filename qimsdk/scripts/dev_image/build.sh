#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
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
        local CMAKE_FLAGS="
            -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON
            -DENABLE_RUNTIME_PARSER:BOOL=ON
            -DGST_PLUGINS_QTI_OSS_VERSION=1.20
            -DGST_VERSION_REQUIRED=1.20
            -DSYSROOT_INCDIR=/usr/include
            -DSYSROOT_LIBDIR=/usr/lib
            -DGST_PLUGINS_QTI_OSS_INSTALL_INCDIR=/usr/include
            -DGST_PLUGINS_QTI_OSS_INSTALL_BINDIR=/usr/bin
            -DGST_PLUGINS_QTI_OSS_INSTALL_LIBDIR=/usr/lib/aarch64-linux-gnu
            -DCMAKE_BUILD_TYPE=Debug
            ${CMAKE_CUSTOM_CONFIG_FLAGS}
        "

        mkdir -p ${QIMSDK_BUILD_DIR}/${TARGET}

        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        cmake ${CMAKE_FLAGS} ${SOURCE_PATH}                                                       |&
                tee "${QIMSDK_LOGS_DIR}/do_configure_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"
    ) || {
        print-red "FAILED: qimsdk-cmake-configure-${TARGET}: cmake configure failed !!!"
        return -2
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

        meson compile                                                                             |&
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
                tee "${QIMSDK_LOGS_DIR}/do_compile_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"
    ) || {
        print-red "FAILED: qimsdk-cmake-compile-${TARGET}: cmake compile failed !!!"
        return -2
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
    (
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        meson install --destdir ${QIMSDK_INSTALL_DEBUG_DIR}                                       |&
                tee "${QIMSDK_LOGS_DIR}/meson_install_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S")`
                `_dbg.log"                                                                      && \
        meson install --destdir ${DESTINATION} --strip                                            |&
                tee "${QIMSDK_LOGS_DIR}/meson_install_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"  \
                                                                                                && \
        meson install --destdir "/" --strip                                                       |&
                tee "${QIMSDK_LOGS_DIR}/meson_install_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"
    ) || {
        print-red "FAILED: qimsdk-meson-install-${TARGET}: meson install failed !!!"
        return -1
    }

    print-green "qimsdk ${TARGET} installed successfully !!!"

    return 0
}

# Install qimsdk CMake Target
#    ${1} - TARGET - CMake Target
function qimsdk-cmake-install() {
    local TARGET=${1}

    local DATE=$(date "+%Y_%m_%d-%H_%M_%S")
    local LOG_FILE_NAME=${QIMSDK_LOGS_DIR}/do_install_${TARGET}_${DATE}.log
    local LOG_FILE_NAME_DBG=${QIMSDK_LOGS_DIR}/do_install_${TARGET}_dbg_${DATE}.log

    [ ! -d ${QIMSDK_BUILD_DIR}/${TARGET} ]                                                      && {
        print-red "No such build dir: ${QIMSDK_BUILD_DIR}/${TARGET}"
        print-red "Installation will be skipped !"

        return -1
    }

    (
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail


        cmake --install . --prefix ${QIMSDK_INSTALL_DEBUG_DIR}                                    |&
                tee ${LOG_FILE_NAME_DBG}                                                        && \
        cmake --install . --prefix /usr --strip                                                   |&
                tee ${LOG_FILE_NAME}                                                              |\
                grep -E 'Up-to-date:|Installing:|configuration:' | tail -n +2                     |\
                cut -d ' ' -f 3 | xargs -i rsync -aR {} ${QIMSDK_INSTALL_DIR}/
    ) || {
        print-red "FAILED: qimsdk-cmake-install-${TARGET}: cmake install failed !!!"
        return -2
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

# Meson build wayland-protocols-1.25
qimsdk-meson-build-wayland-protocols() {
    local CONFIG_FLAGS="--prefix /usr --buildtype debug --bindir bin --sbindir sbin                \
            --datadir share --libdir lib/aarch64-linux-gnu --libexecdir libexec                    \
            --includedir include --mandir share/man --infodir share/info --sysconfdir /etc         \
            --localstatedir /var --sharedstatedir /com --wrap-mode nodownload -Dtests=false"
    local DESTINATION_DIR='/'

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build gstd
qimsdk-meson-build-gstd() {
    local CONFIG_FLAGS="--prefix /usr --libdir lib/aarch64-linux-gnu -D with-gstd-logstatedir=/var/log/gstd/"
    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gstd-1.x ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build pulseaudio
qimsdk-meson-build-pulseaudio() {
    local CONFIG_FLAGS="--prefix /usr --buildtype debug --bindir bin --sbindir sbin                \
            --datadir share --libdir lib/aarch64-linux-gnu --libexecdir libexec                    \
            --includedir include --mandir share/man --infodir share/info --sysconfdir /etc         \
            --localstatedir /var --sharedstatedir /com --wrap-mode nodownload                      \
            -Dhal-compat=false                                                                     \
            -Dorc=disabled                                                                         \
            -Daccess_group=audio                                                                   \
            -Dopenssl=disabled                                                                     \
            -Ddatabase=simple                                                                      \
            -Dzshcompletiondir=no                                                                  \
            -Dudevrulesdir=`pkg-config --variable=udevdir udev`/rules.d                            \
            -Dvalgrind=disabled                                                                    \
            -Dtests=false                                                                          \
            -Drunning-from-build-tree=false"

    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-15.0 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build gst-plugins-good-1.20.7
qimsdk-meson-build-gst-plugins-good() {
    local CONFIG_FLAGS="--prefix /usr --buildtype debug --bindir bin --sbindir sbin                \
            --datadir share --libdir lib/aarch64-linux-gnu --libexecdir libexec                    \
            --includedir include --mandir share/man --infodir share/info --sysconfdir /etc         \
            --localstatedir /var --sharedstatedir /com --wrap-mode nodownload                      \
            -Dexamples=disabled -Dnls=enabled -Ddoc=disabled -Daalib=disabled                      \
            -Ddirectsound=disabled -Ddv=disabled -Dlibcaca=disabled -Doss=enabled                  \
            -Doss4=disabled -Dosxaudio=disabled -Dosxvideo=disabled -Dshout2=disabled              \
            -Dtwolame=disabled -Dwaveform=disabled -Dasm=disabled -Dbz2=enabled                    \
            -Dcairo=enabled -Ddv1394=disabled -Dflac=enabled -Dgdk-pixbuf=enabled                  \
            -Dgtk3=disabled -Dv4l2-gudev=enabled -Djack=disabled -Djpeg=enabled -Dlame=enabled     \
            -Dpng=enabled -Dv4l2-libv4l2=disabled -Dmpg123=enabled -Dorc=enabled                   \
            -Dpulse=enabled -Dqt5=disabled -Drpicamsrc=disabled -Dsoup=enabled -Dspeex=enabled     \
            -Dtaglib=enabled -Dv4l2=enabled -Dv4l2-probe=true -Dvpx=disabled                       \
            -Dwavpack=disabled -Dximagesrc=disabled -Dximagesrc-xshm=disabled                      \
            -Dximagesrc-xfixes=disabled -Dximagesrc-xdamage=disabled -Dbuild_all_plugins=false"
    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build gst-plugins-bad-1.20.7
qimsdk-meson-build-gst-plugins-bad() {
    local CONFIG_FLAGS="--prefix /usr --buildtype debug --bindir bin --sbindir sbin                \
            --datadir share --libdir lib/aarch64-linux-gnu --libexecdir libexec                    \
            --includedir include --mandir share/man --infodir share/info --sysconfdir /etc         \
            --localstatedir /var --sharedstatedir /com --wrap-mode nodownload                      \
            -Dintrospection=enabled -Dexamples=disabled -Dnls=disabled -Dgpl=disabled              \
            -Ddoc=disabled -Daes=enabled -Dcodecalpha=enabled -Ddecklink=enabled -Ddvb=enabled     \
            -Dfbdev=enabled -Dipcpipeline=enabled -Dshm=enabled -Dtranscode=enabled                \
            -Dandroidmedia=disabled -Dapplemedia=disabled -Dasio=disabled -Davtp=disabled          \
            -Dbs2b=disabled -Dchromaprint=disabled -Dd3dvideosink=disabled -Dd3d11=disabled        \
            -Ddirectsound=disabled -Ddts=disabled -Dfdkaac=disabled -Dflite=disabled               \
            -Dgme=disabled -Dgs=disabled -Dgsm=disabled -Diqa=disabled -Dkate=disabled             \
            -Dladspa=disabled -Dldac=disabled -Dlv2=disabled -Dmagicleap=disabled                  \
            -Dmediafoundation=disabled -Dmicrodns=disabled -Dmpeg2enc=disabled                     \
            -Dmplex=disabled -Dmusepack=disabled -Dnvcodec=disabled -Dopenexr=disabled             \
            -Dopenni2=disabled -Dopenaptx=disabled -Dopensles=disabled -Donnx=disabled             \
            -Dqroverlay=disabled -Dsoundtouch=disabled -Dspandsp=disabled                          \
            -Dsvthevcenc=disabled -Dteletext=disabled -Dwasapi=disabled -Dwasapi2=disabled         \
            -Dwildmidi=disabled -Dwinks=disabled -Dwinscreencap=disabled -Dwpe=disabled            \
            -Dzxing=disabled -Daom=disabled -Dassrender=disabled -Dbluez=enabled -Dbz2=enabled     \
            -Dclosedcaption=enabled -Dcurl=enabled -Ddash=enabled -Ddc1394=disabled                \
            -Ddirectfb=disabled -Ddtls=enabled -Dfaac=disabled -Dfaad=disabled                     \
            -Dfluidsynth=disabled -Dgl=enabled -Dhls=enabled -Dkms=disabled                        \
            -Dcolormanagement=disabled -Dlibde265=disabled -Dcurl-ssh2=disabled                    \
            -Dmodplug=disabled -Dmsdk=disabled -Dneon=disabled -Dopenal=disabled                   \
            -Dopencv=disabled -Dopenh264=disabled -Dopenjpeg=disabled -Dopenmpt=disabled           \
            -Dhls-crypto=openssl -Dopus=disabled -Dorc=enabled -Dresindvd=disabled                 \
            -Drsvg=enabled -Drtmp=disabled -Dsbc=enabled -Dsctp=disabled                           \
            -Dsmoothstreaming=enabled -Dsndfile=enabled -Dsrt=disabled -Dsrtp=disabled             \
            -Dtinyalsa=disabled -Dttml=enabled -Duvch264=enabled -Dv4l2codecs=disabled             \
            -Dva=disabled -Dvoaacenc=disabled -Dvoamrwbenc=disabled -Dvulkan=enabled               \
            -Dwayland=enabled -Dwebp=enabled -Dwebrtc=disabled -Dwebrtcdsp=disabled                \
            -Dx11=disabled -Dx265=disabled -Dzbar=disabled -Dbuild_all_plugins=false"
    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# CMake Build le-services
function qimsdk-cmake-build-le-services () {
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/le-services -DTARGET_BOARD_PLATFORM=qimsdk && \
            print-green "${FUNCNAME} completed successfully!"
}

# Clean meson wayland-protocols build directory
function qimsdk-meson-clean-wayland-protocols() {
    rm -rf ${QIMSDK_BUILD_DIR}/wayland-protocols-1.25

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson gst-plugins-good build directory
function qimsdk-meson-clean-gst-plugins-good() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-good-1.20.7

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson gst-plugins-bad build directory
function qimsdk-meson-clean-gst-plugins-bad() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-bad-1.20.7

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson gstd build directory
function qimsdk-meson-clean-gstd() {
    rm -rf ${QIMSDK_BUILD_DIR}/gstd-1.x

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson pulseaudio build directory
function qimsdk-meson-clean-pulseaudio() {
    rm -rf ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-15.0

    print-green "${FUNCNAME} completed successfully!"
}

# Clean CMake le-services build directory
function qimsdk-cmake-clean-le-services() {
    rm -rf ${QIMSDK_BUILD_DIR}/le-services

    print-green "${FUNCNAME} completed successfully!"
}

# Configure and build gst plugins
function qimsdk-incremental-build() {
    qimsdk-meson-build-gstd                                                                     && \
            qimsdk-meson-build-pulseaudio                                                       && \
            qimsdk-meson-build-wayland-protocols                                                && \
            qimsdk-meson-build-gst-plugins-good                                                 && \
            qimsdk-meson-build-gst-plugins-bad                                                  && \
            qimsdk-cmake-build-le-services                                                      && \
            qimsdk-incremental-build-qti                                                        && \
            print-green "QIMSDK GStreamer targets built successfully !!!"
}

print-green "qimsdk-incremental-build"
echo "    Incremental build of gst plugins"
