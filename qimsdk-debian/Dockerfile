# QIMSDK Development Image
FROM debian:trixie-slim AS qimsdk-build

# Add deb-src for everything
RUN sed -Ei 's/^Types: deb$/Types: deb deb-src/'  /etc/apt/sources.list.d/debian.sources

# build time dependencies, needed for gst-plugins-imsdk compilation:
# gst-plugins-imsdk is not an apt package, so we need to install its build dependencies manually
#   instead of doing it using 'apt-get build-dep'
#  gst-plugin-mlaconverter:       libeigen3-dev
#  gst-plugin-mlaclassification:  libcairo-dev
#  gst-plugin-mlmetaparser:       libjson-glib-dev
#  gst-plugin-msgbroker:          libmosquitto-dev,
#                                 librdkafka-dev
#  gst-plugin-overlay:            opencl-headers
#  gst-plugin-redissink:          libhiredis-dev
#  gst-plugin-rtspbin:            libgstrtspserver-1.0-dev
#  gst-plugin-restricted-zonedbg: libgstreamer-plugins-bad1.0-dev

# build time dependencies, needed for camera-service compilation:
#  libprotobuf-dev, protobuf-compiler

# Installing dependencies, needed in order for gst plugins to load succesfully runtime:
#  gstreamer base plugins:        gobject-introspection,
#                                 flex,
#                                 bison,
#                                 libglib2.0-0,
#  glimagesink:                   gstreamer1.0-gl,
#                                 gstreamer1.0-plugins-good,
#                                 libgraphene-1.0-dev,
#                                 libgl1,
#                                 libegl1,
#                                 libwayland-egl1,
#                                 libwayland-dev
#  software encoder needed for
#    rtspsrc usecases:            gstreamer1.0-plugins-ugly
#  pulseaudio runtime dependency: pulseaudio

# Installing required apt packages
RUN apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends           \
            git tar unzip ssh rsync bash-completion jq cmake android-tools-adb wget pipx xz-utils  \
            gobject-introspection flex bison locales-all ninja-build gpg                           \
            libeigen3-dev libcairo-dev libjson-glib-dev libmosquitto-dev opencl-headers            \
            libhiredis-dev libgstrtspserver-1.0-dev libgstreamer-plugins-bad1.0-dev                \
            librdkafka-dev libprotobuf-dev protobuf-compiler                                    && \
    apt-get build-dep -y gst-plugins-base1.0 gst-plugins-good1.0                                && \
    apt -y upgrade                                                                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Set base directory
ENV QIMSDK_BASE_DIR=/mnt/work
ENV QIMSDK_TMP_DIR=${QIMSDK_BASE_DIR}/tmp
RUN mkdir -p ${QIMSDK_TMP_DIR}

# Add host-tools directory
ENV QIMSDK_HOST_TOOLS_DIR=${QIMSDK_BASE_DIR}/host-tools

# Add qimsdk install directory
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
ENV QIMSDK_ADSP_DIR=${QIMSDK_INSTALL_DIR}/usr/lib/rfsa/adsp

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

# Update and clean, fetch GStreamer base and good plugins
RUN DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    apt source gst-plugins-base1.0 gst-plugins-good1.0                                          && \
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

# Clone Tensorflow Lite
ENV QIMSDK_TF_LITE_MAJOR="2"
ENV QIMSDK_TF_LITE_MINOR="20"
ENV QIMSDK_TF_LITE_PATCH="0"
ENV QIMSDK_TF_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/tensorflow
RUN git config --global http.postBuffer 157286400                                               && \
    git clone --progress https://github.com/tensorflow/tensorflow.git --single-branch              \
            --branch r${QIMSDK_TF_LITE_MAJOR}.${QIMSDK_TF_LITE_MINOR} ${QIMSDK_TF_SRC_DIR}

# Clone meta-qcom-distro and apply tflite patches for it
ENV QIMSDK_META_QCOM_DISTRO_DIR=${QIMSDK_DOWNLOAD_DIR}/meta-qcom-distro
RUN git clone https://github.com/qualcomm-linux/meta-qcom-distro.git --single-branch --branch main \
            ${QIMSDK_META_QCOM_DISTRO_DIR}                                                      && \
    git -C ${QIMSDK_TF_SRC_DIR} am ${QIMSDK_META_QCOM_DISTRO_DIR}/recipes-ml/tflite/files/tflite/0*

