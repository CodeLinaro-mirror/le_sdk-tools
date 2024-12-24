# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

ARG QML_ARG_BASE_IMAGE

# QML_builder Image
FROM --platform=linux/arm64 ${QML_ARG_BASE_IMAGE} as QML_builder

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

RUN mkdir -p /deploy/snpe/usr/lib/rfsa/adsp/
RUN mkdir -p /deploy/snpe/usr/bin/

# Copy Acceleration engine libraries and binaries to /usr/lib/ and /usr/bin/
RUN bash ${QML_BASE_DIR}/scripts/all_scripts.sh qml-install-libraries

# QML Image
FROM --platform=linux/arm64 ${QML_ARG_BASE_IMAGE} as QML

# Installing required apt packages
RUN apt-get update                                                                              && \
    apt-get install -y libglib2.0-0 libpcre3 libatomic1                                         && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

COPY --from=QML_builder /deploy/snpe/usr/lib/ /usr/lib
COPY --from=QML_builder /deploy/snpe/usr/bin/ /usr/bin
