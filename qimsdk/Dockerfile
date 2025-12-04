# QIMSDK Development Image
FROM --platform=arm64 ubuntu:24.04 AS qimsdk_dev_image

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Set base directory
ARG QIMSDK_ARG_BASE_DIR
ENV QIMSDK_BASE_DIR=${QIMSDK_ARG_BASE_DIR}

# Installing required apt packages
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y                               \
        git tar unzip ssh rsync bash-completion jq cmake android-tools-adb                         \
        libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev       \
        gettext libdaemon-dev libjansson-dev libreadline-dev protobuf-compiler libcairo2-dev       \
        libgstrtspserver-1.0-dev libgirepository1.0-dev opencl-headers libjson-glib-dev            \
        libsoup-3.0-dev libedit-dev libhiredis-dev libeigen3-dev libltdl-dev libsndfile1-dev       \
        libxtst-dev libmosquitto-dev libxml-parser-perl python3 python3-pip python3-setuptools     \
        python3-gst-1.0 python3-wheel ninja-build python3-full pipx flex bison librdkafka-dev   && \
        pipx ensurepath                                                                         && \
        pipx install meson                                                                      && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Propagate proxy to dev container
ARG QIMSDK_ARG_HTTP_PROXY
ENV http_proxy=${QIMSDK_ARG_HTTP_PROXY}

ARG QIMSDK_ARG_HTTPS_PROXY
ENV https_proxy=${QIMSDK_ARG_HTTPS_PROXY}

ARG QIMSDK_ARG_NO_PROXY
ENV no_proxy=${QIMSDK_ARG_NO_PROXY}

# Add meson install location to PATH
ENV PATH="${PATH}:/root/.local/bin"

# Add root to plugdev group
RUN usermod -aG plugdev root

# Add qimsdk install directory
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
ENV QIMSDK_ADSP_DIR=${QIMSDK_INSTALL_DIR}/usr/lib/rfsa/adsp

# Add qimsdk debug install directory
ENV QIMSDK_INSTALL_DEBUG_DIR=${QIMSDK_BASE_DIR}/deploy_dbg

# Add qimsdk build directory and logs directory
ENV QIMSDK_BUILD_DIR=${QIMSDK_BASE_DIR}/build
ENV QIMSDK_LOGS_DIR=${QIMSDK_BASE_DIR}/logs
ENV QIMSDK_TMP_DIR=${QIMSDK_BASE_DIR}/tmp
RUN mkdir -p ${QIMSDK_BUILD_DIR}
RUN mkdir -p ${QIMSDK_LOGS_DIR}
RUN mkdir -p ${QIMSDK_TMP_DIR}

ARG QIMSDK_ARG_SUPPORTED_TARGETS

# Initialize environment variables
ENV QIMSDK_SUPPORTED_TARGETS=${QIMSDK_ARG_SUPPORTED_TARGETS}
ENV QIMSDK_PATCHES_DIR=${QIMSDK_TMP_DIR}/patches
ENV QIMSDK_RECIPES_PATCHES_DIR=${QIMSDK_TMP_DIR}/recipes_patches/
ENV QIMSDK_RECIPES_JSON=${QIMSDK_RECIPES_PATCHES_DIR}/recipes_patches.json
ENV QIMSDK_SRC_DIR=${QIMSDK_BASE_DIR}/src
ENV QIMSDK_PKGCONFIG_DIR=/usr/lib/pkgconfig/

# Declare qimsdk variables for path to patches
ENV QIMSDK_PATH_TO_GST_META="${QIMSDK_TMP_DIR}/meta-qti-gst"
ENV QIMSDK_PATH_TO_WAYLAND_PATCHES=""
ENV QIMSDK_PATH_TO_GSTREAMER_PATCHES=""
ENV QIMSDK_PATH_TO_GST_PLUGINS_BASE_PATCHES=""
ENV QIMSDK_PATH_TO_GST_PLUGINS_GOOD_PATCHES=""
ENV QIMSDK_PATH_TO_GST_PLUGINS_BAD_PATCHES=""
ENV QIMSDK_PATH_TO_PULSEAUDIO_META=""
ENV QIMSDK_PATH_TO_PULSEAUDIO=""
ENV QIMSDK_PATH_TO_GSTD_PATCHES=""