# Clone flatbuffers. Use the exact git tag as specified in tflite dependency
ENV QIMSDK_FLATBUFFERS_24_3_25_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/flatbuffers_24.3.25
ENV QIMSDK_FLATBUFFERS_24_3_25_INSTALL_DIR=${QIMSDK_HOST_TOOLS_DIR}/flatbuffers_24.3.25/usr
RUN QIMSDK_FLATBUFFERS_24_3_25_TAG=$(cat ${QIMSDK_TF_SRC_DIR}/tensorflow/lite/tools/cmake/modules/flatbuffers.cmake | \
            grep GIT_TAG | rev | cut -d ' ' -f 1 | rev)                                         && \
    git clone --progress https://github.com/google/flatbuffers.git                                 \
            --single-branch --branch master ${QIMSDK_FLATBUFFERS_24_3_25_SRC_DIR}               && \
    git -C ${QIMSDK_FLATBUFFERS_24_3_25_SRC_DIR} checkout -b work ${QIMSDK_FLATBUFFERS_24_3_25_TAG}

# Clone abseil-cpp. Use the git tag compatible with tflite 2.20 and lite rt 2.1.2
ENV QIMSDK_ABSEIL_CPP_DIR=${QIMSDK_DOWNLOAD_DIR}/abseil-cpp
RUN QIMSDK_ABSEIL_CPP_TAG=d38452e1ee03523a208362186fd42248ff2609f6                              && \
    git clone --progress https://github.com/abseil/abseil-cpp.git                                  \
            --single-branch --branch lts_2025_08_14 ${QIMSDK_ABSEIL_CPP_DIR}                    && \
    git -C ${QIMSDK_ABSEIL_CPP_DIR} checkout -b work ${QIMSDK_ABSEIL_CPP_TAG}

# Add CMake redirects
COPY cmake ${QIMSDK_DOWNLOAD_DIR}/cmake

# Initialize environment variables
ENV QIMSDK_SRC_DIR=${QIMSDK_BASE_DIR}/src
ENV QIMSDK_PATH_TO_GST_META=${QIMSDK_SRC_DIR}/meta-qti-gst

# media: fetch and propagate needed camera_metadata headers (camera-service dependency)
RUN git clone --progress https://android.googlesource.com/platform/system/media.git                \
        --single-branch --branch main ${QIMSDK_DOWNLOAD_DIR}/media                              && \
    sed -i '\|#include <cutils/compiler\.h>|d'                                                     \
        ${QIMSDK_DOWNLOAD_DIR}/media/camera/include/system/camera_metadata.h                    && \
    sed -i '\|ANDROID_API|d'                                                                       \
        ${QIMSDK_DOWNLOAD_DIR}/media/camera/include/system/camera_metadata.h                    && \
    rsync -a ${QIMSDK_DOWNLOAD_DIR}/media/camera/include/system /usr/include/

# camera-service: fetch
RUN git clone --progress https://github.com/qualcomm/camera-service.git                            \
        --single-branch --branch main ${QIMSDK_SRC_DIR}/camera-service

# meta-qti-gst: fetch
RUN git clone --progress https://git.codelinaro.org/clo/le/meta-qti-gst.git                        \
        --single-branch --branch imsdk.lnx.2.0.0 ${QIMSDK_SRC_DIR}/meta-qti-gst

