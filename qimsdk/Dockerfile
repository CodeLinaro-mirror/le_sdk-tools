# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# QIMSDK Development Image
FROM --platform=arm64 ubuntu:22.04 AS qimsdk_dev_image

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Set base directory
ARG QIMSDK_ARG_BASE_DIR
ENV QIMSDK_BASE_DIR=${QIMSDK_ARG_BASE_DIR}

# Installing required apt packages
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y                               \
        git tar unzip ssh rsync bash-completion jq cmake                                           \
        libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev       \
        gettext                                                                                    \
        libcairo2-dev                                                                              \
        libgstrtspserver-1.0-dev                                                                   \
        libgirepository1.0-dev                                                                     \
        opencl-headers                                                                             \
        libjson-glib-dev                                                                           \
        libsoup2.4-dev                                                                             \
        libhiredis-dev                                                                             \
        libjsoncpp-dev                                                                             \
        python3 python3-pip python3-setuptools                                                     \
        python3-wheel ninja-build                                                               && \
        pip3 install meson                                                                      && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Add qimsdk install directory
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy

# Add qimsdk build directory and logs directory
ENV QIMSDK_BUILD_DIR=${QIMSDK_BASE_DIR}/build
ENV QIMSDK_LOGS_DIR=${QIMSDK_BASE_DIR}/logs
RUN mkdir -p ${QIMSDK_BUILD_DIR}
RUN mkdir -p ${QIMSDK_LOGS_DIR}

# Add private headers needed compiletime from headers dir
COPY tmp/headers/usr/ /usr/

# Set up download directory
ENV QIMSDK_DOWNLOAD_DIR=${QIMSDK_BASE_DIR}/downloads
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}

# Clone Tensorflow Lite
ENV QIMSDK_TF_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/tensorflow
RUN mkdir -p ${QIMSDK_TF_SRC_DIR}

RUN git clone --progress https://github.com/tensorflow/tensorflow.git                              \
    --single-branch --branch master ${QIMSDK_TF_SRC_DIR}

ARG QIMSDK_ARG_QNP_SDK_DOWNLOAD_LINK

