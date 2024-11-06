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
        gettext libdaemon-dev libjansson-dev libreadline-dev                                       \
        libcairo2-dev                                                                              \
        libgstrtspserver-1.0-dev                                                                   \
        libgirepository1.0-dev                                                                     \
        opencl-headers                                                                             \
        libjson-glib-dev                                                                           \
        libsoup2.4-dev                                                                             \
        libhiredis-dev                                                                             \
        libjsoncpp-dev                                                                             \
        libeigen3-dev                                                                              \
        python3 python3-pip python3-setuptools python3-gst-1.0                                     \
        python3-wheel ninja-build                                                               && \
        pip3 install meson                                                                      && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Add qimsdk install directory
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy

# Add qimsdk debug install directory
ENV QIMSDK_INSTALL_DEBUG_DIR=${QIMSDK_BASE_DIR}/deploy_dbg

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

# Clone Tensorflow Lite; checkout hash is for v2.15.1
ENV QIMSDK_TF_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/tensorflow
RUN git config --global http.postBuffer 157286400                                               && \
    git clone --progress https://github.com/tensorflow/tensorflow.git                              \
        --single-branch --branch r2.15 ${QIMSDK_TF_SRC_DIR}                                     && \
    cd ${QIMSDK_TF_SRC_DIR}                                                                     && \
    git checkout 63f5a65c7cd7b6241bede8d2e0082058566ea364

