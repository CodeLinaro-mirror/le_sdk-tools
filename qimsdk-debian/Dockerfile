# QIMSDK Development Image
FROM debian:trixie-slim AS qimsdk_build

# Add deb-src for everything
RUN sed -Ei 's/^Types: deb$/Types: deb deb-src/'  /etc/apt/sources.list.d/debian.sources

# Add arm64 to dpkg
RUN dpkg --add-architecture arm64

# Enable Backports repo, grab mesa from there
COPY <<EOF /etc/apt/sources.list.d/trixie-backports.sources
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

COPY <<EOF /etc/apt/preferences.d/debian-backports.pref
# for binary packages built from these source packages, score the version from
# Debian backports higher as to get hardware enabled or better hardware support

Package: src:mesa:any
Pin: release n=trixie-backports
Pin-Priority: 900
EOF

# Packages installed for the native arch, needed to establish the debian/rules build system:
#   fakeroot git tar unzip ssh rsync bash-completion jq cmake android-tools-adb wget pipx
#   xz-utils gobject-introspection flex bison locales-all ninja-build gpg curl devscripts
#   debhelper crossbuild-essential-arm64 binutils-aarch64-linux-gnu pkgconf:arm64 libc6:arm64
#   libgcc-s1:arm64 libstdc++6:arm64

#  Python packages:               python-gi-dev python3.13-dev

# build time dependencies, needed for gst-plugins-imsdk compilation:
# gst-plugins-imsdk is not an apt package, so we need to install its build dependencies manually
#   instead of doing it using 'apt-get build-dep'
#  GCC support libraries:         libc6:arm64 libgcc-s1:arm64 libstdc++6:arm64
#  gst-plugin-mlaconverter:       libeigen3-dev:arm64
#  gst-plugin-mlaclassification:  libcairo-dev:arm64
#  gst-plugin-mlmetaparser:       libjson-glib-dev:arm64
#  gst-plugin-msgbroker:          libmosquitto-dev:arm64
#  gst-plugin-overlay:            opencl-headers:arm64
#  gst-plugin-redissink:          libhiredis-dev:arm64
#  gst-plugin-rtspbin:            libgstrtspserver-1.0-dev:arm64
#  gst-plugin-restricted-zonedbg: libgstreamer-plugins-bad1.0-dev:arm64
#  gst-plugin-objtracker:         libeigen3-dev:arm64

# build time dependencies, needed for fast-rpc compilation:
#  libyaml-dev:arm64, libbsd-dev:arm64

# build time dependencies, needed for camera-service compilation:
#  libprotobuf-dev:arm64, protobuf-compiler:arm64

# build time dependencies, needed for glimagesink compilation:
#  libgraphene-1.0-dev:arm64, libdrm-dev:arm64

# build time dependencies, needed for pyconfig.h generation:
#   libgdbm-dev, systemtap-sdt-dev, libdb-dev:arm64

# Installing required apt packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends           \
            fakeroot git tar unzip ssh rsync bash-completion jq cmake wget pipx xz-utils           \
            gobject-introspection flex bison locales-all ninja-build gpg curl devscripts           \
            debhelper libprotobuf-dev:arm64 protobuf-compiler:arm64 crossbuild-essential-arm64     \
            binutils-aarch64-linux-gnu python-gi-dev python3.13-dev libgdbm-dev systemtap-sdt-dev  \
            pkgconf:arm64 libc6:arm64 libgcc-s1:arm64 libstdc++6:arm64                             \
            dpkg-dev libyaml-dev:arm64 libbsd-dev:arm64 libeigen3-dev:arm64                        \
            libgstrtspserver-1.0-dev:arm64 libmosquitto-dev:arm64 libcairo-dev:arm64               \
            libjson-glib-dev:arm64 libhiredis-dev:arm64 libgstreamer-plugins-bad1.0-dev:arm64      \
            libdrm-dev:arm64 libgraphene-1.0-dev:arm64 opencl-headers:arm64 libdb-dev:arm64     && \
    apt-get build-dep -a arm64 -y gst-plugins-base1.0 gst-plugins-good1.0 gst-plugins-bad1.0    && \
    apt -y upgrade                                                                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Set target sysroot for cross-compilation system
ENV QIMSDK_TARGET_SYSROOT="/"

# Set base directory
ENV QIMSDK_BASE_DIR=/mnt/work
ENV QIMSDK_TMP_DIR=${QIMSDK_BASE_DIR}/tmp
RUN mkdir -p ${QIMSDK_TMP_DIR}

# Add host-tools directory
ENV QIMSDK_HOST_TOOLS_DIR=${QIMSDK_BASE_DIR}/host-tools

# Add qimsdk install directory
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
ENV QIMSDK_INSTALL_LIB_DIR=${QIMSDK_INSTALL_DIR}/usr/lib
RUN mkdir -p ${QIMSDK_INSTALL_LIB_DIR}

