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
        qimsdk-setup-crosscompilation
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
        qimsdk-setup-crosscompilation
        local CMAKE_FLAGS="
            -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON
            -DSYSROOT_INCDIR=/usr/include
            -DSYSROOT_LIBDIR=/usr/lib
            -DCMAKE_INSTALL_PREFIX=/usr
            -DCMAKE_INSTALL_INCLUDEDIR=include
            -DCMAKE_INSTALL_BINDIR=bin
            -DCMAKE_INSTALL_LIBDIR=lib/aarch64-linux-gnu
            -DCMAKE_INSTALL_SYSCONFDIR=/etc
            -DCMAKE_BUILD_TYPE=Debug
            ${CMAKE_CUSTOM_CONFIG_FLAGS}
        "

        mkdir -p ${QIMSDK_BUILD_DIR}/${TARGET}

        cd ${QIMSDK_BUILD_DIR}/${TARGET}

        set -o pipefail

        cmake ${CMAKE_FLAGS} ${SOURCE_PATH}                                                       |&
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
        qimsdk-setup-crosscompilation
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
        qimsdk-setup-crosscompilation
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
        qimsdk-setup-crosscompilation
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
        qimsdk-setup-crosscompilation
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
        qimsdk-setup-crosscompilation
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
        qimsdk-setup-crosscompilation
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
    local T=$(qimsdk-get-project ${SOURCE_PATH})
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
    local T=$(qimsdk-get-project ${SOURCE_PATH})

    shift

    local CMAKE_CUSTOM_CONFIG_FLAGS=$@

    qimsdk-cmake-configure ${SOURCE_PATH} ${T} ${CMAKE_CUSTOM_CONFIG_FLAGS}                     && \
            qimsdk-cmake-compile ${T}                                                           && \
            qimsdk-cmake-install ${T}
}

###########################################################

