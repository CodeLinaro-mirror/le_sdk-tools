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

# build time dependencies, needed for qimsdk src compilation:
# qimsdk is not an apt package, its build dependencies needs to be installed manually
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
#  App Builder SDK (cpp):         libyaml-cpp-dev:arm64

# build time dependencies, needed for fast-rpc compilation:
#  libyaml-dev:arm64, libbsd-dev:arm64

# build time dependencies, needed for camera-service compilation:
#  libprotobuf-dev:arm64, protobuf-compiler:arm64

# build time dependencies, needed for glimagesink compilation:
#  libgraphene-1.0-dev:arm64, libdrm-dev:arm64

# build time dependencies, needed for pyconfig.h generation:
#   libgdbm-dev, systemtap-sdt-dev, libdb-dev:arm64

# build time dependencies, needed for mk-build-deps generation:
#   equivs, devscripts

# Installing required apt packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends           \
            fakeroot git tar unzip ssh rsync bash-completion jq cmake wget pipx xz-utils           \
            gobject-introspection flex bison locales-all ninja-build gpg curl devscripts equivs    \
            debhelper libprotobuf-dev:arm64 protobuf-compiler:arm64 crossbuild-essential-arm64     \
            binutils-aarch64-linux-gnu python-gi-dev python3.13-dev libgdbm-dev systemtap-sdt-dev  \
            pkgconf:arm64 libc6:arm64 libgcc-s1:arm64 libstdc++6:arm64                             \
            dpkg-dev libyaml-dev:arm64 libbsd-dev:arm64 libeigen3-dev:arm64                        \
            libgstrtspserver-1.0-dev:arm64 libmosquitto-dev:arm64 libcairo-dev:arm64               \
            libjson-glib-dev:arm64 libhiredis-dev:arm64 libgstreamer-plugins-bad1.0-dev:arm64      \
            libdrm-dev:arm64 libgraphene-1.0-dev:arm64 opencl-headers:arm64 libdb-dev:arm64        \
            libyaml-cpp-dev:arm64                                                               && \
    apt-get build-dep -a arm64 -y gst-plugins-base1.0 gst-plugins-good1.0                       && \
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

# Disable the onnx GStreamer element in gst-plugins-bad1.0: upstream's own
#   -Donnx=disabled excludes arm64, so append our own at the end of the dh_auto_configure recipe
#   line instead
RUN GST_PLUGINS_BAD_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad*                         \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    (                                                                                              \
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                 && \
        sed -i '/^\tdh_auto_configure --/ s/$/ -Donnx=disabled/' debian/rules                   && \
        sed -i '/libonnxruntime-dev/d' debian/control                                           && \
        sed -i '/libgstonnx\.so/d'     debian/rules                                             && \
        grep -qP '^\tdh_auto_configure --.*-Donnx=disabled' debian/rules                           \
    )                                                                                           && \
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