# qnp-sdk: fetch and copy the needed headers
RUN [ -n "${QIMSDK_ARG_QNP_SDK_DOWNLOAD_LINK}" ] || touch ${QIMSDK_BASE_DIR}/no-qnp-sdk-provided
RUN [ -f "${QIMSDK_BASE_DIR}/no-qnp-sdk-provided" ] || (                                           \
    wget -t 2 -T 30 --passive-ftp -P ${QIMSDK_DOWNLOAD_DIR}                                        \
    "${QIMSDK_ARG_QNP_SDK_DOWNLOAD_LINK}"                                                       && \
    QIMSDK_ARG_QNP_SDK=$(basename -- ${QIMSDK_ARG_QNP_SDK_DOWNLOAD_LINK})                       && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    unzip ${QIMSDK_ARG_QNP_SDK}                                                                 && \
    rm -f ${QIMSDK_ARG_QNP_SDK}                                                                 && \
    QIMSDK_ARG_QNP_SDK_VERSION=$(ls qairt)                                                      && \
    cp -r ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/SNPE/*                \
          ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/QNN/*                 \
          /usr/include/                                                                         && \
    rm -rf ${QIMSDK_DOWNLOAD_DIR}/qairt                                                            \
    )

# Add bash aliases file
COPY .bash_aliases /root/.bash_aliases

# Setup patches dir
ENV QIMSDK_PATCHES_DIR=${QIMSDK_BASE_DIR}/tmp/patches
COPY tmp/patches ${QIMSDK_PATCHES_DIR}

# wayland-protocols: fetch and prepare git repo
RUN wget -t 2 -T 30 --passive-ftp -P ${QIMSDK_DOWNLOAD_DIR}                                        \
    'https://wayland.freedesktop.org/releases/wayland-protocols-1.25.tar.xz'                    && \
    cd ${QIMSDK_DOWNLOAD_DIR} && tar -xf wayland-protocols-1.25.tar.xz                          && \
    rm -f wayland-protocols-1.25.tar.xz
WORKDIR  ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25

RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25      && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial wayland protocols Commit"

# gst-plugins-bad: fetch and prepare git repo
RUN wget -t 2 -T 30 --passive-ftp -P ${QIMSDK_DOWNLOAD_DIR}                                        \
    'https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-1.20.7.tar.xz'       && \
    cd ${QIMSDK_DOWNLOAD_DIR} && tar -xf gst-plugins-bad-1.20.7.tar.xz                          && \
    rm -f gst-plugins-bad-1.20.7.tar.xz
WORKDIR  ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7      && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Plugins Bad Commit"

# gst-plugins-good: fetch and prepare git repo
RUN wget -t 2 -T 30 --passive-ftp -P ${QIMSDK_DOWNLOAD_DIR}                                        \
    'https://gstreamer.freedesktop.org/src/gst-plugins-good/gst-plugins-good-1.20.7.tar.xz'     && \
    cd ${QIMSDK_DOWNLOAD_DIR} && tar -xf gst-plugins-good-1.20.7.tar.xz                         && \
    rm -f gst-plugins-good-1.20.7.tar.xz
WORKDIR ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7     && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Plugins Good Commit"

# Add Source Code
ENV QIMSDK_SRC_DIR=${QIMSDK_BASE_DIR}/src
RUN mkdir -p ${QIMSDK_SRC_DIR}
COPY tmp/gst-plugins-qti-oss ${QIMSDK_SRC_DIR}

# Add development image scripts
ENV QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/tmp/scripts/
COPY scripts/dev_image ${QIMSDK_SCRIPTS}

# Copy the Tensorflow Lite's headers and dependent headers to the sysroot
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-copy-tf-lite-headers-to-sysroot

# Add json file with content of cmake flags
ENV QIMSDK_CMAKE_FLAGS_DIR=${QIMSDK_BASE_DIR}/tmp/cmake_flags/
COPY tmp/cmake_flags.json ${QIMSDK_CMAKE_FLAGS_DIR}
ENV QIMSDK_CMAKE_FLAGS_JSON=${QIMSDK_CMAKE_FLAGS_DIR}/cmake_flags.json

# Add json file with content of cmake flags
ENV QIMSDK_RECIPES_PATCHES_DIR=${QIMSDK_BASE_DIR}/tmp/recipes_patches/
COPY tmp/recipes_patches.json ${QIMSDK_RECIPES_PATCHES_DIR}
ENV QIMSDK_RECIPES_JSON=${QIMSDK_RECIPES_PATCHES_DIR}/recipes_patches.json

# Change workdir back to base dir from downloads dir
WORKDIR ${QIMSDK_BASE_DIR}

# Call wrapper function to apply all patches
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-aplly-patches

# Call wrapper build function to compile and install gst plugins
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-incremental-build

# Set artifacts save Docker_image_path
ARG QIMSDK_ARG_DOCKER_IMAGE_PATH
ENV DOCKER_IMAGE_PATH=${QIMSDK_ARG_DOCKER_IMAGE_PATH}

# # # # # # # # # # # # # # #

# QIMSDK Device Image
FROM --platform=arm64 ubuntu:22.04 AS qimsdk_device_image

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Set base directory
ARG QIMSDK_ARG_BASE_DIR
ENV QIMSDK_BASE_DIR=${QIMSDK_ARG_BASE_DIR}

# Installing required apt packages
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y                               \
        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-tools libhiredis0.14       \
        libudev1 libgstrtspserver-1.0-0 bash-completion libsoup2.4 gstreamer1.0-nice               \
        libjsoncpp25 libopencv-imgproc4.5d                                                      && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Copy installed binaries to device image
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
COPY --from=qimsdk_dev_image ${QIMSDK_INSTALL_DIR}/usr /usr
