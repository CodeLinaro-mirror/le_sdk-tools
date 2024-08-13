# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Define build args
ARG TFLITE_ARG_OS

# Target tflite-tools-common
FROM ubuntu:bionic AS tflite-tools-common

# Input arguments
ARG TFLITE_ARG_RSYNC_DST
ARG TFLITE_ARG_SDK_ENV_SETUP_SCRIPT
ARG TFLITE_ARG_NUM_CPU
ARG TFLITE_ARG_DEVICE_INSTALL_PREFIX
ENV TFLITE_DEVICE_INSTALL_PREFIX=${TFLITE_ARG_DEVICE_INSTALL_PREFIX}
ARG TFLITE_ARG_TARGET_SYS
ENV TFLITE_TARGET_SYS=${TFLITE_ARG_TARGET_SYS}
ENV TFLITE_RSYNC_DST=${TFLITE_ARG_RSYNC_DST}

# Set base folder
ARG TFLITE_ARG_BASE_DIR
ENV TFLITE_BASE_DIR=${TFLITE_ARG_BASE_DIR}
RUN mkdir -p ${TFLITE_ARG_BASE_DIR}

# Create directories
ENV TFLITE_DEPLOY_DIR=${TFLITE_ARG_BASE_DIR}/deploy
RUN mkdir -p ${TFLITE_DEPLOY_DIR}

ENV TFLITE_DEPLOY_DBG_DIR=${TFLITE_ARG_BASE_DIR}/deploy_dbg
ENV TFLITE_DEPLOY_DEV_DIR=${TFLITE_ARG_BASE_DIR}/deploy_dev
ENV TFLITE_PKG_DIR=${TFLITE_ARG_BASE_DIR}/tflite_pkg
RUN mkdir -p ${TFLITE_PKG_DIR}

ENV TFLITE_ROOT_BUILD_DIR=${TFLITE_ARG_BASE_DIR}/build
ENV TFLITE_DOWNLOAD_DIR=${TFLITE_ARG_BASE_DIR}/download

# Installing required packages
RUN apt-get update                                                                              && \
    apt-get install -y curl wget git xz-utils zip unzip build-essential libncurses5 python3 sudo   \
        rsync file android-tools-adb procps gcc-aarch64-linux-gnu g++-aarch64-linux-gnu         && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Download additional external dependencies
WORKDIR "${TFLITE_DOWNLOAD_DIR}"

