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
        print-yellow "No such source: ${SOURCE_PATH}"
        print-yellow "Configuration will be skipped !"

        return 0
    }

    shift;shift

    local CMAKE_CUSTOM_CONFIG_FLAGS=$@

    (
        local CMAKE_FLAGS="
            -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON
            -DGST_PLUGINS_QTI_OSS_VERSION=1.20
            -DGST_VERSION_REQUIRED=1.20
            -DSYSROOT_INCDIR=/usr/include
            -DSYSROOT_LIBDIR=/usr/lib
            -DGST_PLUGINS_QTI_OSS_INSTALL_INCDIR=/usr/include
            -DGST_PLUGINS_QTI_OSS_INSTALL_BINDIR=/usr/bin
            -DGST_PLUGINS_QTI_OSS_INSTALL_LIBDIR=/usr/lib/aarch64-linux-gnu
            ${CMAKE_CUSTOM_CONFIG_FLAGS}
        "

        mkdir -p ${QIMSDK_BUILD_DIR}/${TARGET}

        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        cmake ${CMAKE_FLAGS} ${SOURCE_PATH}                                                       |&
                tee "${QIMSDK_LOGS_DIR}/do_configure_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"
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
        print-yellow "No such build dir: ${QIMSDK_BUILD_DIR}/${TARGET}"
        print-yellow "Compilation will be skipped !"

        return 0
    }

    (
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        cmake --build .                                                                           |&
                tee "${QIMSDK_LOGS_DIR}/do_compile_${TARGET}_$(date "+%Y_%m_%d-%H_%M_%S").log"
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
    (
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        meson install --destdir ${DESTINATION} --strip                                            |&
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

    [ ! -d ${QIMSDK_BUILD_DIR}/${TARGET} ]                                                      && {
        print-yellow "No such build dir: ${QIMSDK_BUILD_DIR}/${TARGET}"
        print-yellow "Installation will be skipped !"

        return 0
    }

    (
        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        cmake --install . --prefix /usr --strip                                                   |&
                tee ${LOG_FILE_NAME}                                                              |\
                grep -E 'Up-to-date:|Installing:|configuration:' | tail -n +2                     |\
                cut -d ' ' -f 3 | xargs -i rsync -aR {} ${QIMSDK_INSTALL_DIR}/
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

# CMake Build gst-ml-metadata
function qimsdk-cmake-build-gst-ml-metadata() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_ml_metadata'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlmeta"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-ml-metadata ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-base
function qimsdk-cmake-build-gst-plugin-base() {
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-base
}

# CMake Build gst-plugin-metatransform
function qimsdk-cmake-build-gst-plugin-metatransform() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_metatransform'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-metatransform"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-metatransform ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-batch
function qimsdk-cmake-build-gst-plugin-batch() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_batch'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-batch"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-batch ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-metamux
function qimsdk-cmake-build-gst-plugin-metamux() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_metamux'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-metamux"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-metamux ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mldemux
function qimsdk-cmake-build-gst-plugin-mldemux() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mldemux'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mldemux"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mldemux ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mlvclassification
function qimsdk-cmake-build-gst-plugin-mlvclassification() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mlvclassification'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlvclassification"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mlvclassification ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mlvconverter
function qimsdk-cmake-build-gst-plugin-mlvconverter() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mlvconverter'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlvconverter"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mlvconverter ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mlvdetection
function qimsdk-cmake-build-gst-plugin-mlvdetection() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mlvdetection'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlvdetection"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mlvdetection ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mlvsuperresolution
function qimsdk-cmake-build-gst-plugin-mlvsuperresolution() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mlvsuperresolution'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlvsuperresolution"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mlvsuperresolution ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mlvpose
function qimsdk-cmake-build-gst-plugin-mlvpose() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mlvpose'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlvpose"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mlvpose ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mlvsegmentation
function qimsdk-cmake-build-gst-plugin-mlvsegmentation() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mlvsegmentation'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlvsegmentation"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mlvsegmentation ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mlsnpe
function qimsdk-cmake-build-gst-plugin-mlsnpe() {
    [ -f "${QIMSDK_BASE_DIR}/no-qnp-sdk-provided" ] && {
            return 0
    } || {
        local RECIPE_FLAGS=$(
            cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mlsnpe'
        )

        local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlsnpe"

        qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mlsnpe ${CONFIG_FLAGS}
    }
}

# CMake Build gst-plugin-mltflite
function qimsdk-cmake-build-gst-plugin-mltflite() {
    local RECIPE_FLAGS=$(
        cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mltflite'
    )

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mltflite"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mltflite ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mlqnn
function qimsdk-cmake-build-gst-plugin-mlqnn() {
    [ -f "${QIMSDK_BASE_DIR}/no-qnp-sdk-provided" ] && {
        return 0
    } || {
        local RECIPE_FLAGS=$(
            cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mlqnn'
        )

        local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlqnn"

        qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mlqnn ${CONFIG_FLAGS}
    }
}

# CMake Build gst-plugin-socket
function qimsdk-cmake-build-gst-plugin-socket() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_socket')

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-socket"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-socket ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-tools
function qimsdk-cmake-build-gst-plugin-tools() {
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-tools
}

# CMake Build gst-plugin-vcomposer
function qimsdk-cmake-build-gst-plugin-vcomposer() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_vcomposer')

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-vcomposer"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-vcomposer ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-vsplit
function qimsdk-cmake-build-gst-plugin-vsplit() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_vsplit')

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-vsplit"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-vsplit ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-vtransform
function qimsdk-cmake-build-gst-plugin-vtransform() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_vtransform')

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-vtransform"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-vtransform ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-redissink
function qimsdk-cmake-build-gst-plugin-redissink() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_redissink')

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-redissink"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-redissink ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-mlmetaparser
function qimsdk-cmake-build-gst-plugin-mlmetaparser() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_mlmetaparser')

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-mlmetaparser"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-mlmetaparser ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-rtspbin
function qimsdk-cmake-build-gst-plugin-rtspbin() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_rtspbin')

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-rtspbin"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-rtspbin ${CONFIG_FLAGS}
}

# CMake Build gst-sample-apps
function qimsdk-cmake-build-gst-sample-apps() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_sample_apps')

    # QMMF is not yet decoupled, that is why camera is disabled in the sample apps
    local CONFIG_FLAGS="${RECIPE_FLAGS} -DENABLE_CAMERA=FALSE"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-sample-apps ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-overlay
function qimsdk-cmake-build-gst-plugin-overlay() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_overlay')

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-overlay"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-overlay ${CONFIG_FLAGS}
}

# CMake Build gst-plugin-voverlay
function qimsdk-cmake-build-gst-plugin-voverlay() {
    local RECIPE_FLAGS=$(cat ${QIMSDK_CMAKE_FLAGS_JSON} | jq '.gst_plugin_voverlay')

    local CONFIG_FLAGS="${RECIPE_FLAGS} -DGST_PLUGINS_QTI_OSS_PACKAGE=gstreamer1.0-plugins-qcom-oss-voverlay"

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/gst-plugin-voverlay ${CONFIG_FLAGS}
}

# Clean meson wayland-protocols build directory
function qimsdk-meson-clean-wayland-protocols() {
    rm -rf ${QIMSDK_BUILD_DIR}/wayland-protocols-1.25

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean meson gst-plugins-good build directory
function qimsdk-meson-clean-gst-plugins-good() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-good-1.20.7

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean meson gst-plugins-bad build directory
function qimsdk-meson-clean-gst-plugins-bad() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-bad-1.20.7

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean meson gstd build directory
function qimsdk-meson-clean-gstd() {
    rm -rf ${QIMSDK_BUILD_DIR}/gstd-1.x

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-ml-metadata build directory
function qimsdk-cmake-clean-gst-ml-metadata() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-ml-metadata

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-base build directory
function qimsdk-cmake-clean-gst-plugin-base() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-base

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-metatransform build directory
function qimsdk-cmake-clean-gst-plugin-metatransform() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-metatransform

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-batch build directory
function qimsdk-cmake-clean-gst-plugin-batch() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-batch

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-metamux build directory
function qimsdk-cmake-clean-gst-plugin-metamux() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-metamux

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mldemux build directory
function qimsdk-cmake-clean-gst-plugin-mldemux() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mldemux

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mlvclassification build directory
function qimsdk-cmake-clean-gst-plugin-mlvclassification() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mlvclassification

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mlvconverter build directory
function qimsdk-cmake-clean-gst-plugin-mlvconverter() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mlvconverter

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mlvdetection build directory
function qimsdk-cmake-clean-gst-plugin-mlvdetection() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mlvdetection

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mlvsuperresolution build directory
function qimsdk-cmake-clean-gst-plugin-mlvsuperresolution() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mlvsuperresolution

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mlvpose build directory
function qimsdk-cmake-clean-gst-plugin-mlvpose() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mlvpose

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mlvsegmentation build directory
function qimsdk-cmake-clean-gst-plugin-mlvsegmentation() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mlvsegmentation

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mlsnpe build directory
function qimsdk-cmake-clean-gst-plugin-mlsnpe() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mlsnpe

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mltflite build directory
function qimsdk-cmake-clean-gst-plugin-mltflite() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mltflite

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mlqnn build directory
function qimsdk-cmake-clean-gst-plugin-mlqnn() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mlqnn

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-socket build directory
function qimsdk-cmake-clean-gst-plugin-socket() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-socket

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-tools build directory
function qimsdk-cmake-clean-gst-plugin-tools() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-tools

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-vcomposer build directory
function qimsdk-cmake-clean-gst-plugin-vcomposer() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-vcomposer

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-vsplit build directory
function qimsdk-cmake-clean-gst-plugin-vsplit() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-vsplit

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-vtransform build directory
function qimsdk-cmake-clean-gst-plugin-vtransform() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-vtransform

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-redissink build directory
function qimsdk-cmake-clean-gst-plugin-redissink() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-redissink

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-mlmetaparser build directory
function qimsdk-cmake-clean-gst-plugin-mlmetaparser() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-mlmetaparser

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-rtspbin build directory
function qimsdk-cmake-clean-gst-plugin-rtspbin() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-rtspbin

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-sample-apps build directory
function qimsdk-cmake-clean-gst-sample-apps() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-sample-apps

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-overlay build directory
function qimsdk-cmake-clean-gst-plugin-overlay() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-overlay

    print-green "${FUNCNAME} completed succesfully!"
}

# Clean CMake gst-plugin-voverlay build directory
function qimsdk-cmake-clean-gst-plugin-voverlay() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugin-voverlay

    print-green "${FUNCNAME} completed succesfully!"
}

# Configure and build gst plugins
function qimsdk-incremental-build() {
    qimsdk-meson-build-gstd                                                                     && \
            qimsdk-meson-build-wayland-protocols                                                && \
            qimsdk-meson-build-gst-plugins-good                                                 && \
            qimsdk-meson-build-gst-plugins-bad                                                  && \
            qimsdk-cmake-build-gst-ml-metadata                                                  && \
            qimsdk-cmake-build-gst-plugin-base                                                  && \
            qimsdk-cmake-build-gst-plugin-metatransform                                         && \
            qimsdk-cmake-build-gst-plugin-batch                                                 && \
            qimsdk-cmake-build-gst-plugin-metamux                                               && \
            qimsdk-cmake-build-gst-plugin-mldemux                                               && \
            qimsdk-cmake-build-gst-plugin-mlvclassification                                     && \
            qimsdk-cmake-build-gst-plugin-mlvconverter                                          && \
            qimsdk-cmake-build-gst-plugin-mlvdetection                                          && \
            qimsdk-cmake-build-gst-plugin-mlvsuperresolution                                    && \
            qimsdk-cmake-build-gst-plugin-mlvpose                                               && \
            qimsdk-cmake-build-gst-plugin-mlvsegmentation                                       && \
            qimsdk-cmake-build-gst-plugin-mlsnpe                                                && \
            qimsdk-cmake-build-gst-plugin-mltflite                                              && \
            qimsdk-cmake-build-gst-plugin-mlqnn                                                 && \
            qimsdk-cmake-build-gst-plugin-socket                                                && \
            qimsdk-cmake-build-gst-plugin-tools                                                 && \
            qimsdk-cmake-build-gst-plugin-vcomposer                                             && \
            qimsdk-cmake-build-gst-plugin-vsplit                                                && \
            qimsdk-cmake-build-gst-plugin-vtransform                                            && \
            qimsdk-cmake-build-gst-plugin-redissink                                             && \
            qimsdk-cmake-build-gst-plugin-mlmetaparser                                          && \
            qimsdk-cmake-build-gst-plugin-rtspbin                                               && \
            qimsdk-cmake-build-gst-plugin-overlay                                               && \
            qimsdk-cmake-build-gst-plugin-voverlay                                              && \
            qimsdk-cmake-build-gst-sample-apps                                                  && \
            print-green "QIMSDK GStreamer targets built successfully !!!"
}

print-green "qimsdk-incremental-build"
echo "    Incremental build of gst plugins"