# Meson build wayland-protocols-1.33
qimsdk-meson-build-wayland-protocols() {
    local CONFIG_FLAGS="--prefix /usr --buildtype debug --bindir bin --sbindir sbin                \
            --datadir share --libdir lib/aarch64-linux-gnu --libexecdir libexec                    \
            --includedir include --mandir share/man --infodir share/info --sysconfdir /etc         \
            --localstatedir /var --sharedstatedir /com --wrap-mode nodownload -Dtests=false"
    local DESTINATION_DIR='/'

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build gstreamer1.0
qimsdk-meson-build-gstreamer() {
    local CONFIG_FLAGS="--prefix /usr --buildtype debug --bindir bin --sbindir sbin                \
            --datadir share --libdir lib/aarch64-linux-gnu --libexecdir libexec                    \
            --includedir include --mandir share/man --infodir share/info --sysconfdir /etc         \
            --localstatedir /var --sharedstatedir /com --wrap-mode nodownload                      \
            -Dintrospection=enabled -Ddoc=disabled -Dexamples=disabled -Ddbghelp=disabled          \
            -Dnls=enabled -Dbash-completion=disabled -Dcheck=enabled -Dcoretracers=disabled        \
            -Dgst_debug=true -Dlibdw=disabled -Dtests=enabled -Dtools=enabled                      \
            -Dtracer_hooks=false -Dlibunwind=disabled -Dbuild-all-plugins=false"
    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build gst-plugins-base-1.24.2
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

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build gst-plugins-good-1.24.2
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

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2 ${DESTINATION_DIR} ${CONFIG_FLAGS}
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
            -Ddoxygen=false                                                                        \
            -Drunning-from-build-tree=false"

    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build gst-plugins-bad-1.24.2
qimsdk-meson-build-gst-plugins-bad() {
    local CONFIG_FLAGS="--prefix /usr --buildtype debug --bindir bin --sbindir sbin                \
            --datadir share --libdir lib/aarch64-linux-gnu --libexecdir libexec                    \
            --includedir include --mandir share/man --infodir share/info --sysconfdir /etc         \
            --localstatedir /var --sharedstatedir /com --wrap-mode nodownload                      \
            -Dintrospection=enabled -Dexamples=disabled -Dnls=enabled -Dgpl=disabled               \
            -Ddoc=disabled -Daes=enabled -Dcodecalpha=enabled -Ddecklink=enabled -Ddvb=enabled     \
            -Dfbdev=enabled -Dipcpipeline=enabled -Dshm=enabled -Dtranscode=enabled                \
            -Dandroidmedia=disabled -Dapplemedia=disabled -Dasio=disabled -Dbs2b=disabled          \
            -Dchromaprint=disabled -Dd3dvideosink=disabled -Dd3d11=disabled -Ddirectsound=disabled \
            -Ddts=disabled -Dfdkaac=disabled -Dflite=disabled -Dgme=disabled -Dgs=disabled         \
            -Dgsm=disabled -Diqa=disabled -Dladspa=disabled -Dldac=disabled -Dlv2=disabled         \
            -Dmagicleap=disabled -Dmediafoundation=disabled -Dmicrodns=disabled                    \
            -Dmpeg2enc=disabled -Dmplex=disabled -Dmusepack=disabled -Dnvcodec=disabled            \
            -Dopenexr=disabled -Dopenni2=disabled -Dopenaptx=disabled -Dopensles=disabled          \
            -Donnx=disabled -Dqroverlay=disabled -Dsoundtouch=disabled -Dspandsp=disabled          \
            -Dsvthevcenc=disabled -Dteletext=disabled -Dwasapi=disabled -Dwasapi2=disabled         \
            -Dwildmidi=disabled -Dwinks=disabled -Dwinscreencap=disabled -Dwpe=disabled            \
            -Dzxing=disabled -Daom=disabled -Dassrender=disabled -Davtp=disabled -Dbluez=enabled   \
            -Dbz2=enabled -Dclosedcaption=enabled -Dcurl=enabled -Ddash=enabled -Ddc1394=disabled  \
            -Ddirectfb=disabled -Ddtls=enabled -Dfaac=disabled -Dfaad=disabled                     \
            -Dfluidsynth=disabled -Dgl=enabled -Dhls=enabled -Dkms=disabled                        \
            -Dcolormanagement=disabled -Dlibde265=disabled -Dcurl-ssh2=disabled -Dmodplug=disabled \
            -Dmsdk=disabled -Dneon=disabled -Dopenal=disabled -Dopencv=disabled                    \
            -Dopenh264=disabled -Dopenjpeg=disabled -Dopenmpt=disabled -Dhls-crypto=openssl        \
            -Dopus=disabled -Dorc=enabled -Dresindvd=disabled -Drsvg=enabled -Drtmp=disabled       \
            -Dsbc=enabled -Dsctp=enabled -Dsmoothstreaming=enabled -Dsndfile=enabled -Dsrt=enabled \
            -Dsrtp=enabled -Dtinyalsa=disabled -Dttml=enabled -Duvch264=enabled                    \
            -Dv4l2codecs=disabled -Dva=disabled -Dvoaacenc=disabled -Dvoamrwbenc=disabled          \
            -Dvulkan=enabled -Dwayland=enabled -Dwebp=enabled -Dwebrtc=enabled                     \
            -Dwebrtcdsp=disabled -Dx11=disabled -Dx265=disabled -Dzbar=disabled                    \
            -Dbuild-all-plugins=false"
    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2 ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# Meson build gstd
qimsdk-meson-build-gstd() {
    local CONFIG_FLAGS="--prefix /usr --libdir lib/aarch64-linux-gnu -D with-gstd-logstatedir=/var/log/gstd/"
    local DESTINATION_DIR=${QIMSDK_INSTALL_DIR}

    qimsdk-meson-build ${QIMSDK_DOWNLOAD_DIR}/gstd-1.x ${DESTINATION_DIR} ${CONFIG_FLAGS}
}

# CMake Build le-services
function qimsdk-cmake-build-le-services () {
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/le-services -DBUILD_CATEGORY=CLIENT                    && \
            print-green "${FUNCNAME} completed successfully!"
}

# CMake Build solutions-microservices
function qimsdk-cmake-build-solutions-microservices () {
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/solutions-microservices && \
            print-green "${FUNCNAME} completed successfully!"
}

# Clean meson wayland-protocols build directory
function qimsdk-meson-clean-wayland-protocols() {
    rm -rf ${QIMSDK_BUILD_DIR}/wayland-protocols-1.33

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson gstreamer1.0 build directory
function qimsdk-meson-clean-gstreamer() {
    rm -rf ${QIMSDK_BUILD_DIR}/gstreamer-1.24.2

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson gst-plugins-base build directory
function qimsdk-meson-clean-gst-plugins-base() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-base-1.24.2

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson gst-plugins-good build directory
function qimsdk-meson-clean-gst-plugins-good() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-good-1.24.2

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson gst-plugins-bad build directory
function qimsdk-meson-clean-gst-plugins-bad() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-bad-1.24.2

    print-green "${FUNCNAME} completed successfully!"
}

# Clean meson gstd build directory
function qimsdk-meson-clean-gstd() {
    rm -rf ${QIMSDK_BUILD_DIR}/gstd-1.x

    print-green "${FUNCNAME} completed successfully!"
}

# Clean CMake le-services build directory
function qimsdk-cmake-clean-le-services() {
    rm -rf ${QIMSDK_BUILD_DIR}/le-services

    print-green "${FUNCNAME} completed successfully!"
}

# Clean CMake solutions-microservices build directory
function qimsdk-cmake-clean-solutions-microservices() {
    rm -rf ${QIMSDK_BUILD_DIR}/solutions-microservices

    print-green "${FUNCNAME} completed successfully!"
}

# Configure and build gst plugins
function qimsdk-incremental-build-qti() {

    # Get the runtime flags generated from RecipeParser.py
    local RECIPE_PARSED_FLAGS_ARRAY=(
        $(cat ${QIMSDK_TMP_DIR}/runtime_flags.json                                               | \
                jq .[] | jq -r 'to_entries[] | "\(.key)=\(.value)"')
    )

    local RECIPE_PARSED_FLAGS="${RECIPE_PARSED_FLAGS_ARRAY[@]}"

    # Build the plugins base in a separate directory to ensure usage of the installed headers
    #   located in /usr/include during the plugin build process.
    # In Yocto, the plugins base is also built first as a separate recipe.

    # Sync code in new repo for base
    mkdir -p ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss-base                                         && \
        rsync -aP ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss/*                                          \
                ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss-base/                                     && \

    # Build only qti plugins base
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss-base /usr                             \
            -DENABLE_GST_PLUGIN_BASE=ON                                                         && \

    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss                                       \
            -DENABLE_GST_PLUGIN_BASE=ON                                                            \
            -DENABLE_GST_PLUGIN_QMMFSRC=ON                                                         \
            -DENABLE_GST_PLUGIN_VCOMPOSER=ON                                                       \
            -DENABLE_GST_PLUGIN_BATCH=ON                                                           \
            -DENABLE_GST_PLUGIN_METAMUX=ON                                                         \
            -DENABLE_GST_PLUGIN_SOCKET=ON                                                          \
            -DENABLE_GST_PLUGIN_VSPLIT=ON                                                          \
            -DENABLE_GST_PLUGIN_VTRANSFORM=ON                                                      \
            -DENABLE_GST_PLUGIN_VOVERLAY=ON                                                        \
            -DENABLE_GST_PLUGIN_RESTRICTED_ZONE=ON                                                 \
            -DENABLE_GST_PLUGIN_RTSPBIN=ON                                                         \
            -DENABLE_GST_PLUGIN_REDISSINK=ON                                                       \
            -DENABLE_GST_PLUGIN_SMARTVENCBIN=ON                                                    \
            -DENABLE_GST_PLUGIN_VIDEOTEMPLATE=ON                                                   \
            -DENABLE_GST_PLUGIN_MLACONVERTER=ON                                                    \
            -DENABLE_GST_PLUGIN_MLACLASSIFICATION=ON                                               \
            -DENABLE_GST_PLUGIN_MLDEMUX=ON                                                         \
            -DENABLE_GST_PLUGIN_MLVCONVERTER=ON                                                    \
            -DENABLE_GST_PLUGIN_MLVCLASSIFICATION=ON                                               \
            -DENABLE_GST_PLUGIN_MLVSUPERRESOLUTION=ON                                              \
            -DENABLE_GST_PLUGIN_MLVDETECTION=ON                                                    \
            -DENABLE_GST_PLUGIN_MLVPOSE=ON                                                         \
            -DENABLE_GST_PLUGIN_MLVSEGMENTATION=ON                                                 \
            -DENABLE_GST_PLUGIN_MLTOOLS=ON                                                         \
            -DENABLE_GST_PLUGIN_MLTFLITE=ON                                                        \
            -DENABLE_GST_PLUGIN_MLSNPE=ON                                                          \
            -DENABLE_GST_PLUGIN_MLQNN=ON                                                           \
            -DENABLE_GST_PLUGIN_MLMETAPARSER=ON                                                    \
            -DENABLE_GST_PLUGIN_METATRANSFORM=ON                                                   \
            -DENABLE_GST_PLUGIN_OBJTRACKER=ON                                                      \
            -DENABLE_GST_PLUGIN_MLMETAEXTRACTOR=ON                                                 \
            -DENABLE_GST_PLUGIN_MLPOSTPROCESS=ON                                                   \
            -DENABLE_GST_SAMPLE_APPS=ON                                                            \
            -DENABLE_GST_SAMPLE_APPS_CAMERA=ON                                                     \
            -DENABLE_GST_PLUGIN_TOOLS=ON                                                           \
            -DENABLE_GST_TEST_FRAMEWORK=ON                                                         \
            -DENABLE_GST_PYTHON_EXAMPLES=ON                                                        \
            -DENABLE_GST_PLUGIN_MSGBROKER=ON                                                       \
            -DENABLE_GST_PLUGIN_DFS=ON                                                             \
            -DENABLE_GST_PLUGIN_CAMIMGREPROC=ON                                                    \
            -DENABLE_GST_PLUGIN_CAMREPROC=ON                                                       \
            ${RECIPE_PARSED_FLAGS}                                                              && \
        print-green "${FUNCNAME} completed successfully!"
}

# Clean gst-plugins-qti-oss
function qimsdk-cmake-clean-qti() {
    rm -rf ${QIMSDK_BUILD_DIR}/gst-plugins-qti-oss ${QIMSDK_BUILD_DIR}/gst-plugins-qti-oss-base

    print-green "${FUNCNAME} completed successfully!"
}

#        plugin        |   depends on   | dependency
#----------------------+----------------+--------------------
# gst-plugins-bad      | -------------> | wayland-protocols
# gst-plugins-good     | -------------> | pulseaudio

# Configure and build gst plugins
function qimsdk-incremental-build() {
    qimsdk-meson-build-wayland-protocols                                                        && \
            qimsdk-meson-build-pulseaudio                                                       && \
            qimsdk-meson-build-gstreamer                                                        && \
            qimsdk-meson-build-gst-plugins-base                                                 && \
            qimsdk-meson-build-gst-plugins-good                                                 && \
            qimsdk-meson-build-gst-plugins-bad                                                  && \
            qimsdk-meson-build-gstd                                                             && \
            qimsdk-cmake-build-le-services                                                      && \
            qimsdk-incremental-build-qti                                                        && \
            qimsdk-cmake-build-solutions-microservices                                          && \
            print-green "QIMSDK GStreamer targets built successfully !!!"
}

print-green "qimsdk-incremental-build"
echo "    Incremental build of gst plugins"