# Set up dirs used by fastrpc, comprising of skel binaries for each dsp version
ENV QIMSDK_V66_CDSP_DIR=${QIMSDK_INSTALL_DIR}/usr/share/qcom/v66
ENV QIMSDK_V68_CDSP_DIR=${QIMSDK_INSTALL_DIR}/usr/share/qcom/v68
ENV QIMSDK_V73_CDSP_DIR=${QIMSDK_INSTALL_DIR}/usr/share/qcom/v73
ENV QIMSDK_V75_CDSP_DIR=${QIMSDK_INSTALL_DIR}/usr/share/qcom/v75
RUN mkdir -p ${QIMSDK_V66_CDSP_DIR} ${QIMSDK_V68_CDSP_DIR} ${QIMSDK_V73_CDSP_DIR}                  \
        ${QIMSDK_V75_CDSP_DIR}

# Add qimsdk debug install directory
ENV QIMSDK_INSTALL_DEBUG_DIR=${QIMSDK_BASE_DIR}/deploy_dbg

# Add qimsdk build directory and logs directory
ENV QIMSDK_BUILD_DIR=${QIMSDK_BASE_DIR}/build
ENV QIMSDK_LOGS_DIR=${QIMSDK_BASE_DIR}/logs
RUN mkdir -p ${QIMSDK_BUILD_DIR}
RUN mkdir -p ${QIMSDK_LOGS_DIR}

# Set up download directory
ENV QIMSDK_DOWNLOAD_DIR=${QIMSDK_BASE_DIR}/downloads
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}

# Add the Ubuntu QCOM PPA as source-only (safe to fetch source on Debian)
RUN install -d -m 0755 /etc/apt/keyrings                                                        && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x33EF0ACBC6FE252590ABBAF21C70EB0C444248D7" | \
            gpg --dearmor -o /etc/apt/keyrings/qcom-ppa.gpg                                     && \
    echo "deb-src [signed-by=/etc/apt/keyrings/qcom-ppa.gpg] https://ppa.launchpadcontent.net/ubuntu-qcom-iot/qcom-ppa/ubuntu noble main" \
            > /etc/apt/sources.list.d/qcom-ppa-src.list

# Update and clean, fetch dma buf heap and GStreamer base, good and bad plugins
RUN DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    apt source gst-plugins-base1.0 gst-plugins-good1.0 gst-plugins-bad1.0 qcom-libdmabufheap    && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Install additional dependencies required by some gstreamer plugins: (NOTE: This needs to be done
#   separately, otherwise installation of these packages breaks.)
#   gst-plugin-msgbroker:          librdkafka-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y librdkafka-dev:arm64    && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Automatically save gst source package version and set up gst source directories
RUN GST_PLUGINS_BASE_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base*                       \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION} init          && \
    git config --global --add safe.directory                                                       \
            ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}              && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}                  \
            config --global user.name "username"                                                && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}                  \
            config --global user.email "email"                                                  && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}                  \
            add --all                                                                           && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}                  \
            commit -m "Initial Plugins Base Commit"                                             && \
    echo "export GST_PLUGINS_BASE_VERSION=${GST_PLUGINS_BASE_VERSION}" >> /root/.bashrc

RUN GST_PLUGINS_GOOD_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good*                       \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION} init          && \
    git config --global --add safe.directory                                                       \
            ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}              && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}                  \
            config --global user.name "username"                                                && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}                  \
            config --global user.email "email"                                                  && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}                  \
            add --all                                                                           && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}                  \
            commit -m "Initial Plugins Good Commit"                                             && \
    echo "export GST_PLUGINS_GOOD_VERSION=${GST_PLUGINS_GOOD_VERSION}" >> /root/.bashrc

RUN GST_PLUGINS_BAD_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad*                         \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION} init            && \
    git config --global --add safe.directory                                                       \
            ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                    \
            config --global user.name "username"                                                && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                    \
            config --global user.email "email"                                                  && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                    \
            add --all                                                                           && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                    \
            commit -m "Initial Plugins Bad Commit"                                              && \
    echo "export GST_PLUGINS_BAD_VERSION=${GST_PLUGINS_BAD_VERSION}" >> /root/.bashrc

# Optional build argument for helping set max CPU thread utilization
ARG QIMSDK_ARG_MAX_JOBS
ENV QIMSDK_MAX_JOBS="${QIMSDK_ARG_MAX_JOBS}"

# Clone Tensorflow Lite
ENV QIMSDK_TF_LITE_MAJOR="2"
ENV QIMSDK_TF_LITE_MINOR="16"
ENV QIMSDK_TF_LITE_PATCH="2"
ENV QIMSDK_TF_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/tensorflow
RUN git config --global pack.threads "${QIMSDK_ARG_MAX_JOBS:-$(nproc)}"                         && \
    git config --global http.postBuffer 157286400                                               && \
    git clone --progress https://github.com/tensorflow/tensorflow.git --single-branch              \
            --branch r${QIMSDK_TF_LITE_MAJOR}.${QIMSDK_TF_LITE_MINOR} ${QIMSDK_TF_SRC_DIR}

