# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

ARG QML_ARG_BASE_IMAGE

# QML Image
FROM --platform=linux/arm64 ${QML_ARG_BASE_IMAGE} as QML

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Installing required apt packages
RUN apt-get update                                                                              && \
    apt-get install -y python3 python3-pip                                                      && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Installing required python packages
RUN pip3 install numpy==1.24.4

# Set base directory
ARG QML_ARG_BASE_DIR
ENV QML_BASE_DIR=${QML_ARG_BASE_DIR}

# Add acceleration engines
ADD tmp/acceleration_engines ${QML_BASE_DIR}/downloads/

# Add python wrapper code
COPY src/python ${QML_BASE_DIR}/src/python

# Add scripts
ADD scripts/docker/ ${QML_BASE_DIR}/scripts

# Set workdir
WORKDIR "${QML_BASE_DIR}"

ARG QML_ARG_TARGET_PLATFORM
ENV QML_TARGET_PLATFORM=${QML_ARG_TARGET_PLATFORM}

ARG QML_ARG_ACCELERATION_ENGINE_NAMES
ENV QML_ACCELERATION_ENGINE_NAMES=${QML_ARG_ACCELERATION_ENGINE_NAMES}

RUN mkdir -p /usr/lib/rfsa/adsp/

# Copy Acceleration engine libraries and binaries to /usr/lib/ and /usr/bin/
RUN bash ${QML_BASE_DIR}/scripts/all_scripts.sh qml-update-libraries
