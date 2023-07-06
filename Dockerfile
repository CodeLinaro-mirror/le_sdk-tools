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
        libxml-simple-perl git vim openssl software-properties-common                              \
        locales gdb lcov libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev usbutils             \
        liblzma-dev libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev lzma lzma-dev       \
        tk-dev file language-pack-en-base wget android-tools-adb android-tools-fastboot         && \
    apt install -y fakechroot gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libiberty-dev jq         \
    bash-completion                                                                             && \
    apt autoremove -y                                                                           && \
    apt clean                                                                                   && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Install additional dependencies
RUN rm -rf /lib/ld-linux-aarch64.so.1                                                           && \
    ln -sf /usr/aarch64-linux-gnu/lib/ld-2.31.so /lib/ld-linux-aarch64.so.1                     && \
    ln -sf /bin/bash /bin/sh                                                                    && \
    QEMU_PACKAGE=$(wget -q -O - http://archive.ubuntu.com/ubuntu/pool/universe/q/qemu/           | \
    grep -o '"qemu-user-static_6.2+dfsg-2ubuntu*.*.deb"' | sort -V | head -1 | tr -d '"')       && \
    wget --quiet http://archive.ubuntu.com/ubuntu/pool/universe/q/qemu/${QEMU_PACKAGE}          && \
    dpkg -i ${QEMU_PACKAGE}                                                                     && \
    rm -rf ${QEMU_PACKAGE}

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

# Set base directory
ARG QIMSDK_ARG_BASE_DIR
ENV QIMSDK_BASE_DIR=${QIMSDK_ARG_BASE_DIR}
RUN mkdir -p ${QIMSDK_BASE_DIR}                                                              && \
    chown ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_BASE_DIR}

# Add eSDK
ARG QIMSDK_ARG_ESDK_SH
ENV QIMSDK_ESDK_SH=${QIMSDK_ARG_ESDK_SH}
ENV QIMSDK_ESDK_BASE_DIR=${QIMSDK_BASE_DIR}/esdk
RUN mkdir -p ${QIMSDK_ESDK_BASE_DIR}                                                         && \
    chown ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_ESDK_BASE_DIR}
ADD tmp/${QIMSDK_ESDK_SH} ${QIMSDK_ESDK_BASE_DIR}/${QIMSDK_ESDK_SH}

# Setup eSDK as HOST user
RUN chmod a+r ${QIMSDK_ESDK_BASE_DIR}/${QIMSDK_ESDK_SH}
RUN umask 022
USER ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP}
RUN ${QIMSDK_ESDK_BASE_DIR}/${QIMSDK_ESDK_SH} -y -d ${QIMSDK_ESDK_BASE_DIR}
USER root
RUN chown -R ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_ESDK_BASE_DIR}/downloads
RUN ln -sf ${QIMSDK_ESDK_BASE_DIR}/buildtools /usr/local/oe-sdk-hardcoded-buildpath
RUN rm -rf ${QIMSDK_ESDK_BASE_DIR}/${QIMSDK_ESDK_SH}

# Add bash aliases
ADD sdk-tools/.bash_aliases /home/${QIMSDK_ARG_HOST_USER}/.bash_aliases
RUN chown ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} /home/${QIMSDK_ARG_HOST_USER}/.bash_aliases

# Set gst plugins qti oss dependencies
ARG QIMSDK_ARG_GST_PLUGINS_QTI_OSS_DEPENDENCIES
ENV QIMSDK_ESDK_GST_PLUGINS_QTI_OSS_DEPENDENCIES=${QIMSDK_ARG_GST_PLUGINS_QTI_OSS_DEPENDENCIES}

# Remove meta layers and src code to be cloned
RUN rm -rf ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-gst
RUN rm -rf ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-gst-prop
RUN rm -rf ${QIMSDK_ESDK_BASE_DIR}/layers/src/vendor/qcom/opensource/gst-plugins-qti-oss