# Clone meta-qcom-distro and apply tflite patches for it
ENV QIMSDK_META_QCOM_DISTRO_DIR=${QIMSDK_DOWNLOAD_DIR}/meta-qcom-distro
ENV QIMSDK_TFLITE_PATCHES_DIR=${QIMSDK_META_QCOM_DISTRO_DIR}/recipes-ml/tflite/files/tflite
RUN git clone https://github.com/qualcomm-linux/meta-qcom-distro.git --single-branch --branch main \
            ${QIMSDK_META_QCOM_DISTRO_DIR}                                                      && \
    git -C ${QIMSDK_TF_SRC_DIR}                                                                    \
            am ${QIMSDK_TFLITE_PATCHES_DIR}/0*                                                  && \
    git -C ${QIMSDK_TF_SRC_DIR}                                                                    \
            am ${QIMSDK_TFLITE_PATCHES_DIR}/${QIMSDK_TF_LITE_MAJOR}.${QIMSDK_TF_LITE_MINOR}/0*

# Clone flatbuffers. Use the exact git tag as specified in tflite dependency
ENV QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/flatbuffers_23.5.26
ENV QIMSDK_FLATBUFFERS_23_5_26_INSTALL_DIR=${QIMSDK_HOST_TOOLS_DIR}/flatbuffers_23.5.26/usr
RUN QIMSDK_FLATBUFFERS_23_5_26_TAG=$(cat ${QIMSDK_TF_SRC_DIR}/tensorflow/lite/tools/cmake/modules/flatbuffers.cmake | \
            grep GIT_TAG | rev | cut -d ' ' -f 1 | rev)                                         && \
    git clone --progress https://github.com/google/flatbuffers.git                                 \
            --single-branch --branch master ${QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR}               && \
    git -C ${QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR} checkout -b work ${QIMSDK_FLATBUFFERS_24_3_25_TAG}

# Clone abseil-cpp. Use the git tag compatible with tflite 2.16, tflite 2.20 and lite rt 2.1.2
ENV QIMSDK_ABSEIL_CPP_DIR=${QIMSDK_DOWNLOAD_DIR}/abseil-cpp
RUN QIMSDK_ABSEIL_CPP_TAG=d38452e1ee03523a208362186fd42248ff2609f6                              && \
    git clone --progress https://github.com/abseil/abseil-cpp.git                                  \
            --single-branch --branch lts_2025_08_14 ${QIMSDK_ABSEIL_CPP_DIR}                    && \
    git -C ${QIMSDK_ABSEIL_CPP_DIR} checkout -b work ${QIMSDK_ABSEIL_CPP_TAG}

# Add CMake redirects
COPY cmake ${QIMSDK_DOWNLOAD_DIR}/cmake

# Copy Gobject Introspect wrappers
COPY --chmod=755 g-ir-scripts/ /usr/bin/

# Install pyconfig without overwriting existing python packages
#   the needed file is aarch64-linux-gnu/python3.13/pyconfig.h which is provided from the
#   python3.13-dev:arm64 apt package. Installing this package leads to deleting necessary packages
#   needed build time. The following RUN command solves the overwriting problem
RUN cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
        apt update && apt-get source python3.13                                                 && \
        cd $(ls -d python3.13-* | head -n1)                                                     && \
        mkdir build && cd build                                                                 && \
        ../configure --enable-loadable-sqlite-extensions                                           \
                --with-ssl-default-suites=openssl --without-ensurepip                              \
                --with-system-expat --with-system-libmpdec=no                                      \
                --with-wheel-pkg-dir=/usr/share/python-wheels/                                     \
                --with-computed-gotos --enable-ipv6 --prefix=/usr                                  \
                --libdir=/usr/lib/$DEB_HOST_MULTIARCH --with-dtrace                                \
                --host=aarch64-linux-gnu --build=aarch64-linux-gnu                              && \
        mkdir -p /usr/include/aarch64-linux-gnu/python3.13/                                     && \
        mv pyconfig.h /usr/include/aarch64-linux-gnu/python3.13/

# Initialize environment variables
ENV QIMSDK_SRC_DIR=${QIMSDK_BASE_DIR}/src
ENV QIMSDK_PATH_TO_GST_META=${QIMSDK_SRC_DIR}/gst-qti-oss-patches

