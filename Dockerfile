# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# QIMSDK_ARG_IMAGE_OS argument
ARG QIMSDK_ARG_IMAGE_OS

################################################################################
# Start ubuntu 18 base image
FROM ubuntu:bionic as qimsdk-ubuntu18

# Set alternatives priority for python
ENV QIMSDK_ALTERNATIVES_PRIPRITY_PYTHON2=10
ENV QIMSDK_ALTERNATIVES_PRIPRITY_PYTHON3=1

################################################################################
# Start ubuntu 20 base image
FROM ubuntu:focal as qimsdk-ubuntu20

# Set alternatives priority for python
ENV QIMSDK_ALTERNATIVES_PRIPRITY_PYTHON2=1
ENV QIMSDK_ALTERNATIVES_PRIPRITY_PYTHON3=10

################################################################################
# Start qimsdk base image
FROM qimsdk-${QIMSDK_ARG_IMAGE_OS} as qimsdk

# Install needed ubuntu packets
RUN apt update                                                                                  && \
    DEBIAN_FRONTEND=noninteractive apt install -y sudo python2.7 gnupg flex bison screen tree mc   \
        build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 libncurses5   \
        lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils   \
        xsltproc unzip fontconfig python3 clang cmake python3-pip texinfo chrpath diffstat         \
        xmlstarlet libarchive-dev ssh libselinux1-dev g++ gawk gcc make libwayland-dev fakeroot    \
        libpam0g-dev openjdk-8-jdk-headless binutils-dev util-linux uuid-dev zstd cpio whiptail    \
        libxml-simple-perl bash-completion vim openssl software-properties-common                  \
        locales gdb lcov libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev usbutils             \
        liblzma-dev libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev lzma lzma-dev       \
        tk-dev file git language-pack-en-base wget android-tools-adb android-tools-fastboot     && \
    apt install -y fakechroot gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libiberty-dev jq      && \
    apt autoremove -y                                                                           && \
    apt clean                                                                                   && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Install additional dependencies
RUN rm -rf /lib/ld-linux-aarch64.so.1                                                           && \
    ln -sf /usr/aarch64-linux-gnu/lib/ld-2.31.so /lib/ld-linux-aarch64.so.1                     && \
    ln -sf /bin/bash /bin/sh

# Set python2.7 as python2
RUN update-alternatives --install /usr/bin/python2 python2 /usr/bin/python2.7 10

# Set python alternatives
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 ${QIMSDK_ALTERNATIVES_PRIPRITY_PYTHON3}
RUN update-alternatives --install /usr/bin/python python /usr/bin/python2 ${QIMSDK_ALTERNATIVES_PRIPRITY_PYTHON2}

# Increase max user watches
RUN echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
RUN echo fs.inotify.max_user_instances=8192 | sudo tee -a /etc/sysctl.conf
RUN sysctl -p

# Input arguments
ARG QIMSDK_ARG_HOST_USER_ID
ARG QIMSDK_ARG_HOST_USER
ARG QIMSDK_ARG_HOST_GROUP_ID
ARG QIMSDK_ARG_HOST_GROUP

# Create user
# Group users lists logged users and cannot be manually created
RUN [ "$QIMSDK_ARG_HOST_GROUP" != "users" ]                                                     && \
    addgroup --gid ${QIMSDK_ARG_HOST_GROUP_ID} ${QIMSDK_ARG_HOST_GROUP}                         || \
    true
RUN useradd -s /bin/bash -m -g ${QIMSDK_ARG_HOST_GROUP} -u ${QIMSDK_ARG_HOST_USER_ID} ${QIMSDK_ARG_HOST_USER}
RUN usermod -aG plugdev ${QIMSDK_ARG_HOST_USER}
RUN usermod -aG sudo ${QIMSDK_ARG_HOST_USER}
RUN echo ${QIMSDK_ARG_HOST_USER}:pass | chpasswd

# Update locale
RUN locale-gen "en_US.UTF-8"                                                                    && \
    echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' > /etc/default/locale