# qnp-sdk: fetch and copy the needed headers
ENV QIMSDK_QNP_SDK=v2.24.0.240626.zip
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        https://softwarecenter.qualcomm.com/api/download/software/qualcomm_neural_processing_sdk/${QIMSDK_QNP_SDK} && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    unzip ${QIMSDK_QNP_SDK}                                                                     && \
    rm -f ${QIMSDK_QNP_SDK}                                                                     && \
    QIMSDK_ARG_QNP_SDK_VERSION=$(ls qairt)                                                      && \
    cp -r ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/SNPE/*                \
        ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/QNN/*                   \
        /usr/include/                                                                           && \
    rm -rf ${QIMSDK_DOWNLOAD_DIR}/qairt

# gstd: fetch (hash is for v0.11.3) and install
ENV QIMSDK_GSTD_SRC_DIR=${QIMSDK_DOWNLOAD_DIR}/gstd-1.x
RUN git clone https://github.com/RidgeRun/gstd-1.x.git ${QIMSDK_GSTD_SRC_DIR}                   && \
    cd ${QIMSDK_GSTD_SRC_DIR}                                                                   && \
    git checkout d924fcbc2123dcfcb35242ecf5dc2fc3049004b3

# Add bash aliases file
COPY .bash_aliases /root/.bash_aliases

# Setup patches dir
ENV QIMSDK_PATCHES_DIR=${QIMSDK_BASE_DIR}/tmp/patches
COPY tmp/patches ${QIMSDK_PATCHES_DIR}

# wayland-protocols: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        'https://wayland.freedesktop.org/releases/wayland-protocols-1.25.tar.xz'                && \
    wget -t 2 -T 30  -P ${QIMSDK_DOWNLOAD_DIR}                                                     \
        'https://wayland.freedesktop.org/releases/wayland-protocols-1.25.tar.xz.sig'            && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys                                        \
        8307C0A224BABDA1BABD0EB9A6EEEC9E0136164A                                                && \
    gpg --fingerprint 8307C0A224BABDA1BABD0EB9A6EEEC9E0136164A                                  && \
    gpg --verify ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25.tar.xz.sig                          \
        ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25.tar.xz                                    && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xf wayland-protocols-1.25.tar.xz                                                       && \
    gpg --batch --delete-key 8307C0A224BABDA1BABD0EB9A6EEEC9E0136164A                           && \
    rm -f wayland-protocols-1.25.tar.xz*

WORKDIR  ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25      && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial wayland protocols Commit"

# gst-plugins-bad: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        'https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-1.20.7.tar.xz'   && \
    wget -t 2 -T 30  -P ${QIMSDK_DOWNLOAD_DIR}                                                     \
        'https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-1.20.7.tar.xz.asc' && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys                                        \
        D637032E45B8C6585B9456565D2EEE6F6F349D7C                                                && \
    gpg --fingerprint D637032E45B8C6585B9456565D2EEE6F6F349D7C                                  && \
    gpg --verify ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7.tar.xz.asc                          \
        ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7.tar.xz                                    && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xf gst-plugins-bad-1.20.7.tar.xz                                                       && \
    gpg --batch --delete-key D637032E45B8C6585B9456565D2EEE6F6F349D7C                           && \
    rm -f gst-plugins-bad-1.20.7.tar.xz*

WORKDIR  ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7      && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Plugins Bad Commit"

# gst-plugins-good: fetch and prepare git repo
RUN wget -t 2 -T 30 -P ${QIMSDK_DOWNLOAD_DIR}                                                      \
        'https://gstreamer.freedesktop.org/src/gst-plugins-good/gst-plugins-good-1.20.7.tar.xz' && \
    wget -t 2 -T 30  -P ${QIMSDK_DOWNLOAD_DIR}                                                     \
        'https://gstreamer.freedesktop.org/src/gst-plugins-good/gst-plugins-good-1.20.7.tar.xz.asc' && \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys                                        \
        D637032E45B8C6585B9456565D2EEE6F6F349D7C                                                && \
    gpg --fingerprint D637032E45B8C6585B9456565D2EEE6F6F349D7C                                  && \
    gpg --verify ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7.tar.xz.asc                         \
        ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7.tar.xz                                   && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    tar -xf gst-plugins-good-1.20.7.tar.xz                                                      && \
    gpg --batch --delete-key D637032E45B8C6585B9456565D2EEE6F6F349D7C                           && \
    rm -f gst-plugins-good-1.20.7.tar.xz*

WORKDIR ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7     && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Plugins Good Commit"

# Add Source Code
ENV QIMSDK_SRC_DIR=${QIMSDK_BASE_DIR}/src
RUN mkdir -p ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss
COPY tmp/gst-plugins-qti-oss ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss

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

# Copy qimsdk microservices shell scripts
COPY --chmod=755                                                                                   \
        tmp/solutions-microservices/ai/24-stream-ai-concurrency/qimsdk_24_stream_ai_concurrency.sh \
        ${QIMSDK_INSTALL_DIR}/usr/bin/
COPY --chmod=755                                                                                   \
        tmp/solutions-microservices/ai/access-control/qimsdk_access_control.sh                     \
        ${QIMSDK_INSTALL_DIR}/usr/bin/
COPY --chmod=755                                                                                   \
        tmp/solutions-microservices/ai/daisy-chain/qimsdk_daisy_chain.sh                           \
        ${QIMSDK_INSTALL_DIR}/usr/bin/
COPY --chmod=755                                                                                   \
        tmp/solutions-microservices/ai/person-detect/qimsdk_person_detect.sh                       \
        ${QIMSDK_INSTALL_DIR}/usr/bin/
COPY --chmod=755                                                                                   \
        tmp/solutions-microservices/ai/ppe/qimsdk_ppe.sh ${QIMSDK_INSTALL_DIR}/usr/bin/
COPY --chmod=755                                                                                   \
        tmp/solutions-microservices/ai/rz/qimsdk_restricted_zone.sh ${QIMSDK_INSTALL_DIR}/usr/bin/

# Copy label files
COPY --chmod=555                                                                                   \
        tmp/solutions-microservices/ai/files/labels/gear_guard_net.labels                          \
        ${QIMSDK_INSTALL_DIR}/opt/labels/gear_guard_net.labels
COPY --chmod=555                                                                                   \
        tmp/solutions-microservices/ai/files/labels/foot_track_net.labels                          \
        ${QIMSDK_INSTALL_DIR}/opt/labels/foot_track_net.labels
COPY --chmod=555                                                                                   \
        tmp/solutions-microservices/ai/files/labels/dv3-argmax.labels                              \
        ${QIMSDK_INSTALL_DIR}/opt/labels/dv3-argmax.labels
COPY --chmod=555                                                                                   \
        tmp/solutions-microservices/ai/files/labels/resnet101.labels                               \
        ${QIMSDK_INSTALL_DIR}/opt/labels/resnet101.labels

# Change workdir back to base dir from downloads dir
WORKDIR ${QIMSDK_BASE_DIR}

# Call wrapper function to apply all patches
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-apply-patches

# Call wrapper build function to compile and install gst plugins
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-incremental-build

# Set artifacts save Docker_image_path
ARG QIMSDK_ARG_DOCKER_IMAGE_PATH
ENV DOCKER_IMAGE_PATH=${QIMSDK_ARG_DOCKER_IMAGE_PATH}

# # # # # # # # # # # # # # #

# QIMSDK Device Image
FROM --platform=arm64 ubuntu:22.04 AS qimsdk_device_image

# Set base directory
ARG QIMSDK_ARG_BASE_DIR
ENV QIMSDK_BASE_DIR=${QIMSDK_ARG_BASE_DIR}

# Installing required apt packages
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y                               \
        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-tools libhiredis0.14       \
        libudev1 libgstrtspserver-1.0-0 bash-completion libsoup2.4 gstreamer1.0-nice               \
        libjsoncpp25 libopencv-imgproc4.5d libdaemon0 python3 python3-gst-1.0                   && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Create USER and add to video group for accessing v4ls devices
RUN addgroup qcom                                                                               && \
    useradd -s /bin/bash -m -g qcom qimsdk                                                      && \
    usermod -aG video qimsdk                                                                    && \
    echo qimsdk:asd | chpasswd

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /home/qimsdk/.bashrc

# Copy installed binaries to device image
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
COPY --from=qimsdk_dev_image ${QIMSDK_INSTALL_DIR}/usr /usr
COPY --from=qimsdk_dev_image ${QIMSDK_INSTALL_DIR}/opt /opt

# Copy python examples
COPY --from=qimsdk_dev_image ${QIMSDK_BASE_DIR}/src/gst-plugins-qti-oss/gst-python-examples /usr/bin

# Copy wizard script
COPY --from=qimsdk_dev_image                                                                       \
    ${QIMSDK_BASE_DIR}/src/gst-plugins-qti-oss/gst-plugin-tools/gst-scripts/demo_setup_wizard.sh   \
    /usr/bin

# Change user to qimsdk
USER qimsdk

# Change workdir to user home
WORKDIR /home/qimsdk
