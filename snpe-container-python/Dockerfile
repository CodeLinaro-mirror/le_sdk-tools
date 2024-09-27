# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

ARG QML_ARG_BASE_IMAGE

# QML Image
FROM --platform=linux/arm64 ${QML_ARG_BASE_IMAGE} as QML_builder

# Installing required apt packages
RUN apt-get update                                                                              && \
    apt-get install -y curl unzip                                                               && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Set base directory
ARG QML_ARG_BASE_DIR
ENV QML_BASE_DIR=${QML_ARG_BASE_DIR}

# Add scripts
ADD scripts/docker/ ${QML_BASE_DIR}/scripts

# Set workdir
WORKDIR "${QML_BASE_DIR}"

# Set base directory
ARG QML_ARG_SDK_VERSION
ENV QML_SDK_VERSION=${QML_ARG_SDK_VERSION}

ARG QML_ARG_TARGET_PLATFORM
ENV QML_TARGET_PLATFORM=${QML_ARG_TARGET_PLATFORM}

# Copy SNPE libraries and binaries to /usr/lib/ and /usr/bin/ and models to /opt
RUN mkdir -p /deploy/snpe/usr/lib/rfsa/adsp/                                                    && \
    mkdir -p /deploy/snpe/usr/bin/                                                              && \
    mkdir -p /deploy/snpe/opt/                                                                  && \
    bash ${QML_BASE_DIR}/scripts/all_scripts.sh qml-install-libraries-snpe                      && \
    bash ${QML_BASE_DIR}/scripts/all_scripts.sh qml-download-models-snpe

# QML Image
FROM --platform=linux/arm64 ${QML_ARG_BASE_IMAGE} as QML

# Set base directory
ARG QML_ARG_BASE_DIR
ENV QML_BASE_DIR=${QML_ARG_BASE_DIR}

# Enable color prompt
# Install required apt and python packages
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc                   && \
    apt-get update                                                                              && \
    apt-get install -y --no-install-recommends python3 python3-pip                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*                                                && \
    pip3 install --no-cache-dir numpy==1.24.4 opencv-python-headless==4.10.0.84 pillow==10.4.0

# Set workdir
WORKDIR "${QML_BASE_DIR}"

# Add python wrapper code
COPY src/python ${QML_BASE_DIR}/src/python

COPY --from=QML_builder /deploy/snpe/usr/lib/ /usr/lib
COPY --from=QML_builder /deploy/snpe/usr/bin/ /usr/bin
COPY --from=QML_builder /deploy/snpe/opt/ /opt