# Add image scripts
ENV QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/scripts
ADD sdk-tools/scripts/image ${QIMSDK_SCRIPTS}
RUN chown -R ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_SCRIPTS}

# Set work dir
ENV QIMSDK_WORK_DIR=${QIMSDK_BASE_DIR}/work

WORKDIR ${QIMSDK_BASE_DIR}

# Add src code
ADD poky ${QIMSDK_ARG_BASE_DIR}/repo/poky
ADD src ${QIMSDK_ARG_BASE_DIR}/repo/src
RUN chown -R ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_ARG_BASE_DIR}/repo/poky  && \
    chown -R ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP} ${QIMSDK_ARG_BASE_DIR}/repo/src
USER ${QIMSDK_ARG_HOST_USER}:${QIMSDK_ARG_HOST_GROUP}
RUN [ -d ${QIMSDK_ESDK_BASE_DIR}/src ] || mkdir ${QIMSDK_ESDK_BASE_DIR}/src
RUN ln -s ${QIMSDK_ARG_BASE_DIR}/repo/src/* ${QIMSDK_ESDK_BASE_DIR}/src/
RUN ln -s ${QIMSDK_ARG_BASE_DIR}/repo/poky ${QIMSDK_ARG_BASE_DIR}/poky

# Set tflite filename
ARG QIMSDK_ARG_TFLITE_FILENAME
ENV QIMSDK_ESDK_TFLITE_FILENAME=${QIMSDK_ARG_TFLITE_FILENAME}

# Set acceleration engine name
ARG QIMSDK_ARG_ACCELERATION_ENGINE_NAMES
ENV QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES=${QIMSDK_ARG_ACCELERATION_ENGINE_NAMES}

# Setup eSDK tflite, acceleration engines, and buildtools
COPY tmp/${QIMSDK_ESDK_TFLITE_FILENAME} ${QIMSDK_ESDK_BASE_DIR}/downloads/
COPY tmp/acceleration_engines/ ${QIMSDK_ESDK_BASE_DIR}/downloads/
RUN rm -rf tmp/acceleration_engines

# Set deploy URL
ARG QIMSDK_ARG_DEPLOY_URL
ENV QIMSDK_ESDK_DEPLOY_URL=${QIMSDK_ARG_DEPLOY_URL}

# Set deploy dev URL
ARG QIMSDK_ARG_DEPLOY_URL_DEV
ENV QIMSDK_ESDK_DEPLOY_URL_DEV=${QIMSDK_ARG_DEPLOY_URL_DEV}

# Set deploy QIMSDK artifacts URL
ARG QIMSDK_ARG_DEPLOY_ARTIFACTS
ENV QIMSDK_ESDK_DEPLOY_ARTIFACTS=${QIMSDK_ARG_DEPLOY_ARTIFACTS}

# Set deploy QIMSDK release artifacts URL
ARG QIMSDK_ARG_DEPLOY_ARTIFACTS_REL
ENV QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL=${QIMSDK_ARG_DEPLOY_ARTIFACTS_REL}

# Set deploy QIMSDK development artifacts URL
ARG QIMSDK_ARG_DEPLOY_ARTIFACTS_DEV
ENV QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV=${QIMSDK_ARG_DEPLOY_ARTIFACTS_DEV}

# Prepare, build and package all layers
RUN bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-layers-prepare-build-package

# Call function to sync packages to artifacts archive
RUN [ "no-artifacts-dir-provided" == "${QIMSDK_ESDK_DEPLOY_ARTIFACTS}" ] || bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-target-sync-artifacts-all
RUN [ "no-artifacts-rel-dir-provided" == "${QIMSDK_ESDK_DEPLOY_ARTIFACTS_REL}" ] || bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-target-sync-artifacts-rel
RUN [ "no-artifacts-dev-dir-provided" == "${QIMSDK_ESDK_DEPLOY_ARTIFACTS_DEV}" ] || bash ${QIMSDK_SCRIPTS}/env_setup.sh qimsdk-target-sync-artifacts-dev