# qnp-sdk: fetch and copy the needed headers
ARG QIMSDK_ARG_QNP_VERSION
RUN if [ -z "$QIMSDK_ARG_QNP_VERSION" ]; then                                                      \
        echo "WARN : QIMSDK_ARG_QNP_VERSION is not provided. Skipping QNN installation." >&2;      \
    else                                                                                           \
        export QIMSDK_QNP_SDK=v${QIMSDK_ARG_QNP_VERSION}.zip                                    && \
        export QIMSDK_QNN_LIB_PATH=${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_VERSION}/lib/  && \
        wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                  \
        https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/${QIMSDK_ARG_QNP_VERSION}/${QIMSDK_QNP_SDK} && \
        cd ${QIMSDK_DOWNLOAD_DIR}                                                               && \
        unzip ${QIMSDK_QNP_SDK}                                                                 && \
        rm -f ${QIMSDK_QNP_SDK}                                                                 && \
        QIMSDK_ARG_QNP_SDK_VERSION=$(ls qairt)                                                  && \
        cp -r ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/SNPE/*            \
            /usr/include/.                                                                      && \
        cp -r ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/QNN/*             \
            /usr/include/.                                                                      && \
        mkdir -p ${QIMSDK_ADSP_DIR}                                                             && \
        cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v68/unsigned/* ${QIMSDK_ADSP_DIR}/                    && \
        cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v73/unsigned/* ${QIMSDK_ADSP_DIR}/                    && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libhta_hexagon_runtime_qnn.so           \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libhta_hexagon_runtime_snpe.so          \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libPlatformValidatorShared.so           \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnChrometraceProfilingReader.so     \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnCpu.so                            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDspNetRunExtensions.so            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDsp.so                            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGenAiTransformerCpuOpPkg.so       \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGenAiTransformerModel.so          \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGenAiTransformer.so               \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGpuNetRunExtensions.so            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGpuProfilingReader.so             \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGpu.so                            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtaNetRunExtensions.so            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHta.so                            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpNetRunExtensions.so            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpOptraceProfilingReader.so      \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpPrepare.so                     \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpProfilingReader.so             \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtp.so                            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV68CalculatorStub.so           \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV68Stub.so                     \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV73CalculatorStub.so           \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV73Stub.so                     \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnIr.so                             \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnJsonProfilingReader.so            \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnModelDlc.so                       \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnSaver.so                          \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnSystem.so                         \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnTFLiteDelegate.so                 \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHta.so                           \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpPrepare.so                    \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV68CalculatorStub.so          \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV68Stub.so                    \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV73CalculatorStub.so          \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV73Stub.so                    \
            ${QIMSDK_INSTALL_DIR}/usr/lib/                                                      && \
        cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSNPE.so                              \
            ${QIMSDK_INSTALL_DIR}/usr/lib/;                                                        \
    fi

# gst-plugins-imsdk: fetch
RUN git clone --single-branch --branch main https://github.com/qualcomm/gst-plugins-imsdk.git      \
        ${QIMSDK_SRC_DIR}/gst-plugins-imsdk

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
       ${QIMSDK_DOWNLOAD_DIR}/*base1.0-0_1*                                                        \
       ${QIMSDK_DOWNLOAD_DIR}/debs/

# --------------------------------------------------------------------------------------------------

# QIMSDK Device Image
FROM debian:trixie-slim AS qimsdk-deploy

# Set base directory
ENV QIMSDK_BASE_DIR=/mnt/work
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
ENV QIMSDK_DEB_DIR=${QIMSDK_BASE_DIR}/downloads/debs

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
RUN apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends           \
            adduser bash-completion nano libhiredis1.1.0 gstreamer1.0-tools wget                   \
            libgstrtspserver-1.0-0 libopencv-imgproc410 libxv1                                     \
            gstreamer1.0-plugins-good pulseaudio gstreamer1.0-plugins-base librdkafka1             \
            gstreamer1.0-plugins-ugly gir1.2-gst-1.0                                            && \
    apt -y upgrade                                                                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Add QTI PPA and install QTI dependencies
#  gpg curl:                        install PPA
#  firmware-qcom-hlosfw:            qcom firmware
#  linux-firmware:                  linux firmware
#  qcom-fastrpc1:                   fast rpc
#  qcom-libdmabufheap:              dma buf
RUN apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gpg curl             \
            ca-certificates                                                                     && \
    update-ca-certificates                                                                      && \
    install -d -m 0700 /var/lib/apt/gnupg                                                       && \
    install -d -m 0755 /etc/apt/keyrings                                                        && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x33EF0ACBC6FE252590ABBAF21C70EB0C444248D7" | \
            env GNUPGHOME=/var/lib/apt/gnupg gpg --dearmor                                         \
            -o /etc/apt/keyrings/qcom-noble-ppa.gpg                                             && \
    echo "deb [signed-by=/etc/apt/keyrings/qcom-noble-ppa.gpg] https://ppa.launchpadcontent.net/ubuntu-qcom-iot/qcom-noble-ppa/ubuntu noble main" \
            > /etc/apt/sources.list.d/qcom-noble-ppa.list                                       && \
    apt update                                                                                  && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends                          \
            qcom-fastrpc1 qcom-libdmabufheap                                                    && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Create USER and add to video group for accessing v4ls devices
RUN addgroup qcom                                                                               && \
    useradd -s /bin/bash -m -g qcom qimsdk                                                      && \
    usermod -aG video qimsdk                                                                    && \
    usermod -aG kmem qimsdk                                                                     && \
    echo qimsdk:asd | chpasswd

# Increase max number of fd to be opened by one process
RUN ulimit -n 16192

# Copy installed binaries to device image
COPY --from=qimsdk-build ${QIMSDK_INSTALL_DIR}/usr /usr

# Copy deb packages to device image
COPY --from=qimsdk-build /mnt/work/downloads/debs ${QIMSDK_DEB_DIR}

# Install deb packages to deploy image and remove the directory after install
RUN dpkg -i ${QIMSDK_DEB_DIR}/* && rm -rf ${QIMSDK_DEB_DIR}

# Change user to qimsdk
USER qimsdk

# Change workdir to user home
WORKDIR /home/qimsdk

# Add glimagesink exports
ENV DISPLAY=:0

# Add gstreamer exports
ENV GST_DEBUG_NO_COLOR=1
ENV GST_DEBUG=2
ENV GST_PLUGIN_SCANNER="/usr/lib/aarch64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner"
ENV XDG_RUNTIME_DIR="/run/user/1000"