# Get CMAKE binaries
RUN wget --quiet https://github.com/Kitware/CMake/releases/download/v3.20.2/cmake-3.20.2-linux-x86_64.tar.gz && \
    tar -zxf cmake-3.20.2-linux-x86_64.tar.gz                                                   && \
    cp -r cmake-3.20.2-linux-x86_64/bin/* /usr/local/bin/                                       && \
    cp -r cmake-3.20.2-linux-x86_64/share/* /usr/local/share/                                   && \
    rm -rf cmake*

#---------------------------------------------------------------------------------------------------

# Target tflite-tools-common-le
FROM tflite-tools-common AS tflite-tools-common-le
RUN mkdir -p ${TFLITE_DEPLOY_DBG_DIR}/usr/lib/

# Add SDK
ENV TFLITE_SDK_BASE_DIR=${TFLITE_BASE_DIR}/sdk
RUN mkdir -p ${TFLITE_SDK_BASE_DIR}
ADD tmp/sdk.sh ${TFLITE_SDK_BASE_DIR}/sdk.sh

# Setup SDK as HOST user
RUN chmod ug+x ${TFLITE_SDK_BASE_DIR}/sdk.sh
RUN umask 022
RUN ${TFLITE_SDK_BASE_DIR}/sdk.sh -y -d ${TFLITE_SDK_BASE_DIR}
RUN rm -rf ${TFLITE_SDK_BASE_DIR}/sdk.sh

ENV TFLITE_SDK_ENV_SETUP_SCRIPT=${TFLITE_ARG_SDK_ENV_SETUP_SCRIPT}

# Get Protoc binary and Protobuf dependencies
RUN wget --quiet https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/protobuf-cpp-3.17.3.tar.gz && \
    tar xf protobuf-cpp-3.17.3.tar.gz                                                           && \
    cd protobuf-3.17.3                                                                          && \
    mkdir x86_64_build                                                                          && \
    cd x86_64_build/                                                                            && \
    ../configure --disable-shared --prefix=${PWD}/x86_64_pb_install                             && \
    make -j${TFLITE_ARG_NUM_CPU} install                                                        && \
    . ${TFLITE_SDK_BASE_DIR}/${TFLITE_SDK_ENV_SETUP_SCRIPT}                                     && \
    cp x86_64_pb_install/bin/protoc ${OECORE_NATIVE_SYSROOT}/usr/bin/                           && \
    cp x86_64_pb_install/lib/libprotobuf.a ${OECORE_NATIVE_SYSROOT}/usr/lib/                    && \
    cp -r x86_64_pb_install/include/google ${OECORE_NATIVE_SYSROOT}/usr/include                 && \
    cd ../                                                                                      && \
    mkdir arm64_build                                                                           && \
    cd arm64_build/                                                                             && \
    ../configure --disable-shared --with-pic --prefix=${PWD}/arm64_pb_install --host=aarch64-linux --with-protoc=${OECORE_NATIVE_SYSROOT}/usr/bin/protoc ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu && \
    make -j${TFLITE_ARG_NUM_CPU} install                                                        && \
    cp arm64_pb_install/lib/libprotobuf.a ${SDKTARGETSYSROOT}/usr/lib/                          && \
    mkdir -p ${SDKTARGETSYSROOT}/usr/include                                                    && \
    cp -r arm64_pb_install/include/* ${SDKTARGETSYSROOT}/usr/include/                           && \
    cd ../../                                                                                   && \
    rm -rf protobuf*

# Get JPEG library and headers
RUN . ${TFLITE_SDK_BASE_DIR}/${TFLITE_SDK_ENV_SETUP_SCRIPT}                                     && \
    TFLITE_TARGET=$(echo ${TARGET_PREFIX} | rev | cut -c2- | rev)                               && \
    echo ${TFLITE_TARGET} | grep 'gnu' || TFLITE_TARGET=""                                      && \
    wget --quiet --output-document libjpeg-2.0.90.tar.xz https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/2.0.90.tar.gz && \
    tar xf libjpeg-2.0.90.tar.xz                                                                && \
    cd libjpeg-turbo-2.0.90/                                                                    && \
    cmake -DCMAKE_TOOLCHAIN_FILE=${OE_CMAKE_TOOLCHAIN_FILE}                                        \
        -DCMAKE_INSTALL_DEFAULT_PREFIX=${PWD}/install_dir                                          \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON                                                       \
        -DWITH_TURBOJPEG=FALSE                                                                     \
        -DENABLE_SHARED=FALSE .                                                                 && \
    make -j${TFLITE_ARG_NUM_CPU}                                                                && \
    make -j${TFLITE_ARG_NUM_CPU} install                                                        && \
    cp ./install_dir/lib64/libjpeg.a* ${SDKTARGETSYSROOT}/usr/lib/${TFLITE_TARGET}              && \
    cp ./install_dir/include/* ${SDKTARGETSYSROOT}/usr/include/                                 && \
    cd ../                                                                                      && \
    rm -rf libjpeg*

#---------------------------------------------------------------------------------------------------

# Target tflite-tools-builder
FROM tflite-tools-common-${TFLITE_ARG_OS} AS tflite-tools-builder

# Switch back to base dir
WORKDIR "${TFLITE_ARG_BASE_DIR}"

# Set needed environment variables
ENV TFLITE_TF_SRC_DIR=${TFLITE_ARG_BASE_DIR}/src/tensorflow
ENV TFLITE_SRC_DIR=${TFLITE_TF_SRC_DIR}/tensorflow/lite/c
ENV TFLITE_DEPLOY_DEVICE_DIR=/tmp/mount-docker
ENV TFLITE_BUILD_DIR=${TFLITE_ROOT_BUILD_DIR}/tflite

# Clone Tensorflow Lite
ARG TFLITE_ARG_VERSION
ENV TFLITE_VERSION=${TFLITE_ARG_VERSION}
RUN git clone --progress https://git.codelinaro.org/clo/lc/external/github.com/tensorflow/tensorflow.git --single-branch --branch v${TFLITE_VERSION} ${TFLITE_TF_SRC_DIR}

# Adding Required files and libraries
ADD patches ${TFLITE_DOWNLOAD_DIR}/

# Dummy user name and email just to apply and merge patches and configure tf
RUN git -C ${TFLITE_TF_SRC_DIR} config --global user.name "username"
RUN git -C ${TFLITE_TF_SRC_DIR} config --global user.email "email"

# Apply and merge patches
RUN git -C ${TFLITE_TF_SRC_DIR} am --reject --whitespace=fix ${TFLITE_DOWNLOAD_DIR}/tf-lite-${TFLITE_VERSION}/0*

# Adding scripts
ADD scripts/image ${TFLITE_ARG_BASE_DIR}/scripts

# Set needed environment variables
ARG TFLITE_ARG_OS
ENV TFLITE_OS=${TFLITE_ARG_OS}

# Enable needed Delegates
ARG TFLITE_ARG_HEXAGON
ENV TFLITE_ENABLE_HEXAGON=${TFLITE_ARG_HEXAGON}
ARG TFLITE_ARG_GPU
ENV TFLITE_ENABLE_GPU=${TFLITE_ARG_GPU}
ARG TFLITE_ARG_XNNPACK
ENV TFLITE_ENABLE_XNNPACK=${TFLITE_ARG_XNNPACK}

# Build Tensorflow Lite
RUN bash ${TFLITE_BASE_DIR}/scripts/all_scripts.sh tflite-tools-clean-build-install

# Unset dummy git user
RUN git -C ${TFLITE_TF_SRC_DIR} config --global --unset user.name
RUN git -C ${TFLITE_TF_SRC_DIR} config --global --unset user.email

#---------------------------------------------------------------------------------------------------

# Final stage - TFLite Image
FROM --platform=linux/arm64 ubuntu:22.04 AS tflite-tools-image

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Installing required apt packages
RUN apt-get update                                                                              && \
    apt-get install -y  libglib2.0-dev libpcre3-dev                                             && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

ARG TFLITE_ARG_BASE_DIR
ENV TFLITE_BASE_DIR=${TFLITE_ARG_BASE_DIR}

COPY --from=tflite-tools-builder ${TFLITE_ARG_BASE_DIR}/deploy/usr /usr
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/usr/lib1

WORKDIR "${TFLITE_BASE_DIR}"
