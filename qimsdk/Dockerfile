# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

ARG QIMSDK_ARG_BASE_IMAGE
ARG QIMSDK_ARG_PATCHED_SOURCES

# --------------------------------------------------------------------------------------------------

# Get source code of
# wayland-protocols-1.25, gst-plugins-bad-1.20.7 and wayland-protocols-1.25
# from GitLab
FROM ${QIMSDK_ARG_BASE_IMAGE} as get_patched_sources_from_gitlab

# Installing required apt packages
RUN apt-get update                                                                              && \
        apt-get install -y wget tar xz-utils                                                    && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

ENV QIMSDK_DOWNLOAD_DIR=/mnt/work/downloads/
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}

# wayland-protocols: fetch
RUN wget -t 2 -T 30 --passive-ftp -P ${QIMSDK_DOWNLOAD_DIR}                                        \
    'https://wayland.freedesktop.org/releases/wayland-protocols-1.25.tar.xz'                    && \
    cd ${QIMSDK_DOWNLOAD_DIR} && tar -xf wayland-protocols-1.25.tar.xz                          && \
    rm -f wayland-protocols-1.25.tar.xz

# gst-plugins-bad: fetch
RUN wget -t 2 -T 30 --passive-ftp -P ${QIMSDK_DOWNLOAD_DIR}                                        \
    'https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-1.20.7.tar.xz'       && \
    cd ${QIMSDK_DOWNLOAD_DIR} && tar -xf gst-plugins-bad-1.20.7.tar.xz                          && \
    rm -f gst-plugins-bad-1.20.7.tar.xz

# gst-plugins-good: fetch
RUN wget -t 2 -T 30 --passive-ftp -P ${QIMSDK_DOWNLOAD_DIR}                                        \
    'https://gstreamer.freedesktop.org/src/gst-plugins-good/gst-plugins-good-1.20.7.tar.xz'     && \
    cd ${QIMSDK_DOWNLOAD_DIR} && tar -xf gst-plugins-good-1.20.7.tar.xz                         && \
    rm -f gst-plugins-good-1.20.7.tar.xz

# --------------------------------------------------------------------------------------------------

# Get source code of
# wayland-protocols-1.25, gst-plugins-bad-1.20.7 and wayland-protocols-1.25
# from host file system
FROM ${QIMSDK_ARG_BASE_IMAGE} as get_patched_sources_from_host

ENV QIMSDK_DOWNLOAD_DIR=/mnt/work/downloads/
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}

ARG QIMSDK_ARG_WAYLAND_PROTOCOLS_DIR
ARG QIMSDK_ARG_GST_PLUGINS_BAD_DIR
ARG QIMSDK_ARG_GST_PLUGINS_GOOD_DIR

ENV QIMSDK_WAYLAND_PROTOCOLS_DIR=${QIMSDK_DOWNLOAD_DIR}/${QIMSDK_ARG_WAYLAND_PROTOCOLS_DIR}
ENV QIMSDK_GST_PLUGINS_BAD_DIR=${QIMSDK_DOWNLOAD_DIR}/${QIMSDK_ARG_GST_PLUGINS_BAD_DIR}
ENV QIMSDK_GST_PLUGINS_GOOD_DIR=${QIMSDK_DOWNLOAD_DIR}/${QIMSDK_ARG_GST_PLUGINS_GOOD_DIR}

COPY tmp/${QIMSDK_ARG_WAYLAND_PROTOCOLS_DIR} ${QIMSDK_WAYLAND_PROTOCOLS_DIR}
COPY tmp/${QIMSDK_ARG_GST_PLUGINS_BAD_DIR}   ${QIMSDK_GST_PLUGINS_BAD_DIR}
COPY tmp/${QIMSDK_ARG_GST_PLUGINS_GOOD_DIR}  ${QIMSDK_GST_PLUGINS_GOOD_DIR}

# --------------------------------------------------------------------------------------------------

# Common layer of
# wayland-protocols-1.25, gst-plugins-bad-1.20.7 and wayland-protocols-1.25
# from layers above, chosen by json file
FROM get_patched_sources_from_${QIMSDK_ARG_PATCHED_SOURCES} as get_patched_sources

# --------------------------------------------------------------------------------------------------

# QIMSDK Development Image
FROM ${QIMSDK_ARG_BASE_IMAGE} as QIMSDK_dev_image

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

ARG QIMSDK_ARG_QNP_SDK_VERSION