# Install gst-plugins-bad1.0's build-deps from the patched local debian/control via
#  mk-build-deps, so the Debian packaged onnxruntime is never pulled in,
#  qimsdk ships its own build and having both breaks dpkg-shlibdeps.
RUN GST_PLUGINS_BAD_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad*                         \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    (                                                                                              \
        cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                 && \
        mk-build-deps -i -r --host-arch arm64 -a arm64                                             \
            -t 'apt-get -y --no-install-recommends' debian/control                              && \
        rm -f gst-plugins-bad1.0-cross-build-deps_*.deb                                            \
            gst-plugins-bad1.0-cross-build-deps_*.changes                                          \
            gst-plugins-bad1.0-cross-build-deps_*.buildinfo                                        \
    )                                                                                           && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Install additional dependencies required by some gstreamer plugins: (NOTE: This needs to be done
#   separately, otherwise installation of these packages breaks.)
#   gst-plugin-msgbroker:          librdkafka-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y librdkafka-dev:arm64    && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

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
    mkdir -p ${QIMSDK_TF_SRC_DIR}                                                               && \
    git -C ${QIMSDK_TF_SRC_DIR} init                                                            && \
    git -C ${QIMSDK_TF_SRC_DIR}                                                                    \
            remote add origin https://github.com/tensorflow/tensorflow.git                      && \
    git -C ${QIMSDK_TF_SRC_DIR} fetch --depth 1 origin                                             \
            r${QIMSDK_TF_LITE_MAJOR}.${QIMSDK_TF_LITE_MINOR}                                    && \
    git -C ${QIMSDK_TF_SRC_DIR} checkout FETCH_HEAD

# Clone LiteRT
ENV LITERT_MAJOR_VERSION="2"
ENV LITERT_MINOR_VERSION="1"
ENV LITERT_PATCH_VERSION="6"
ENV QIMSDK_LITERT_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/litert
RUN mkdir -p ${QIMSDK_LITERT_SRC_DIR}                                                           && \
    git -C ${QIMSDK_LITERT_SRC_DIR} init                                                        && \
    git -C ${QIMSDK_LITERT_SRC_DIR}                                                                \
            remote add origin https://github.com/google-ai-edge/LiteRT.git                      && \
    git -C ${QIMSDK_LITERT_SRC_DIR} fetch --depth 1 origin                                         \
            v${LITERT_MAJOR_VERSION}.${LITERT_MINOR_VERSION}.${LITERT_PATCH_VERSION}            && \
    git -C ${QIMSDK_LITERT_SRC_DIR} checkout FETCH_HEAD                                         && \
    git -C ${QIMSDK_LITERT_SRC_DIR} submodule update --init --recursive --depth 1

# Clone meta-qcom-distro and apply tflite patches for it
ENV QIMSDK_META_QCOM_DISTRO_DIR=${QIMSDK_DOWNLOAD_DIR}/meta-qcom-distro
ENV QIMSDK_TFLITE_PATCHES_DIR=${QIMSDK_META_QCOM_DISTRO_DIR}/recipes-ml/tflite/files/tflite
RUN mkdir -p ${QIMSDK_META_QCOM_DISTRO_DIR}                                                     && \
    git -C ${QIMSDK_META_QCOM_DISTRO_DIR} init                                                  && \
    git -C ${QIMSDK_META_QCOM_DISTRO_DIR}                                                          \
            remote add origin https://github.com/qualcomm-linux/meta-qcom-distro.git            && \
    git -C ${QIMSDK_META_QCOM_DISTRO_DIR} fetch --depth 1 origin main                           && \
    git -C ${QIMSDK_META_QCOM_DISTRO_DIR} checkout FETCH_HEAD                                   && \
    git -C ${QIMSDK_TF_SRC_DIR}                                                                    \
            am ${QIMSDK_TFLITE_PATCHES_DIR}/0*                                                  && \
    git -C ${QIMSDK_TF_SRC_DIR}                                                                    \
            am ${QIMSDK_TFLITE_PATCHES_DIR}/${QIMSDK_TF_LITE_MAJOR}.${QIMSDK_TF_LITE_MINOR}/0*

# Clone meta-ai and apply litert patches for it
ENV QIMSDK_META_AI_DIR=${QIMSDK_DOWNLOAD_DIR}/meta-ai
ENV QIMSDK_LITERT_PATCHES_DIR=${QIMSDK_META_AI_DIR}/recipes-ml/litert/files
RUN mkdir -p ${QIMSDK_META_AI_DIR}                                                              && \
    git -C ${QIMSDK_META_AI_DIR} init                                                           && \
    git -C ${QIMSDK_META_AI_DIR}                                                                   \
            remote add origin https://github.com/qualcomm-linux/meta-ai.git                     && \
    git -C ${QIMSDK_META_AI_DIR} fetch --depth 1 origin main                                    && \
    git -C ${QIMSDK_META_AI_DIR} checkout FETCH_HEAD                                            && \
    git -C ${QIMSDK_LITERT_SRC_DIR} am ${QIMSDK_LITERT_PATCHES_DIR}/0*.patch

# Clone onnxruntime-qnn. It is cloned first because its cmake/deps.txt declares
#  the onnx and onnxruntime versions it was validated against, which are used to
#  clone the two below.
ENV QIMSDK_ONNXRUNTIME_QNN_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/onnxruntime-qnn
ENV QIMSDK_ONNXRUNTIME_QNN_SRC_BRANCH=v2.4.0
RUN mkdir -p ${QIMSDK_ONNXRUNTIME_QNN_SRC_DIR}                                                  && \
    git -C ${QIMSDK_ONNXRUNTIME_QNN_SRC_DIR} init                                               && \
    git -C ${QIMSDK_ONNXRUNTIME_QNN_SRC_DIR}                                                       \
            remote add origin https://github.com/onnxruntime/onnxruntime-qnn                    && \
    git -C ${QIMSDK_ONNXRUNTIME_QNN_SRC_DIR} fetch --depth 1 --no-tags origin                      \
            ${QIMSDK_ONNXRUNTIME_QNN_SRC_BRANCH}                                                && \
    git -C ${QIMSDK_ONNXRUNTIME_QNN_SRC_DIR} checkout FETCH_HEAD

# Clone onnx and onnxruntime on the release branches onnxruntime-qnn pins for
#  them in cmake/deps.txt.
ENV QIMSDK_ONNX_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/onnx
ENV QIMSDK_ONNXRUNTIME_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/onnxruntime
RUN QIMSDK_ONNX_DEPS_FILE=${QIMSDK_ONNXRUNTIME_QNN_SRC_DIR}/cmake/deps.txt                      && \
    QIMSDK_ONNX_SRC_BRANCH=$(grep "onnx;" ${QIMSDK_ONNX_DEPS_FILE}                                 \
        | rev | cut -d '/' -f 1 | rev | sed -E 's#.*v([0-9.]+)\.zip;.*#rel-\1#')                && \
    QIMSDK_ONNXRUNTIME_SRC_BRANCH=$(grep "ort_core;" ${QIMSDK_ONNX_DEPS_FILE}                      \
        | rev | cut -d '/' -f 1 | rev | sed -E 's#.*v([0-9.]+)\.zip;.*#rel-\1#')                && \
    mkdir -p ${QIMSDK_ONNX_SRC_DIR}                                                             && \
    git -C ${QIMSDK_ONNX_SRC_DIR} init                                                          && \
    git -C ${QIMSDK_ONNX_SRC_DIR}                                                                  \
            remote add origin https://github.com/onnx/onnx.git                                  && \
    git -C ${QIMSDK_ONNX_SRC_DIR} fetch --depth 1 --no-tags origin ${QIMSDK_ONNX_SRC_BRANCH}    && \
    git -C ${QIMSDK_ONNX_SRC_DIR} checkout FETCH_HEAD                                           && \
    mkdir -p ${QIMSDK_ONNXRUNTIME_SRC_DIR}                                                      && \
    git -C ${QIMSDK_ONNXRUNTIME_SRC_DIR} init                                                   && \
    git -C ${QIMSDK_ONNXRUNTIME_SRC_DIR}                                                           \
            remote add origin https://github.com/microsoft/onnxruntime                          && \
    git -C ${QIMSDK_ONNXRUNTIME_SRC_DIR} fetch --depth 1 --no-tags origin                          \
            ${QIMSDK_ONNXRUNTIME_SRC_BRANCH}                                                    && \
    git -C ${QIMSDK_ONNXRUNTIME_SRC_DIR} checkout FETCH_HEAD                                    && \
    git -C ${QIMSDK_ONNXRUNTIME_SRC_DIR} submodule update --init --recursive --depth 1

# Clone meta-qcom and apply onnxruntime-qnn patches for it
ENV QIMSDK_META_QCOM_DIR=${QIMSDK_DOWNLOAD_DIR}/meta-qcom
ENV QIMSDK_ONNXRUNTIME_QNN_PATCHES_DIR=${QIMSDK_META_QCOM_DIR}/dynamic-layers/ai/recipes-ml/onnxruntime-qnn/files
RUN mkdir -p ${QIMSDK_META_QCOM_DIR}                                                            && \
    git -C ${QIMSDK_META_QCOM_DIR} init                                                         && \
    git -C ${QIMSDK_META_QCOM_DIR}                                                                 \
            remote add origin https://github.com/qualcomm-linux/meta-qcom.git                   && \
    git -C ${QIMSDK_META_QCOM_DIR} fetch --depth 1 origin master                                && \
    git -C ${QIMSDK_META_QCOM_DIR} checkout FETCH_HEAD                                          && \
    git -C ${QIMSDK_ONNXRUNTIME_QNN_SRC_DIR} am ${QIMSDK_ONNXRUNTIME_QNN_PATCHES_DIR}/0*.patch

# Clone flatbuffers. Use the exact git tag as specified in tflite dependency
ENV QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/flatbuffers_23.5.26
ENV QIMSDK_FLATBUFFERS_23_5_26_INSTALL_DIR=${QIMSDK_HOST_TOOLS_DIR}/flatbuffers_23.5.26/usr
RUN QIMSDK_FLATBUFFERS_23_5_26_TAG=$(cat ${QIMSDK_TF_SRC_DIR}/tensorflow/lite/tools/cmake/modules/flatbuffers.cmake | \
            grep GIT_TAG | rev | cut -d ' ' -f 1 | rev)                                         && \
    mkdir -p ${QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR}                                              && \
    git -C ${QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR} init                                           && \
    git -C ${QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR}                                                   \
            remote add origin https://github.com/google/flatbuffers.git                         && \
    git -C ${QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR}                                                   \
            fetch --depth 1 origin ${QIMSDK_FLATBUFFERS_23_5_26_TAG}                            && \
    git -C ${QIMSDK_FLATBUFFERS_23_5_26_SRC_DIR} checkout FETCH_HEAD

# Clone abseil-cpp. Use the git tag compatible with tflite 2.16, tflite 2.20 and lite rt 2.1.2
ENV QIMSDK_ABSEIL_CPP_DIR=${QIMSDK_DOWNLOAD_DIR}/abseil-cpp
RUN QIMSDK_ABSEIL_CPP_TAG=d38452e1ee03523a208362186fd42248ff2609f6                              && \
    mkdir -p ${QIMSDK_ABSEIL_CPP_DIR}                                                           && \
    git -C ${QIMSDK_ABSEIL_CPP_DIR} init                                                        && \
    git -C ${QIMSDK_ABSEIL_CPP_DIR}                                                                \
            remote add origin https://github.com/abseil/abseil-cpp.git                          && \
    git -C ${QIMSDK_ABSEIL_CPP_DIR} fetch --depth 1 origin ${QIMSDK_ABSEIL_CPP_TAG}             && \
    git -C ${QIMSDK_ABSEIL_CPP_DIR} checkout FETCH_HEAD

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
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}/media                                                       && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/media init                                                    && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/media                                                            \
            remote add origin https://android.googlesource.com/platform/system/media.git        && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/media fetch --depth 1 origin main                             && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/media checkout FETCH_HEAD                                     && \
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
    mkdir -p fastrpc                                                                            && \
    git -C fastrpc init                                                                         && \
    git -C fastrpc remote add origin https://github.com/quic/fastrpc.git                        && \
    git -C fastrpc fetch --depth 1 origin v1.0.7                                                && \
    git -C fastrpc checkout FETCH_HEAD                                                          && \
    cd fastrpc                                                                                  && \
    autoreconf -is                                                                              && \
    BUILD_ARCH="$(dpkg --print-architecture)"                                                   && \
    TARGET_ARCH=arm64                                                                           && \
    TARGET_TRIPLET=aarch64-linux-gnu                                                            && \
    PREFIX="${QIMSDK_INSTALL_DIR}/usr"                                                          && \
    LIBDIR="${PREFIX}/lib/${TARGET_TRIPLET}"                                                    && \
    [ "${BUILD_ARCH}" = "${TARGET_ARCH}" ]                                                    && { \
        CC=gcc                                                                                  && \
        AR=ar                                                                                   && \
        RANLIB=ranlib                                                                           && \
        CONFIGURE_ARGS="";                                                                         \
    } || {                                                                                         \
        CC=${TARGET_TRIPLET}-gcc                                                                && \
        AR=${TARGET_TRIPLET}-ar                                                                 && \
        RANLIB=${TARGET_TRIPLET}-ranlib                                                         && \
        CONFIGURE_ARGS="--host=${TARGET_TRIPLET}";                                                 \
    }                                                                                           && \
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
ENV SMART_VENC_BUILD_DATE="260814"
ENV SMART_VENC_VERSION="1.0.4"
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
    https://qartifactory-edge.qualcomm.com/artifactory/qsc_releases/software/chip/component/iot-core-algs.lnx.0.0/${SMART_VENC_BUILD_DATE}/prebuilt_trixie/qimsdk-smartvenc_${SMART_VENC_VERSION}_arm64.tar.gz && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar xvf qimsdk-smartvenc_${SMART_VENC_VERSION}_arm64.tar.gz                                 && \
    cp -r qimsdk-smartvenc-${SMART_VENC_VERSION}/libqimsdk-smartvenc1/arm64/usr /               && \
    cp -r qimsdk-smartvenc-${SMART_VENC_VERSION}/libqimsdk-smartvenc-dev/arm64/usr /            && \
    cp -r qimsdk-smartvenc-${SMART_VENC_VERSION}/libqimsdk-smartvenc1/arm64/usr/* ${QIMSDK_INSTALL_LIB_DIR}/ && \
    rm -rf qimsdk-smartvenc-${SMART_VENC_VERSION} qimsdk-smartvenc_*_arm64.tar.gz

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
    cp -r ${QIMSDK_DOWNLOAD_DIR}/fastcv/usr/include/fastcv /usr/include/                        && \
    rm -rf fastcv ${FASTCV_PACKAGE_NAME}_${FASTCV_VERSION}_${FASTCV_ARCH}.tar.gz

# gst-qti-oss-patches: fetch
RUN GST_PLUGINS_BASE_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base*                       \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    mkdir -p ${QIMSDK_SRC_DIR}/gst-qti-oss-patches                                              && \
    git -C ${QIMSDK_SRC_DIR}/gst-qti-oss-patches init                                           && \
    git -C ${QIMSDK_SRC_DIR}/gst-qti-oss-patches                                                   \
            remote add origin https://github.com/qualcomm/gst-qti-oss-patches.git               && \
    git -C ${QIMSDK_SRC_DIR}/gst-qti-oss-patches fetch --depth 1 origin                            \
            ${GST_PLUGINS_BASE_VERSION}                                                         && \
    git -C ${QIMSDK_SRC_DIR}/gst-qti-oss-patches checkout FETCH_HEAD

# qnp-sdk: fetch and copy the needed headers
ARG QIMSDK_ARG_QNP_VERSION
ENV QIMSDK_QNP_VERSION=${QIMSDK_ARG_QNP_VERSION}
RUN [ -z "$QIMSDK_ARG_QNP_VERSION" ]                                                          && { \
        echo "WARN : QIMSDK_ARG_QNP_VERSION is not provided. Skipping QNN installation." >&2;      \
    } || {                                                                                         \
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
        [ ! -d "${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/QAIRT" ]     || \
            cp -rf "${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/QAIRT"      \
            "/usr/include/"                                                                     && \
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
                -name 'libSNPE.so' -o                                                              \
                -name 'libQairtSystem.so' -o                                                       \
                -name 'libQairtDspV66Stub.so' -o                                                   \
                -name 'libQairtHtpV68Stub.so' -o                                                   \
                -name 'libQairtHtpV73Stub.so' -o                                                   \
                -name 'libQairtHtpV75Stub.so' -o                                                   \
                -name 'libQairtHtpPrepare.so' -o                                                   \
                -name 'libQairtHtpBackendExtensions.so' -o                                         \
                -name 'libQairtGpuBackendExtensions.so' -o                                         \
                -name 'libQairtGpu.so' -o                                                          \
                -name 'libQairtDsp.so' -o                                                          \
                -name 'libQairtCpuBackendExtensions.so' -o                                         \
                -name 'libQairtCpu.so' -o                                                          \
                -name 'libQairtHtp.so' -o                                                          \
                -name 'libQairtDspBackendExtensions.so'                                            \
            \)                                                                                     \
            -exec cp -t "${QIMSDK_INSTALL_LIB_DIR}/" {} +;                                         \
    }

# camera-service: fetch
ARG QIMSDK_ARG_CAMERA_SERVICE_TAG
RUN mkdir -p ${QIMSDK_SRC_DIR}/camera-service                                                   && \
    git -C ${QIMSDK_SRC_DIR}/camera-service init                                                && \
    git -C ${QIMSDK_SRC_DIR}/camera-service                                                        \
            remote add origin https://github.com/qualcomm/camera-service.git                    && \
    git -C ${QIMSDK_SRC_DIR}/camera-service fetch --depth 1 origin                                 \
            "${QIMSDK_ARG_CAMERA_SERVICE_TAG:-main}"                                            && \
    git -C ${QIMSDK_SRC_DIR}/camera-service checkout FETCH_HEAD

# qimsdk: fetch
ARG QIMSDK_ARG_GST_PLUGINS_TAG
RUN mkdir -p ${QIMSDK_SRC_DIR}/qimsdk                                                           && \
    git -C ${QIMSDK_SRC_DIR}/qimsdk init                                                        && \
    git -C ${QIMSDK_SRC_DIR}/qimsdk                                                                \
            remote add origin https://github.com/qualcomm/qimsdk.git                            && \
    git -C ${QIMSDK_SRC_DIR}/qimsdk fetch --depth 1 origin                                         \
            "${QIMSDK_ARG_GST_PLUGINS_TAG:-main}"                                               && \
    git -C ${QIMSDK_SRC_DIR}/qimsdk checkout FETCH_HEAD

# solutions-microservices: fetch
ARG QIMSDK_ARG_SOLUTIONS_MICROSERVICES_TAG
RUN mkdir -p ${QIMSDK_SRC_DIR}/solutions-microservices                                          && \
    git -C ${QIMSDK_SRC_DIR}/solutions-microservices init                                       && \
    git -C ${QIMSDK_SRC_DIR}/solutions-microservices                                               \
            remote add origin https://git.codelinaro.org/clo/le/solutions-microservices         && \
    git -C ${QIMSDK_SRC_DIR}/solutions-microservices fetch --depth 1 origin                        \
            "${QIMSDK_ARG_SOLUTIONS_MICROSERVICES_TAG:-iot-solutions.lnx.1.0}"                  && \
    git -C ${QIMSDK_SRC_DIR}/solutions-microservices checkout FETCH_HEAD

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

# Copy deb packages to device image
COPY --from=qimsdk_build /mnt/work/downloads/debs ${QIMSDK_DEB_DIR}

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
#  App Builder SDK (cpp)
#    runtime dependency:          libyaml-cpp0.8
#  WebRTC runtime dependency:     gstreamer1.0-nice
#  Mesa Vulkan drivers:           mesa-vulkan-drivers
RUN apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends           \
            adduser gosu bash-completion nano libhiredis1.1.0 ${QIMSDK_DEB_DIR}/*.deb              \
            gstreamer1.0-tools libgstrtspserver-1.0-0 libopencv-imgproc410 libxv1                  \
            gstreamer1.0-nice libpulse0 librdkafka1 gstreamer1.0-plugins-ugly gir1.2-gst-1.0       \
            libyaml-0-2 mesa-vulkan-drivers libyaml-cpp0.8                                      && \
    apt -y upgrade                                                                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*                                                       && \
    rm -rf ${QIMSDK_DEB_DIR}

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
        echo '  Qualcomm Technologies, Inc. Purwa IoT EVK:';                                       \
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

# Copy /etc directory to device image
COPY --from=qimsdk_build ${QIMSDK_INSTALL_DIR}/etc /etc

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

# QIMSDK Device Image with support for python use-cases
FROM qimsdk_deploy_arm64 AS qimsdk_deploy_py_arm64

# Installing dependencies, needed in order for gst python apps to work runtime:
#  python3 basic dependencies:    python3 python3-pip python3-venv python3-gi pygobject
#  pygobject dependencies:        gobject-introspection libgirepository-2.0-dev libcairo2-dev
#                                 python3-dev libgirepository1.0-dev python3-opencv python3-yaml
#  gstreamer python bindings:     python3-gst-1.0
# NOTE: The reason for installing dev packages (python3-dev, libcairo2-dev, libgirepository1.0-dev)
# is that runtime, when executing the pip install command, the pip install for the PyGObject package
# has a dependency on the pkgconfig files of python, gobject-introspection and cairo. It also has a
# dependency on python.h headers - These are found in these dev packages.
# NOTE: 'python3-gst-1.0' must come from apt and NOT from pip - it is a Debian package name with no
# PyPI equivalent. It provides the gi 'Gst' override module (Gst.Fraction, Gst.ValueArray, the
# buffer.map() tuple return, ...) which plain PyGObject from PyPI does not ship.
RUN apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends           \
            python3 python3-dev python3-pip python3-venv python3-gi gobject-introspection          \
            libgirepository-2.0-dev libcairo2-dev libgirepository1.0-dev python3-gst-1.0           \
            python3-opencv python3-yaml                                                         && \
    apt -y upgrade                                                                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Switch user to create qimsdk user owned python venv
USER qimsdk

# QIMSDK_PYTHON_LOGS_PATH needed for proper operation of the reference python app builder scripts
ENV QIMSDK_PYTHON_LOGS_PATH=/home/qimsdk/Downloads
RUN mkdir -p ${QIMSDK_PYTHON_LOGS_PATH}

# Switch user back to root to resume regular operation
USER root

# Create an image where a detached container can run indefinitely
ENTRYPOINT ["/bin/entrypoint.sh"]

CMD ["/bin/bash"]