# Set base folder
ARG QIMSDK_ARG_BASE_FOLDER
ENV QIMSDK_BASE_FOLDER=${QIMSDK_ARG_BASE_FOLDER}
RUN mkdir -p ${QIMSDK_BASE_FOLDER}                                                              && \
    chown ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_BASE_FOLDER}

# Add eSDK
ARG QIMSDK_ARG_ESDK_SH
ENV QIMSDK_ESDK_SH=${QIMSDK_ARG_ESDK_SH}
ENV QIMSDK_ESDK_BASE_FOLDER=${QIMSDK_BASE_FOLDER}/esdk
RUN mkdir -p ${QIMSDK_ESDK_BASE_FOLDER}                                                         && \
    chown ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_ESDK_BASE_FOLDER}
ADD tmp/${QIMSDK_ESDK_SH} ${QIMSDK_ESDK_BASE_FOLDER}/${QIMSDK_ESDK_SH}

# Set tflite path
ARG QIMSDK_ARG_TFLITE_FILE
ENV QIMSDK_ESDK_TFLITE_FILE=${QIMSDK_ARG_TFLITE_FILE}

# Set SNPE path
ARG QIMSDK_ARG_SNPE_DIR
ENV QIMSDK_ESDK_SNPE_DIR=${QIMSDK_ARG_SNPE_DIR}

# Setup eSDK as HOST user
RUN chmod a+r ${QIMSDK_ESDK_BASE_FOLDER}/${QIMSDK_ESDK_SH}
RUN umask 022
USER ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP}
RUN ${QIMSDK_ESDK_BASE_FOLDER}/${QIMSDK_ESDK_SH} -y -d ${QIMSDK_ESDK_BASE_FOLDER}
COPY tmp/${QIMSDK_ESDK_TFLITE_FILE} ${QIMSDK_ESDK_BASE_FOLDER}/downloads/
COPY tmp/${QIMSDK_ESDK_SNPE_DIR} ${QIMSDK_ESDK_BASE_FOLDER}/downloads/${QIMSDK_ESDK_SNPE_DIR}
USER root
RUN chown -R ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_ESDK_BASE_FOLDER}/downloads/${QIMSDK_ESDK_SNPE_DIR}
RUN ln -sf ${QIMSDK_ESDK_BASE_FOLDER}/buildtools /usr/local/oe-sdk-hardcoded-buildpath
RUN rm -rf ${QIMSDK_ESDK_BASE_FOLDER}/${QIMSDK_ESDK_SH}

# Add bash aliases
ADD .bash_aliases /home/${QIMSDK_ARG_HOST_USER}/.bash_aliases
RUN chown ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} /home/${QIMSDK_ARG_HOST_USER}/.bash_aliases

# Set sync URL prefix
ARG QIMSDK_ARG_SYNC_URL_PREFIX
ENV QIMSDK_ESDK_SYNC_URL_PREFIX=${QIMSDK_ARG_SYNC_URL_PREFIX}

# Set deploy URL
ARG QIMSDK_ARG_DEPLOY_URL
ENV QIMSDK_ESDK_DEPLOY_URL=${QIMSDK_ARG_DEPLOY_URL}

# Remove meta layers and src code to be cloned
RUN rm -rf ${QIMSDK_ESDK_BASE_FOLDER}/layers/poky/meta-qti-gst
RUN rm -rf ${QIMSDK_ESDK_BASE_FOLDER}/layers/poky/meta-qti-gst-prop
RUN rm -rf ${QIMSDK_ESDK_BASE_FOLDER}/layers/src/vendor/qcom/opensource/gst-plugins-qti-oss

# Add patches
ENV QIMSDK_PATCHES=${QIMSDK_BASE_FOLDER}/patches
ADD patches ${QIMSDK_PATCHES}
RUN chown -R ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_PATCHES}

# Add image scripts
ENV QIMSDK_SCRIPTS=${QIMSDK_BASE_FOLDER}/scripts
ADD scripts/image ${QIMSDK_SCRIPTS}
RUN chown -R ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_SCRIPTS}

# Set work folder
ENV QIMSDK_WORK_FOLDER=${QIMSDK_BASE_FOLDER}/work

WORKDIR ${QIMSDK_BASE_FOLDER}
