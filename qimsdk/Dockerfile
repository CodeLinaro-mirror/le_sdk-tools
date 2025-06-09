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
        python3-gst-1.0 python3-wheel ninja-build python3-full pipx flex bison                  && \
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
RUN mkdir -p ${QIMSDK_BUILD_DIR}
RUN mkdir -p ${QIMSDK_LOGS_DIR}

# Add private headers needed compiletime from headers dir
COPY tmp/headers/usr/ /usr/

# Add soft link to woarkaround glibconfig.h file install path
RUN ln -s /usr/lib/aarch64-linux-gnu/glib-2.0/include/glibconfig.h /usr/include/

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

# qnp-sdk: fetch and copy the needed headers
ENV QIMSDK_QNP_VER=2.35.0.250530
ENV QIMSDK_QNP_SDK=v${QIMSDK_QNP_VER}.zip
ENV QIMSDK_QNN_LIB_PATH=${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_QNP_VER}/lib/
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/${QIMSDK_QNP_VER}/${QIMSDK_QNP_SDK} && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    unzip ${QIMSDK_QNP_SDK}                                                                     && \
    rm -f ${QIMSDK_QNP_SDK}                                                                     && \
    QIMSDK_ARG_QNP_SDK_VERSION=$(ls qairt)                                                      && \
    cp -r ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/SNPE/*                \
        ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/QNN/*                   \
        /usr/include/                                                                           && \
    mkdir -p ${QIMSDK_ADSP_DIR}                                                                 && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v66/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v68/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v69/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v73/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v75/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/hexagon-v79/unsigned/* ${QIMSDK_ADSP_DIR}/                        && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libhta_hexagon_runtime_qnn.so               \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libhta_hexagon_runtime_snpe.so              \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libPlatformValidatorShared.so               \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnChrometraceProfilingReader.so         \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnCpu.so                                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDspNetRunExtensions.so                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDsp.so                                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDspV66CalculatorStub.so               \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnDspV66Stub.so                         \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGenAiTransformerCpuOpPkg.so           \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGenAiTransformerModel.so              \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGenAiTransformer.so                   \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGpuNetRunExtensions.so                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGpuProfilingReader.so                 \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnGpu.so                                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtaNetRunExtensions.so                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHta.so                                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpNetRunExtensions.so                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpOptraceProfilingReader.so          \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpPrepare.so                         \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpProfilingReader.so                 \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtp.so                                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV68CalculatorStub.so               \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV68Stub.so                         \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV69CalculatorStub.so               \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV69Stub.so                         \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV73CalculatorStub.so               \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV73Stub.so                         \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV75CalculatorStub.so               \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV75Stub.so                         \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV79CalculatorStub.so               \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnHtpV79Stub.so                         \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnIr.so                                 \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnJsonProfilingReader.so                \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnModelDlc.so                           \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnSaver.so                              \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnSystem.so                             \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libQnnTFLiteDelegate.so                     \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeDspV66Stub.so                        \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHta.so                               \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpPrepare.so                        \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV68CalculatorStub.so              \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV68Stub.so                        \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV73CalculatorStub.so              \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV73Stub.so                        \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV75CalculatorStub.so              \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV75Stub.so                        \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV79CalculatorStub.so              \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSnpeHtpV79Stub.so                        \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    cp ${QIMSDK_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2/libSNPE.so                                  \
        ${QIMSDK_INSTALL_DIR}/usr/lib/                                                          && \
    rm -rf ${QIMSDK_DOWNLOAD_DIR}/qairt

# Add bash aliases file
COPY .bash_aliases /root/.bash_aliases

# Setup patches dir
ENV QIMSDK_PATCHES_DIR=${QIMSDK_BASE_DIR}/tmp/patches
COPY tmp/patches ${QIMSDK_PATCHES_DIR}

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

WORKDIR  ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.33      && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial wayland protocols Commit"

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

WORKDIR ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/gstreamer-1.24.2            && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Gstreamer Commit"

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

WORKDIR ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base-1.24.2     && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Plugins Base Commit"

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

WORKDIR ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.24.2     && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Plugins Good Commit"

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

WORKDIR  ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.24.2      && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Plugins Bad Commit"

# pulseaudio: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        'https://freedesktop.org/software/pulseaudio/releases/pulseaudio-17.0.tar.xz'           && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xfpulseaudio-17.0.tar.xz                                                               && \
    rm -f pulseaudio-17.0.tar.xz*

WORKDIR ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/pulseaudio-17.0             && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Pulse Audio Commit"

# gstd: fetch (hash is for v0.15.0) and install
ENV QIMSDK_GSTD_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/gstd-1.x
RUN git clone https://github.com/RidgeRun/gstd-1.x.git ${QIMSDK_GSTD_SRC_DIR}                   && \
    cd ${QIMSDK_GSTD_SRC_DIR}                                                                   && \
    git checkout a011affa67f240cbc7aaff5b00fdfd6124bdaece

WORKDIR ${QIMSDK_DOWNLOAD_DIR}
RUN git clone https://github.com/abseil/abseil-cpp.git                                          && \
    cd abseil-cpp && mkdir -p build && cd build                                                 && \
    cmake .. && cmake --build . -j7 && cmake --install .                                        && \
    cd ${QIMSDK_DOWNLOAD_DIR} && rm -rf abseil-cpp

# Add Source Code
ENV QIMSDK_SRC_DIR=${QIMSDK_BASE_DIR}/src
RUN mkdir -p ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss
COPY tmp/gst-plugins-qti-oss ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss

RUN mkdir -p ${QIMSDK_SRC_DIR}/le-services
COPY tmp/le-services ${QIMSDK_SRC_DIR}/le-services

RUN mkdir -p ${QIMSDK_SRC_DIR}/solutions-microservices
COPY tmp/solutions-microservices ${QIMSDK_SRC_DIR}/solutions-microservices

# Add development image scripts
ENV QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/tmp/scripts/
COPY scripts/dev_image ${QIMSDK_SCRIPTS}
COPY tmp/build_plugins.sh ${QIMSDK_SCRIPTS}

# Copy the Tensorflow Lite's headers and dependent headers to the sysroot
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-copy-tf-lite-headers-to-sysroot

# Add json file with content of cmake flags
ENV QIMSDK_RECIPES_PATCHES_DIR=${QIMSDK_BASE_DIR}/tmp/recipes_patches/
COPY tmp/recipes_patches.json ${QIMSDK_RECIPES_PATCHES_DIR}
ENV QIMSDK_RECIPES_JSON=${QIMSDK_RECIPES_PATCHES_DIR}/recipes_patches.json

# Change workdir back to base dir from downloads dir
WORKDIR ${QIMSDK_BASE_DIR}

# Call wrapper function to apply all patches
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-apply-patches

# Setup pkg-config dir
ENV QIMSDK_PKGCONFIG_DIR=/usr/lib/pkgconfig/
COPY tmp/lib/pkgconfig/*.pc ${QIMSDK_PKGCONFIG_DIR}

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
        libopencv-highgui406t64                                                                 && \
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
COPY --from=qimsdk_dev_image                                                                       \
    ${QIMSDK_BASE_DIR}/src/gst-plugins-qti-oss/gst-plugin-tools/gst-scripts/demo_setup_wizard.sh   \
    /usr/bin

# Copy qimsdk microservices shell scripts
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/ai/24-stream-ai-concurrency/qimsdk_24_stream_ai_concurrency.sh \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/ai/access-control/qimsdk_access_control.sh  \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/ai/daisy-chain/qimsdk_daisy_chain.sh        \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/ai/person-detect/qimsdk_person_detect.sh    \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/ai/ppe/qimsdk_ppe.sh                        \
        /usr/bin/
COPY --from=qimsdk_dev_image --chmod=755                                                           \
        ${QIMSDK_BASE_DIR}/src/solutions-microservices/ai/rz/qimsdk_restricted_zone.sh             \
        /usr/bin/

# Add json file with content of runtime flags
ENV QIMSDK_RUNTIME_FLAGS_DIR=/opt/qti/runtime_flags/
RUN mkdir -p ${QIMSDK_RUNTIME_FLAGS_DIR}

COPY --chmod=644 tmp/*runtime_flags.json ${QIMSDK_RUNTIME_FLAGS_DIR}

# Temporary: Resolve mismatching versioned libs versions
RUN ln -s /usr/lib/libadreno_utils.so.1 /usr/lib/libadreno_utils.so.
RUN ln -s /usr/lib/libadreno_utils.so.1 /usr/lib/libadreno_utils.so
RUN ln -s /usr/lib/libcamera_metadata.so /usr/lib/libcamera_metadata.so.0

# Change user to qimsdk
USER qimsdk

# Change workdir to user home
WORKDIR /home/qimsdk
