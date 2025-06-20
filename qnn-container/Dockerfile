# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

ARG QNN_ARG_BASE_IMAGE=ubuntu:24.04

# QNN_builder Image
FROM --platform=linux/arm64 ${QNN_ARG_BASE_IMAGE} AS qnn_builder
RUN apt-get update                                                                              && \
    apt-get install -y curl unzip                                                               && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Set base directory
ARG QNN_ARG_BASE_DIR
ENV QNN_BASE_DIR=${QNN_ARG_BASE_DIR}

# Add scripts
ADD scripts/image/ ${QNN_BASE_DIR}/scripts

# Set workdir
WORKDIR "${QNN_BASE_DIR}"

# Set base directory
ARG QNN_ARG_VERSION
ENV QNN_VERSION=${QNN_ARG_VERSION}

ARG QNN_ARG_TARGET_PLATFORM
ENV QNN_TARGET_PLATFORM=${QNN_ARG_TARGET_PLATFORM}

RUN mkdir -p /deploy/qnn/usr/lib/rfsa/adsp/
RUN mkdir -p /deploy/qnn/usr/bin/

# Copy Acceleration engine libraries and binaries to /usr/lib/ and /usr/bin/
RUN bash ${QNN_BASE_DIR}/scripts/all_scripts.sh qnn-install-libraries

#---------------------------------------------------------------------------------------------------
# Final stage - QNN Image
FROM --platform=linux/arm64 ${QNN_ARG_BASE_IMAGE} AS qnn

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Installing required apt packages
RUN apt-get update                                                                              && \
    apt-get install -y libglib2.0-0 libpcre3 libatomic1                                         && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

COPY --from=QNN_builder /deploy/qnn/usr/lib/ /usr/lib
COPY --from=QNN_builder /deploy/qnn/usr/bin/ /usr/bin