# qnp-sdk: fetch and copy the needed headers
RUN [ -n "${QIMSDK_ARG_QNP_SDK_VERSION}" ] || touch ${QIMSDK_BASE_DIR}/no-qnp-sdk-provided
RUN [ -f "${QIMSDK_BASE_DIR}/no-qnp-sdk-provided" ] || (                                           \
    wget -t 2 -T 30 --passive-ftp -P ${QIMSDK_DOWNLOAD_DIR}                                        \
    "https://softwarecenter.qualcomm.com/api/download/software/qualcomm_neural_processing_sdk/v${QIMSDK_ARG_QNP_SDK_VERSION}.zip" && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    unzip v${QIMSDK_ARG_QNP_SDK_VERSION}.zip                                                    && \
    rm -f v${QIMSDK_ARG_QNP_SDK_VERSION}.zip                                                    && \
    cp -r ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/SNPE/*                \
          ${QIMSDK_DOWNLOAD_DIR}/qairt/${QIMSDK_ARG_QNP_SDK_VERSION}/include/QNN/*                 \
          /usr/include/                                                                         && \
    rm -rf ${QIMSDK_DOWNLOAD_DIR}/qairt                                                            \
    )

# Add and install tflite dev package
COPY tmp/tflite* ${QIMSDK_DOWNLOAD_DIR}
COPY tmp/*no-tflite-provided ${QIMSDK_DOWNLOAD_DIR}
RUN [ ! -f "${QIMSDK_DOWNLOAD_DIR}/tflite-dev.deb" ]                                            || \
        dpkg -i ${QIMSDK_DOWNLOAD_DIR}/tflite-dev.deb                                           && \
        rm -f ${QIMSDK_DOWNLOAD_DIR}/tflite-dev.deb

# Add bash aliases file
COPY .bash_aliases /root/.bash_aliases

# Setup patches dir
ENV QIMSDK_PATCHES_DIR=${QIMSDK_BASE_DIR}/tmp/patches
COPY tmp/patches ${QIMSDK_PATCHES_DIR}

# Get source code of
# wayland-protocols-1.25, gst-plugins-bad-1.20.7 and wayland-protocols-1.25
# from common get_patched_sources layer

COPY --from=get_patched_sources /mnt/work/downloads/wayland-protocols-1.25 ${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25
COPY --from=get_patched_sources /mnt/work/downloads/gst-plugins-bad-1.20.7 ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7
COPY --from=get_patched_sources /mnt/work/downloads/gst-plugins-good-1.20.7 ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7

ENV QIMSDK_WAYLAND_PROTOCOLS_DIR=${QIMSDK_DOWNLOAD_DIR}/wayland-protocols-1.25
ENV QIMSDK_GST_PLUGINS_BAD_DIR=${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad-1.20.7
ENV QIMSDK_GST_PLUGINS_GOOD_DIR=${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good-1.20.7

# wayland-protocols: prepare git repo
WORKDIR ${QIMSDK_WAYLAND_PROTOCOLS_DIR}
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_WAYLAND_PROTOCOLS_DIR}                    && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial wayland protocols Commit"

# gst-plugins-bad: prepare git repo
WORKDIR ${QIMSDK_GST_PLUGINS_BAD_DIR}
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_GST_PLUGINS_BAD_DIR}                      && \
    git config --global user.name "username"                                                    && \
    git config --global user.email "email"                                                      && \
    git add --all                                                                               && \
    git commit -m "Initial Plugins Bad Commit"

# gst-plugins-good: prepare git repo
WORKDIR ${QIMSDK_GST_PLUGINS_GOOD_DIR}
RUN git init                                                                                    && \
    git config --global --add safe.directory ${QIMSDK_GST_PLUGINS_GOOD_DIR}                     && \
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

# Add json file with content of cmake flags
ENV QIMSDK_CMAKE_FLAGS_DIR=${QIMSDK_BASE_DIR}/tmp/cmake_flags/
COPY tmp/cmake_flags.json ${QIMSDK_CMAKE_FLAGS_DIR}
ENV QIMSDK_CMAKE_FLAGS_JSON=${QIMSDK_CMAKE_FLAGS_DIR}/cmake_flags.json

# Change workdir back to base dir from downloads dir
WORKDIR ${QIMSDK_BASE_DIR}

# Call wrapper function to apply all patches
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-aplly-patches

# Call wrapper build function to compile and install gst plugins
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-incremental-build

# Set artifacts save URL
ARG QIMSDK_ARG_URL
ENV URL=${QIMSDK_ARG_URL}

# # # # # # # # # # # # # # #

# QIMSDK Device Image
FROM ${QIMSDK_ARG_BASE_IMAGE} as QIMSDK_device_image

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Set base directory
ARG QIMSDK_ARG_BASE_DIR
ENV QIMSDK_BASE_DIR=${QIMSDK_ARG_BASE_DIR}

# Installing required apt packages
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y                               \
        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-tools                      \
        libudev1 libgstrtspserver-1.0-0 bash-completion libsoup2.4 gstreamer1.0-nice            && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Copy installed binaries to device image
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
COPY --from=QIMSDK_dev_image ${QIMSDK_INSTALL_DIR}/usr /usr
