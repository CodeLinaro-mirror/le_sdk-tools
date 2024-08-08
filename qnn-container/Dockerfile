# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Define build args
ARG QNN_ARG_BASE_IMAGE

# Target qnn-tools-common
FROM ${QNN_ARG_BASE_IMAGE} AS qnn-tools-builder
# Set base folder
ARG QNN_ARG_BASE_DIR
ENV QNN_BASE_DIR=${QNN_ARG_BASE_DIR}
RUN mkdir -p ${QNN_ARG_BASE_DIR}

# Create directories
ENV QNN_DEPLOY_DIR=${QNN_ARG_BASE_DIR}/deploy
RUN mkdir -p ${QNN_DEPLOY_DIR}

ADD tmp/acceleration_engines ${QNN_BASE_DIR}/downloads/

ARG QNN_ARG_VERSION
ENV QNN_VERSION=${QNN_ARG_VERSION}

ARG QNN_ARG_TARGET_PLATFORM
ENV QNN_TARGET_PLATFORM=${QNN_ARG_TARGET_PLATFORM}

ADD scripts/image/ ${QNN_BASE_DIR}/scripts

RUN mkdir -p ${QNN_DEPLOY_DIR}/usr/lib/rfsa/adsp/
RUN mkdir -p ${QNN_DEPLOY_DIR}/usr/bin/

RUN bash ${QNN_BASE_DIR}/scripts/all_scripts.sh qnn-update-libraries

#---------------------------------------------------------------------------------------------------
# Final stage - QNN Image
FROM --platform=linux/arm64 ${QNN_ARG_BASE_IMAGE} AS qnn-tools-image

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Installing required apt packages
RUN apt-get update                                                                              && \
    apt-get install -y libglib2.0-0  libpcre3                                                   && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

ARG QNN_ARG_BASE_DIR
ENV QNN_BASE_DIR=${QNN_ARG_BASE_DIR}

COPY --from=qnn-tools-builder ${QNN_BASE_DIR}/deploy/usr /usr

WORKDIR "${QNN_BASE_DIR}"