# Clone yocto poky project
RUN git -C ${QIMSDK_TMP_DIR} clone https://git.yoctoproject.org/poky                               \
            --single-branch --branch scarthgap                                                  && \
    git -C ${QIMSDK_TMP_DIR} clone https://github.com/qualcomm-linux/meta-qcom-hwe                 \
            --single-branch --branch scarthgap                                                  && \
    git -C ${QIMSDK_TMP_DIR} clone https://github.com/qualcomm-linux/meta-qcom-qim-product-sdk     \
            --single-branch --branch scarthgap

# Set up download directory
ENV QIMSDK_DOWNLOAD_DIR=${QIMSDK_BASE_DIR}/downloads
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}

# Clone Tensorflow Lite; checkout hash is for v2.15.1
ENV QIMSDK_TF_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/tensorflow
RUN git config --global http.postBuffer 157286400                                               && \
    git clone --progress https://github.com/tensorflow/tensorflow.git                              \
        --single-branch --branch r2.15 ${QIMSDK_TF_SRC_DIR}                                     && \
    cd ${QIMSDK_TF_SRC_DIR}                                                                     && \
    git checkout 63f5a65c7cd7b6241bede8d2e0082058566ea364

# qairt-sdk: fetch and copy the needed headers
ARG QIMSDK_ARG_QAIRT_SDK_VERSION
ENV QIMSDK_QAIRT_VER=${QIMSDK_ARG_QAIRT_SDK_VERSION}
ENV QIMSDK_QAIRT_SDK=v${QIMSDK_QAIRT_VER}.zip
ENV QIMSDK_QNN_LIB_PATH=${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_QAIRT_VER}/lib/
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/${QIMSDK_QAIRT_VER}/${QIMSDK_QAIRT_SDK} && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    unzip ${QIMSDK_QAIRT_SDK}                                                                   && \
    rm -f ${QIMSDK_QAIRT_SDK}                                                                   && \
    QIMSDK_ARG_QAIRT_SDK_VERSION=$(ls qairt)                                                    && \
    cp -r ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QAIRT_SDK_VERSION}/include/SNPE/*              \
        ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QAIRT_SDK_VERSION}/include/QNN/*                 \
        /usr/include/                                                                           && \
    mkdir -p ${QIMSDK_ADSP_DIR}                                                                 && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v66/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v68/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v69/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v73/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v75/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v79/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp -r ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libhta_hexagon_runtime_snpe.so           \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeDspV66Stub.so                       \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHta.so                              \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpPrepare.so                       \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV68CalculatorStub.so             \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV68Stub.so                       \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV73CalculatorStub.so             \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV73Stub.so                       \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV75CalculatorStub.so             \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV75Stub.so                       \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV79CalculatorStub.so             \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV79Stub.so                       \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSNPE.so                                 \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libhta_hexagon_runtime_qnn.so              \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libPlatformValidatorShared.so              \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnChrometraceProfilingReader.so        \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnCpu.so                               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDspNetRunExtensions.so               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDsp.so                               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDspV66CalculatorStub.so              \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDspV66Stub.so                        \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGenAiTransformerCpuOpPkg.so          \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGenAiTransformerModel.so             \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGenAiTransformer.so                  \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGpuNetRunExtensions.so               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGpuProfilingReader.so                \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGpu.so                               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtaNetRunExtensions.so               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHta.so                               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpNetRunExtensions.so               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpOptraceProfilingReader.so         \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpPrepare.so                        \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpProfilingReader.so                \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtp.so                               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV68CalculatorStub.so              \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV68Stub.so                        \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV69CalculatorStub.so              \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV69Stub.so                        \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV73CalculatorStub.so              \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV73Stub.so                        \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV75CalculatorStub.so              \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV75Stub.so                        \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV79CalculatorStub.so              \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV79Stub.so                        \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnIr.so                                \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnJsonProfilingReader.so               \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnModelDlc.so                          \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnSaver.so                             \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnSystem.so                            \
        ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnTFLiteDelegate.so                    \
        ${QIMSDK_INSTALL_DIR}/usr/lib/.                                                         && \
    rm -rf ${QIMSDK_DOWNLOAD_DIR}/qairt

# wayland-protocols: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        'https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.33/downloads/wayland-protocols-1.33.tar.xz' && \
    wget -t 2 -T 30  -P ${QIMSDK_DOWNLOAD_DIR}                                                     \
        'https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.33/downloads/wayland-protocols-1.33.tar.xz.sig' && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys                                        \
        A66D805F7C9329B4C5D82767CCC4F07FAC641EFF                                                && \
    gpg --fingerprint A66D805F7C9329B4C5D82767CCC4F07FAC641EFF                                  && \
    gpg --verify ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33.tar.xz.sig                          \
        ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33.tar.xz                                    && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xf wayland-protocols-1.33.tar.xz                                                       && \
    gpg --batch --delete-key A66D805F7C9329B4C5D82767CCC4F07FAC641EFF                           && \
    rm -f wayland-protocols-1.33.tar.xz*

RUN git -C ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33                                           \
        init                                                                                    && \
    git config --global --add safe.directory                                                       \
        ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33                                           && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33                                           \
        config --global user.name "username"                                                    && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33                                           \
        config --global user.email "email"                                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33                                           \
        add --all                                                                               && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33                                           \
        commit -m "Initial wayland protocols Commit"

#Set locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# gstreamer: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        'https://gstreamer.freedesktop.org/src/gstreamer/gstreamer-1.24.2.tar.xz'               && \
    wget -t 2 -T 30  -P ${QIMSDK_DOWNLOAD_DIR}                                                     \
        'https://gstreamer.freedesktop.org/src/gstreamer/gstreamer-1.24.2.tar.xz.asc'           && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys                                        \
        D637032E45B8C6585B9456565D2EEE6F6F349D7C                                                && \
    gpg --fingerprint D637032E45B8C6585B9456565D2EEE6F6F349D7C                                  && \
    gpg --verify ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2.tar.xz.asc                                \
        ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2.tar.xz                                          && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xf gstreamer-1.24.2.tar.xz                                                             && \
    gpg --batch --delete-key D637032E45B8C6585B9456565D2EEE6F6F349D7C                           && \
    rm -f gstreamer-1.24.2.tar.xz*

RUN git -C ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2                                                 \
        init                                                                                    && \
    git config --global --add safe.directory                                                       \
        ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2                                                 && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2                                                 \
        config --global user.name "username"                                                    && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2                                                 \
        config --global user.email "email"                                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2                                                 \
        add --all                                                                               && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2                                                 \
        commit -m "Initial Gstreamer Commit"

# gst-plugins-base: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
    'https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.24.2.tar.xz'     && \
    wget -t 2 -T 30  -P ${QIMSDK_DOWNLOAD_DIR}                                                     \
    'https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.24.2.tar.xz.asc' && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys                                        \
    D637032E45B8C6585B9456565D2EEE6F6F349D7C                                                    && \
    gpg --fingerprint D637032E45B8C6585B9456565D2EEE6F6F349D7C                                  && \
    gpg --verify ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2.tar.xz.asc                         \
        ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2.tar.xz                                   && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xf gst-plugins-base-1.24.2.tar.xz                                                      && \
    gpg --batch --delete-key D637032E45B8C6585B9456565D2EEE6F6F349D7C                           && \
    rm -f gst-plugins-base-1.24.2.tar.xz*

RUN git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2                                          \
        init                                                                                    && \
    git config --global --add safe.directory                                                       \
        ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2                                          && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2                                          \
        config --global user.name "username"                                                    && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2                                          \
        config --global user.email "email"                                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2                                          \
        add --all                                                                               && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2                                          \
        commit -m "Initial Plugins Base Commit"

# gst-plugins-good: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        'https://gstreamer.freedesktop.org/src/gst-plugins-good/gst-plugins-good-1.24.2.tar.xz' && \
    wget -t 2 -T 30  -P ${QIMSDK_DOWNLOAD_DIR}                                                     \
        'https://gstreamer.freedesktop.org/src/gst-plugins-good/gst-plugins-good-1.24.2.tar.xz.asc' && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys                                        \
        D637032E45B8C6585B9456565D2EEE6F6F349D7C                                                && \
    gpg --fingerprint D637032E45B8C6585B9456565D2EEE6F6F349D7C                                  && \
    gpg --verify ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2.tar.xz.asc                         \
        ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2.tar.xz                                   && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xf gst-plugins-good-1.24.2.tar.xz                                                      && \
    gpg --batch --delete-key D637032E45B8C6585B9456565D2EEE6F6F349D7C                           && \
    rm -f gst-plugins-good-1.24.2.tar.xz*

RUN git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2                                          \
        init                                                                                    && \
    git config --global --add safe.directory                                                       \
        ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2                                          && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2                                          \
        config --global user.name "username"                                                    && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2                                          \
        config --global user.email "email"                                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2                                          \
        add --all                                                                               && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2                                          \
        commit -m "Initial Plugins Good Commit"

# gst-plugins-bad: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        'https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-1.24.2.tar.xz'   && \
    wget -t 2 -T 30  -P ${QIMSDK_DOWNLOAD_DIR}                                                     \
        'https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-1.24.2.tar.xz.asc' && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys                                        \
        D637032E45B8C6585B9456565D2EEE6F6F349D7C                                                && \
    gpg --fingerprint D637032E45B8C6585B9456565D2EEE6F6F349D7C                                  && \
    gpg --verify ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2.tar.xz.asc                          \
        ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2.tar.xz                                    && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xf gst-plugins-bad-1.24.2.tar.xz                                                       && \
    gpg --batch --delete-key D637032E45B8C6585B9456565D2EEE6F6F349D7C                           && \
    rm -f gst-plugins-bad-1.24.2.tar.xz*

RUN git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2                                           \
        init                                                                                    && \
    git config --global --add safe.directory                                                       \
        ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2                                           && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2                                           \
        config --global user.name "username"                                                    && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2                                           \
        config --global user.email "email"                                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2                                           \
        add --all                                                                               && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2                                           \
        commit -m "Initial Plugins Bad Commit"

# pulseaudio: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        'https://freedesktop.org/software/pulseaudio/releases/pulseaudio-17.0.tar.xz'           && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xfpulseaudio-17.0.tar.xz                                                               && \
    rm -f pulseaudio-17.0.tar.xz*

RUN git -C ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0                                                  \
        init                                                                                    && \
    git config --global --add safe.directory                                                       \
        ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0                                                  && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0                                                  \
        config --global user.name "username"                                                    && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0                                                  \
        config --global user.email "email"                                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0                                                  \
        add --all                                                                               && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0                                                  \
        commit -m "Initial Pulse Audio Commit"

# gstd: fetch (hash is for v0.15.0) and install
ENV QIMSDK_GSTD_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/gstd-1.x
RUN git clone https://github.com/RidgeRun/gstd-1.x.git ${QIMSDK_GSTD_SRC_DIR}                   && \
    cd ${QIMSDK_GSTD_SRC_DIR}                                                                   && \
    git checkout a011affa67f240cbc7aaff5b00fdfd6124bdaece

# abseil-cpp as dependency of TfLite: download the source, configure, compile, install and remove
RUN git -C ${QIMSDK_DOWNLOAD_DIR} clone https://github.com/abseil/abseil-cpp.git                && \
    cd ${QIMSDK_DOWNLOAD_DIR}/abseil-cpp && mkdir -p build && cd build                          && \
    cmake .. && cmake --build . -j && cmake --install .                                         && \
    cd ${QIMSDK_DOWNLOAD_DIR} && rm -rf abseil-cpp

# Add soft link to woarkaround glibconfig.h file install path
RUN ln -s /usr/lib/aarch64-linux-gnu/glib-2.0/include/glibconfig.h /usr/include/

# Add bash aliases file
COPY .bash_aliases /root/.bash_aliases

# Add whole content of tmp dir
COPY tmp ${QIMSDK_TMP_DIR}

# Add supported targets' json files
COPY targets ${QIMSDK_TMP_DIR}/targets

# Add development image scripts
ENV QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/scripts/
COPY scripts/dev_image ${QIMSDK_SCRIPTS}

# Add Recipe Parser
ENV QIMSDK_TOOLS=${QIMSDK_TMP_DIR}/tools/
COPY scripts/tools/RecipeParser.py ${QIMSDK_TOOLS}/RecipeParser.py

# Invoke Recipe Parser script
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-invoke-recipe-parser

# Propagate packages and sources
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-propagate-packages-and-sources

# Copy the Tensorflow Lite's headers and dependent headers to the sysroot
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-copy-tf-lite-headers-to-sysroot

# Change workdir back to base dir from downloads dir
WORKDIR ${QIMSDK_BASE_DIR}

# Propagate paths to patch files and call wrapper function to apply all patches
RUN bash -c 'source ${QIMSDK_SCRIPTS}/env_setup.sh                                              && \
        qimsdk-propagate-path-to-patches                                                        && \
        qimsdk-apply-patches'

# Call wrapper build function to compile and install gst plugins
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-incremental-build

# Set artifacts save Docker_image_path
ARG QIMSDK_ARG_DOCKER_IMAGE_PATH
ENV QIMSDK_DOCKER_IMAGE_PATH=${QIMSDK_ARG_DOCKER_IMAGE_PATH}

# Set artifacts push device id
ARG QIMSDK_ARG_DEVICE_ID
ENV QIMSDK_DEVICE_ID=${QIMSDK_ARG_DEVICE_ID}

# Set device container name
ARG QIMSDK_ARG_CONTAINER_NAME
ENV QIMSDK_CONTAINER_NAME=${QIMSDK_ARG_CONTAINER_NAME}

# # # # # # # # # # # # # # #

# QIMSDK Device Image
FROM --platform=arm64 ubuntu:24.04 AS qimsdk_device_image

# Set base directory
ARG QIMSDK_ARG_BASE_DIR
ENV QIMSDK_BASE_DIR=${QIMSDK_ARG_BASE_DIR}

# Add jammy suites to downgrade gstreamer1.0 version
RUN sed -i 's/noble noble-updates noble-backports/noble noble-updates noble-backports jammy jammy-updates/g' /etc/apt/sources.list.d/ubuntu.sources

# Installing required apt packages
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y bash-completion               \
        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-tools                      \
        gstreamer1.0-plugins-base-apps libgstrtspserver-1.0-0 gstreamer1.0-nice libhiredis1.1.0    \
        python3 python3-gst-1.0 libjpeg62 libprotobuf32t64 libdaemon0 mosquitto                    \
        libopencv-imgproc406t64 libopencv-calib3d406t64 libopencv-imgcodecs406t64                  \
        libopencv-highgui406t64 librdkafka1                                                     && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Link needed versions of rvsdk dependencies
RUN ln -s /usr/lib/aarch64-linux-gnu/libopencv_core.so.4.6.0                                       \
        /usr/lib/libopencv_core.so.405                                                          && \
    ln -s /usr/lib/aarch64-linux-gnu/libopencv_imgproc.so.4.6.0                                    \
        /usr/lib/libopencv_imgproc.so.405                                                       && \
    ln -s /usr/lib/aarch64-linux-gnu/libopencv_calib3d.so.4.6.0                                    \
            /usr/lib/libopencv_calib3d.so.405                                                   && \
    ln -s /usr/lib/aarch64-linux-gnu/libopencv_imgcodecs.so.4.6.0                                  \
        /usr/lib/libopencv_imgcodecs.so.405                                                     && \
    ln -s /usr/lib/aarch64-linux-gnu/libopencv_highgui.so.4.6.0                                    \
        /usr/lib/libopencv_highgui.so.405

# Link to the gbm and msm_gbm libraries and dependent xml file
RUN ln -s /usr/lib/libgbm.so.1                                                                     \
        /usr/lib/libgbm.so                                                                      && \
    mkdir -p /usr/lib/aarch64-linux-gnu/gbm/                                                    && \
    ln -s /usr/lib/gbm/msm_gbm.so                                                                  \
        /usr/lib/aarch64-linux-gnu/gbm/msm_gbm.so                                               && \
    ln -s /usr/lib/gbm/default_fmt_alignment.xml                                                   \
        /usr/lib/aarch64-linux-gnu/gbm/default_fmt_alignment.xml

# Create USER and add to video group for accessing v4ls devices
RUN addgroup qcom                                                                               && \
    useradd -s /bin/bash -m -g qcom qimsdk                                                      && \
    usermod -aG video qimsdk                                                                    && \
    usermod -aG kmem qimsdk                                                                     && \
    echo qimsdk:asd | chpasswd

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /home/qimsdk/.bashrc

# Increase max number of fd to be opened by one process
RUN ulimit -n 16192

# Copy installed binaries to device image
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
COPY --from=qimsdk_dev_image ${QIMSDK_INSTALL_DIR}/usr /usr
COPY --from=qimsdk_dev_image ${QIMSDK_INSTALL_DIR}/etc/configs /etc/configs

# Copy python examples
COPY --from=qimsdk_dev_image ${QIMSDK_BASE_DIR}/src/gst-plugins-qti-oss/gst-python-examples /usr/bin

# Copy wizard script
COPY --from=qimsdk_dev_image --chmod=755                                                           \
    ${QIMSDK_BASE_DIR}/src/gst-plugins-qti-oss/gst-plugin-tools/gst-scripts/demo_setup_wizard.sh   \
    /usr/bin

# Copy qimsdk microservices shell scripts
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/pipelines/24-stream-ai-concurrency/qimsdk_24_stream_ai_concurrency.sh \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/pipelines/access-control/qimsdk_access_control.sh  \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/pipelines/daisy-chain/qimsdk_daisy_chain.sh        \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/pipelines/person-detect/qimsdk_person_detect.sh    \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/pipelines/ppe/qimsdk_ppe.sh                        \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/pipelines/rz/qimsdk_restricted_zone.sh             \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/pipelines/fire-smoke-detect/qimsdk_fire_smoke_detect.sh  \
        /usr/bin/

# Add json file with content of runtime flags
ENV QIMSDK_RUNTIME_FLAGS_DIR=/opt/qti/runtime_flags/
RUN mkdir -p ${QIMSDK_RUNTIME_FLAGS_DIR}

COPY --chmod=644 tmp/*runtime_flags.json ${QIMSDK_RUNTIME_FLAGS_DIR}

# Add compare python scripts to the qimsdk device image,
# and append to .bashrc to check for detecting whether mounted libs.
COPY scripts/tools/compare.py /opt/qti/compare.py
RUN echo 'python3 /opt/qti/compare.py' >> /home/qimsdk/.bashrc

# Temporary: Resolve mismatching versioned libs versions
RUN ln -s /usr/lib/libadreno_utils.so.1 /usr/lib/libadreno_utils.so.
RUN ln -s /usr/lib/libadreno_utils.so.1 /usr/lib/libadreno_utils.so
RUN ln -s /usr/lib/libcamera_metadata.so /usr/lib/libcamera_metadata.so.0
RUN ln -s /usr/lib/libOpenCL.so.1 /usr/lib/libOpenCL.so
RUN ln -s /usr/lib/libOpenCL_adreno.so.1 /usr/lib/libOpenCL_adreno.so
RUN ln -s /usr/lib/libq3dtools_adreno.so.1 /usr/lib/libq3dtools_adreno.so
RUN ln -s /usr/lib/libvulkan_adreno.so.1 /usr/lib/libvulkan_adreno.so
RUN ln -s /usr/lib/libGLESv2_adreno.so.2 /usr/lib/libGLESv2_adreno.so
RUN ln -s /usr/lib/libEGL.so.1 /usr/lib/libEGL.so
RUN ln -s /usr/lib/libEGL_adreno.so.1 /usr/lib/libEGL_adreno.so
RUN ln -s /usr/lib/libtensorflowlite_c.so /usr/lib/libtensorflowlite_c.so.2
RUN ln -s /usr/lib/libtensorflowlite_c.so /usr/lib/libtensorflowlite_c.so.2.16.1

# Eliminate redundant libraries in /usr/lib/aarch64-linux-gnu
# that are already mapped or available through the platform's default library paths.
RUN rm /usr/lib/aarch64-linux-gnu/libEGL.so.1*
RUN rm /usr/lib/aarch64-linux-gnu/libGLESv2.so.2*
RUN rm /usr/lib/aarch64-linux-gnu/libOpenCL.so.1
RUN rm /usr/lib/aarch64-linux-gnu/libgbm.so*
RUN rm /usr/lib/aarch64-linux-gnu/libwayland-client.so.0
RUN rm /usr/lib/aarch64-linux-gnu/libwayland-egl.so.1

# Change user to qimsdk
USER qimsdk

# Change workdir to user home
WORKDIR /home/qimsdk