# media: fetch and build camera metadata library
RUN git clone --progress https://android.googlesource.com/platform/system/media.git                \
        --single-branch --branch main ${QIMSDK_DOWNLOAD_DIR}/media                              && \
    sed -i '\|ANDROID_API|d'                                                                       \
        ${QIMSDK_DOWNLOAD_DIR}/media/private/camera/include/camera_metadata_hidden.h            && \
    sed -i '\|#include <cutils/compiler\.h>|d'                                                     \
        ${QIMSDK_DOWNLOAD_DIR}/media/private/camera/include/camera_metadata_hidden.h            && \
    sed -i '\|#include <cutils/compiler\.h>|d'                                                     \
        ${QIMSDK_DOWNLOAD_DIR}/media/camera/include/system/camera_metadata.h                    && \
    sed -i '\|ANDROID_API|d'                                                                       \
        ${QIMSDK_DOWNLOAD_DIR}/media/camera/include/system/camera_metadata.h                    && \
    sed -i 's|#include <log/log.h>|#include <stddef.h>\n#define android_errorWriteLog(...)\n#define ALOGE(...)|' \
        ${QIMSDK_DOWNLOAD_DIR}/media/camera/src/camera_metadata.c                               && \
    cat > "${QIMSDK_DOWNLOAD_DIR}/media/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)

project(camera_metadata)

add_library(camera_metadata SHARED
    camera/src/camera_metadata.c
)

target_include_directories(camera_metadata PRIVATE
    private/camera/include
    camera/include
)

set_target_properties(camera_metadata PROPERTIES
    VERSION 0.1.0
    SOVERSION 0
    OUTPUT_NAME "camera_metadata"
)

install(TARGETS camera_metadata DESTINATION lib)
EOF

# Build qcom-libdmabufheap
RUN cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    cd $(ls -d qcom-libdmabufheap-* | head -n1)                                                 && \
    MAKEFLAGS="-j${QIMSDK_ARG_MAX_JOBS:-$(nproc)}"                                                 \
    DEB_BUILD_OPTIONS="nocheck parallel=${QIMSDK_ARG_MAX_JOBS:-$(nproc)}" dpkg-buildpackage -b -us -uc -aarm64

# Build fastrpc
RUN cd "${QIMSDK_DOWNLOAD_DIR}"                                                                 && \
    git clone --depth 1 https://github.com/quic/fastrpc.git --branch v1.0.5                     && \
    cd fastrpc                                                                                  && \
    autoreconf -is                                                                              && \
    BUILD_ARCH="$(dpkg --print-architecture)"                                                   && \
    TARGET_ARCH=arm64                                                                           && \
    TARGET_TRIPLET=aarch64-linux-gnu                                                            && \
    PREFIX="${QIMSDK_INSTALL_DIR}/usr"                                                          && \
    LIBDIR="${PREFIX}/lib/${TARGET_TRIPLET}"                                                    && \
    if [ "${BUILD_ARCH}" = "${TARGET_ARCH}" ]; then                                                \
        CC=gcc                                                                                  && \
        AR=ar                                                                                   && \
        RANLIB=ranlib                                                                           && \
        CONFIGURE_ARGS="";                                                                         \
    else                                                                                           \
        CC=${TARGET_TRIPLET}-gcc                                                                && \
        AR=${TARGET_TRIPLET}-ar                                                                 && \
        RANLIB=${TARGET_TRIPLET}-ranlib                                                         && \
        CONFIGURE_ARGS="--host=${TARGET_TRIPLET}";                                                 \
    fi                                                                                          && \
    CFLAGS='-UMACHINE_NAME_PATH -DMACHINE_NAME_PATH=\"/run/device-model\"'                         \
        CC="${CC}" AR="${AR}" RANLIB="${RANLIB}"                                                   \
        ./configure                                                                                \
            ${CONFIGURE_ARGS}                                                                      \
            --prefix="${PREFIX}"                                                                   \
            --libdir="${LIBDIR}"                                                                && \
    make -j"${QIMSDK_ARG_MAX_JOBS:-$(nproc)}"                                                   && \
    cp ./src/.libs/libcdsprpc.so* ${QIMSDK_INSTALL_DIR}/usr/lib/                                && \
    aarch64-linux-gnu-strip ${QIMSDK_INSTALL_DIR}/usr/lib/libcdsprpc.so*

# Download prebuilt libraries for the Smart Video Encoder control algorithm and copy them to the target and build container
ENV SMART_VENC_BUILD_DATE="260112.1"
ENV SMART_VENC_VERSION="1.0"
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
    https://qartifactory-edge.qualcomm.com/artifactory/qsc_releases/software/chip/component/iot-core-algs.lnx.0.0/${SMART_VENC_BUILD_DATE}/prebuilt_yocto/qcom-video-ctrl_${SMART_VENC_VERSION}_armv8-2a.tar.gz && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    mkdir -p ${QIMSDK_DOWNLOAD_DIR}/smart-venc                                                  && \
    tar xvf qcom-video-ctrl_${SMART_VENC_VERSION}_armv8-2a.tar.gz -C smart-venc                 && \
    cp -r ${QIMSDK_DOWNLOAD_DIR}/smart-venc/usr /                                               && \
    cp -r ${QIMSDK_DOWNLOAD_DIR}/smart-venc/etc /                                               && \
    cp ${QIMSDK_DOWNLOAD_DIR}/smart-venc/usr/lib/lib* ${QIMSDK_INSTALL_LIB_DIR}/                && \
    cp -r ${QIMSDK_DOWNLOAD_DIR}/smart-venc/etc ${QIMSDK_INSTALL_DIR}/                          && \
    rm -rf smart-venc qcom-video-ctrl_${SMART_VENC_VERSION}_armv8-2a.tar.gz

# Download prebuilt libraries for the Qualcomm FastCV library and copy them to the target container
ENV FASTCV_BUILD_DATE="260222"
ENV FASTCV_PACKAGE_NAME="qcom-fastcv-binaries"
ENV FASTCV_VERSION="1.8.5"
ENV FASTCV_ARCH="armv8a"
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
    https://qartifactory-edge.qualcomm.com/artifactory/qsc_releases/software/chip/component/computervision-fastcv.qclinux.0.1/${FASTCV_BUILD_DATE}/prebuilt_yocto/${FASTCV_PACKAGE_NAME}_${FASTCV_VERSION}_${FASTCV_ARCH}.tar.gz && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    mkdir -p ${QIMSDK_DOWNLOAD_DIR}/fastcv                                                      && \
    tar xvf ${FASTCV_PACKAGE_NAME}_${FASTCV_VERSION}_${FASTCV_ARCH}.tar.gz -C fastcv            && \
    cp ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/dsp/cdsp/cv/v65/TALOS_MOOREA/*.so                     \
            ${QIMSDK_V66_CDSP_DIR}/                                                             && \
    cp ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/dsp/cdsp/cv/v68/KODIAK/*.so                           \
            ${QIMSDK_V68_CDSP_DIR}/                                                             && \
    cp ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/dsp/cdsp/cv/v73/LEMANS/*.so                           \
            ${QIMSDK_V73_CDSP_DIR}/                                                             && \
    cp ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/dsp/cdsp/cv/v75/MONACO/*.so                           \
            ${QIMSDK_V75_CDSP_DIR}/                                                             && \
    cp ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/libfastcvopt.so.1.8.0 ${QIMSDK_INSTALL_LIB_DIR}/   && \
    cp ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/libfastcvdsp_stub.so.1.8.0                            \
            ${QIMSDK_INSTALL_LIB_DIR}/                                                          && \
    cp -d ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/libfastcvopt.so.1 ${QIMSDK_INSTALL_LIB_DIR}/    && \
    cp -d ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/libfastcvopt.so ${QIMSDK_INSTALL_LIB_DIR}/      && \
    cp -d ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/libfastcvdsp_stub.so.1                             \
            ${QIMSDK_INSTALL_LIB_DIR}/                                                          && \
    cp -d ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/lib/libfastcvdsp_stub.so ${QIMSDK_INSTALL_LIB_DIR}/ && \
    rm -rf fastcv ${FASTCV_PACKAGE_NAME}_${FASTCV_VERSION}_${FASTCV_ARCH}.tar.gz

# gst-qti-oss-patches: fetch
RUN GST_PLUGINS_BASE_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base*                       \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    git clone --progress https://github.com/qualcomm/gst-qti-oss-patches.git --single-branch       \
        --branch ${GST_PLUGINS_BASE_VERSION} ${QIMSDK_SRC_DIR}/gst-qti-oss-patches

# qnp-sdk: fetch and copy the needed headers
ARG QIMSDK_ARG_QNP_VERSION
RUN if [ -z "$QIMSDK_ARG_QNP_VERSION" ]; then                                                      \
        echo "WARN : QIMSDK_ARG_QNP_VERSION is not provided. Skipping QNN installation." >&2;      \
    else                                                                                           \
        export QIMSDK_QNP_SDK=v${QIMSDK_ARG_QNP_VERSION}.zip                                    && \
        export QIMSDK_QNN_LIB_PATH=${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_VERSION}/lib/  && \
        wget -t 10 -T 3600 -P ${QIMSDK_DOWNLOAD_DIR}                                               \
        https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/${QIMSDK_ARG_QNP_VERSION}/${QIMSDK_QNP_SDK} && \
        cd ${QIMSDK_DOWNLOAD_DIR}                                                               && \
        unzip ${QIMSDK_QNP_SDK}                                                                 && \
        rm -f ${QIMSDK_QNP_SDK}                                                                 && \
        QIMSDK_ARG_QNP_SDK_VERSION=$(ls qairt)                                                  && \
        cp -r ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/SNPE/*            \
            /usr/include/.                                                                      && \
        cp -r ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/QNN/*             \
            /usr/include/.                                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v66/unsigned/* ${QIMSDK_V66_CDSP_DIR}/                && \
        cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v68/unsigned/* ${QIMSDK_V68_CDSP_DIR}/                && \
        cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v73/unsigned/* ${QIMSDK_V73_CDSP_DIR}/                && \
        cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v75/unsigned/* ${QIMSDK_V75_CDSP_DIR}/                && \
        find "${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2"                                     \
            -maxdepth 1 -type f                                                                    \
            \(                                                                                     \
                -name 'libQnnGenAiTransformerCpuOpPkg.so' -o                                       \
                -name 'libhta_hexagon_runtime_qnn.so' -o                                           \
                -name 'libhta_hexagon_runtime_snpe.so' -o                                          \
                -name 'libPlatformValidatorShared.so' -o                                           \
                -name 'libQnnChrometraceProfilingReader.so' -o                                     \
                -name 'libQnnCpu.so' -o                                                            \
                -name 'libQnnDspNetRunExtensions.so' -o                                            \
                -name 'libQnnDsp.so' -o                                                            \
                -name 'libQnnGenAiTransformerModel.so' -o                                          \
                -name 'libQnnGenAiTransformer.so' -o                                               \
                -name 'libQnnGpuNetRunExtensions.so' -o                                            \
                -name 'libQnnGpuProfilingReader.so' -o                                             \
                -name 'libQnnGpu.so' -o                                                            \
                -name 'libQnnHtaNetRunExtensions.so' -o                                            \
                -name 'libQnnHta.so' -o                                                            \
                -name 'libQnnHtpNetRunExtensions.so' -o                                            \
                -name 'libQnnHtpOptraceProfilingReader.so' -o                                      \
                -name 'libQnnHtpPrepare.so' -o                                                     \
                -name 'libQnnHtpProfilingReader.so' -o                                             \
                -name 'libQnnHtp.so' -o                                                            \
                -name 'libQnnDspV66Stub.so' -o                                                     \
                -name 'libQnnDspV66CalculatorStub.so' -o                                           \
                -name 'libQnnHtpV68CalculatorStub.so' -o                                           \
                -name 'libQnnHtpV68Stub.so' -o                                                     \
                -name 'libQnnHtpV73CalculatorStub.so' -o                                           \
                -name 'libQnnHtpV73Stub.so' -o                                                     \
                -name 'libQnnHtpV75CalculatorStub.so' -o                                           \
                -name 'libQnnHtpV75Stub.so' -o                                                     \
                -name 'libQnnIr.so' -o                                                             \
                -name 'libQnnJsonProfilingReader.so' -o                                            \
                -name 'libQnnModelDlc.so' -o                                                       \
                -name 'libQnnSaver.so' -o                                                          \
                -name 'libQnnSystem.so' -o                                                         \
                -name 'libQnnTFLiteDelegate.so' -o                                                 \
                -name 'libSnpeHta.so' -o                                                           \
                -name 'libSnpeHtpPrepare.so' -o                                                    \
                -name 'libSnpeDspV66Stub.so' -o                                                    \
                -name 'libSnpeHtpV68CalculatorStub.so' -o                                          \
                -name 'libSnpeHtpV68Stub.so' -o                                                    \
                -name 'libSnpeHtpV73CalculatorStub.so' -o                                          \
                -name 'libSnpeHtpV73Stub.so' -o                                                    \
                -name 'libSnpeHtpV75CalculatorStub.so' -o                                          \
                -name 'libSnpeHtpV75Stub.so' -o                                                    \
                -name 'libSNPE.so'                                                                 \
            \)                                                                                     \
            -exec cp -t "${QIMSDK_INSTALL_LIB_DIR}/" {} +                                       && \
        rm -rf ${QIMSDK_DOWNLOAD_DIR}/qairt;                                                       \
    fi

# camera-service: fetch
ARG QIMSDK_ARG_CAMERA_SERVICE_TAG
RUN git clone --progress https://github.com/qualcomm/camera-service.git                            \
        --single-branch --branch main ${QIMSDK_SRC_DIR}/camera-service                          && \
        [ -z "${QIMSDK_ARG_CAMERA_SERVICE_TAG}" ]                                               || \
        git -C ${QIMSDK_SRC_DIR}/camera-service checkout -b work ${QIMSDK_ARG_CAMERA_SERVICE_TAG}

# gst-plugins-imsdk: fetch
ARG QIMSDK_ARG_GST_PLUGINS_TAG
RUN git clone --single-branch --branch main https://github.com/qualcomm/gst-plugins-imsdk.git      \
        ${QIMSDK_SRC_DIR}/gst-plugins-imsdk                                                     && \
        [ -z "${QIMSDK_ARG_GST_PLUGINS_TAG}" ]                                                  || \
        git -C ${QIMSDK_SRC_DIR}/gst-plugins-imsdk checkout -b work ${QIMSDK_ARG_GST_PLUGINS_TAG}

# gst-plugins-imsdk: fetch
ARG QIMSDK_ARG_SOLUTIONS_MICROSERVICES_TAG
RUN git clone --single-branch --branch iot-solutions.lnx.1.0                                       \
            https://git.codelinaro.org/clo/le/solutions-microservices                              \
        ${QIMSDK_SRC_DIR}/solutions-microservices                                               && \
        [ -z "${QIMSDK_ARG_SOLUTIONS_MICROSERVICES_TAG}" ]                                      || \
        git -C ${QIMSDK_SRC_DIR}/solutions-microservices checkout -b work                          \
                ${QIMSDK_ARG_SOLUTIONS_MICROSERVICES_TAG}

# Add development image scripts
ENV QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/scripts/
COPY scripts ${QIMSDK_SCRIPTS}

# Source container helper scripts from bashrc
RUN echo "source ${QIMSDK_SCRIPTS}/env_setup.sh" >> /root/.bashrc

# Change workdir back to base dir from downloads dir
WORKDIR ${QIMSDK_BASE_DIR}

# Copy the Tensorflow Lite's headers and dependent headers to the sysroot
RUN bash /root/.bashrc qimsdk-copy-tf-lite-headers-to-sysroot

# Call wrapper function to apply all patches
RUN bash /root/.bashrc qimsdk-apply-patches

# Call wrapper build function to compile and install gst plugins
RUN bash /root/.bashrc qimsdk-incremental-build

# Create directory to save deb packages
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}/debs/

# Copy selected packages to install
RUN cp ${QIMSDK_DOWNLOAD_DIR}/*base-1.0_* ${QIMSDK_DOWNLOAD_DIR}/*alsa_*                           \
       ${QIMSDK_DOWNLOAD_DIR}/*gtk3_* ${QIMSDK_DOWNLOAD_DIR}/*base_*                               \
       ${QIMSDK_DOWNLOAD_DIR}/*base-apps_* ${QIMSDK_DOWNLOAD_DIR}/*good_*                          \
       ${QIMSDK_DOWNLOAD_DIR}/*pulseaudio_* ${QIMSDK_DOWNLOAD_DIR}/*x_*                            \
       ${QIMSDK_DOWNLOAD_DIR}/*base1.0-0_1* ${QIMSDK_DOWNLOAD_DIR}/*bad_*                          \
       ${QIMSDK_DOWNLOAD_DIR}/*bad1.0-0_1*                                                         \
       ${QIMSDK_DOWNLOAD_DIR}/qcom-libdmabufheap_*_arm64.deb                                       \
       ${QIMSDK_DOWNLOAD_DIR}/debs/

# --------------------------------------------------------------------------------------------------

# QIMSDK Device Image
FROM --platform=linux/arm64 debian:trixie-slim AS qimsdk_deploy_arm64

# Set base directory
ENV QIMSDK_BASE_DIR=/mnt/work
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
ENV QIMSDK_DEB_DIR=${QIMSDK_BASE_DIR}/downloads/debs

# Enable Backports repo, grab mesa from there
COPY <<EOF /etc/apt/sources.list.d/trixie-backports.sources
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

COPY <<EOF /etc/apt/preferences.d/debian-backports.pref
# for binary packages built from these source packages, score the version from
# Debian backports higher as to get hardware enabled or better hardware support

Package: src:mesa:any
Pin: release n=trixie-backports
Pin-Priority: 900
EOF

# Installing dependencies, needed in order for gst plugins to load succesfully runtime:
#  gstreamer base plugins:        gstreamer1.0-tools,
#                                 gstreamer1.0-plugins-base,
#                                 gir1.2-gst-1.0
#                                 libxv1
#                                 gobject-introspection
#                                 flex
#                                 bison
#                                 libglib2.0-0
#  gst-plugin-redissink:          libhiredis1.1.0
#  gst-plugin-restrictedzonedbg:  libopencv-imgproc410
#  gst-plugin-rtspbin:            libgstrtspserver-1.0-0
#  gst-plugin-msgbroker:          librdkafka1
#  qtdemux:                       gstreamer1.0-plugins-good
#  software encoder needed for
#    rtspsrc usecases:            gstreamer1.0-plugins-ugly
#  pulseaudio runtime dependency: pulseaudio
#  fast rpc runtime dependency:   libyaml-0-2:arm64
#  WebRTC runtime dependency:     gstreamer1.0-nice
#  Mesa Vulkan drivers:           mesa-vulkan-drivers
RUN apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends           \
            adduser gosu bash-completion nano libhiredis1.1.0 gstreamer1.0-tools                   \
            libgstrtspserver-1.0-0 libopencv-imgproc410 libxv1 gstreamer1.0-nice                   \
            gstreamer1.0-plugins-good pulseaudio gstreamer1.0-plugins-base librdkafka1             \
            gstreamer1.0-plugins-ugly gir1.2-gst-1.0 libyaml-0-2 mesa-vulkan-drivers            && \
    apt -y upgrade                                                                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Add QTI PPA and install QTI dependencies
#  gpg curl:                        install PPA
#  qcom-adreno1:                    adreno

RUN DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gpg curl             \
            ca-certificates                                                                     && \
    update-ca-certificates                                                                      && \
    install -d -m 0700 /var/lib/apt/gnupg                                                       && \
    install -d -m 0755 /etc/apt/keyrings                                                        && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x33EF0ACBC6FE252590ABBAF21C70EB0C444248D7" | \
            env GNUPGHOME=/var/lib/apt/gnupg gpg --dearmor                                         \
            -o /etc/apt/keyrings/qcom-ppa.gpg                                                   && \
    echo "deb [signed-by=/etc/apt/keyrings/qcom-ppa.gpg] https://ppa.launchpadcontent.net/ubuntu-qcom-iot/qcom-ppa/ubuntu noble main" \
            > /etc/apt/sources.list.d/qcom-ppa.list                                             && \
    apt update                                                                                  && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends                          \
            qcom-adreno1                                                                        && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*                                                       && \
    rm -f /etc/profile.d/qcom-adreno-profile.sh /usr/lib/qcom-adreno-vars.sh

# Create yaml file specifying directories of dsp skel binaries needed for fastrpc
RUN mkdir -p /usr/share/qcom/conf.d                                                             && \
    {                                                                                              \
        echo '# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.';               \
        echo '# SPDX-License-Identifier: MIT';                                                     \
        echo 'machines:';                                                                          \
        echo '  Qualcomm Technologies, Inc. SDM845 HDK:';                                          \
        echo '    DSP_LIBRARY_PATH: v66';                                                          \
        echo '  Qualcomm QCS615 IQ 615 EVK:';                                                      \
        echo '    DSP_LIBRARY_PATH: v66';                                                          \
        echo '  Qualcomm Technologies, Inc. QCS615 Ride (IQ-615 Beta EVK):';                       \
        echo '    DSP_LIBRARY_PATH: v66';                                                          \
        echo '  Qualcomm Technologies, Inc. Robotics RB3gen2:';                                    \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Robotics RB3gen2 addons vision mezz platform:';        \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Glymur CRD:';                                          \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Kaanapali MTP:';                                       \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Purwa IoT EVK:';                                       \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. QCM6490 IDP:';                                         \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Thundercomm RUBIK Pi 3:';                                                          \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Radxa Dragon Q6A:';                                                                \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Robotics RB5:';                                        \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Lemans EVK:';                                          \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Addons IQ 9075 EVK:';                                  \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Hamoa IoT EVK:';                                       \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Shikra CQS EVK:';                                      \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. SM8750 MTP:';                                          \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm SA8775P Ride:';                                                           \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm SA8775P Ride Rev3:';                                                      \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Lemans Ride:';                                         \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Lemans Ride Rev3:';                                    \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Arduino VENTUNO Q:';                                                               \
        echo '    DSP_LIBRARY_PATH: v75';                                                          \
        echo '  Qualcomm Technologies, Inc. Monaco EVK:';                                          \
        echo '    DSP_LIBRARY_PATH: v75';                                                          \
        echo '  Qualcomm Technologies, Inc. Monaco Monza addons:';                                 \
        echo '    DSP_LIBRARY_PATH: v75';                                                          \
        echo '  Qualcomm Technologies, Inc. QCS8300 Ride:';                                        \
        echo '    DSP_LIBRARY_PATH: v75';                                                          \
    } > /usr/share/qcom/conf.d/hexagon-dsp-binaries.yaml

# Create USER and add to video group for accessing v4ls devices
RUN addgroup qcom                                                                               && \
    useradd -s /bin/bash -m -g qcom qimsdk                                                      && \
    usermod -aG video qimsdk                                                                    && \
    usermod -aG kmem qimsdk                                                                     && \
    echo qimsdk:asd | chpasswd

# Increase max number of fd to be opened by one process
RUN ulimit -n 16192

# Copy installed binaries to device image
COPY --from=qimsdk_build ${QIMSDK_INSTALL_DIR}/usr /usr

# Copy deb packages to device image
COPY --from=qimsdk_build /mnt/work/downloads/debs ${QIMSDK_DEB_DIR}

# Install deb packages to deploy image and remove the directory after install
RUN dpkg -i ${QIMSDK_DEB_DIR}/* && rm -rf ${QIMSDK_DEB_DIR}

# Change workdir to user home
WORKDIR /home/qimsdk

# Add line to .bashrc to source .bash_aliases file on every shell execution
RUN echo '[ -f ~/.bash_aliases ] && . ~/.bash_aliases\n' >> /root/.bashrc

# Copy entrypoint files which allow us to drop priveleges after resolving socket ownership
COPY entrypoint.sh /bin/entrypoint.sh
COPY .bash_aliases /root/.bash_aliases

# Create an image where a detached container can run indefinitely
ENTRYPOINT ["/bin/entrypoint.sh"]

CMD ["/bin/bash"]
