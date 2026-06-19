# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# QAIRT Image
FROM debian:trixie-slim AS qairt_builder

ARG QAIRT_ARG_SDK_VERSION

RUN dpkg --add-architecture arm64

# Installing required apt packages
RUN apt-get update                                                                              && \
    apt-get install -y curl unzip git autoconf automake libtool build-essential libbsd-dev         \
            libbsd-dev:arm64 libyaml-dev libyaml-dev:arm64 pkg-config m4 wget                      \
            crossbuild-essential-arm64 binutils-aarch64-linux-gnu                               && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Set base directory
ENV QAIRT_BASE_DIR=/mnt/work
ENV QAIRT_DOWNLOAD_DIR=${QAIRT_BASE_DIR}/downloads
ENV QAIRT_INSTALL_DIR=${QAIRT_BASE_DIR}/deploy
ENV QAIRT_LIB_DIR=${QAIRT_INSTALL_DIR}/usr/lib
ENV QAIRT_BIN_DIR=${QAIRT_INSTALL_DIR}/usr/bin
ENV QAIRT_ADSP_DIR=${QAIRT_LIB_DIR}/rfsa/adsp
ENV QAIRT_SDK_VERSION=${QAIRT_ARG_SDK_VERSION}

# Create necessary directories
RUN mkdir -p ${QAIRT_DOWNLOAD_DIR} ${QAIRT_INSTALL_DIR} ${QAIRT_LIB_DIR} ${QAIRT_BIN_DIR}          \
             ${QAIRT_ADSP_DIR} ${QAIRT_INSTALL_DIR}/usr/include

# Set workdir
WORKDIR "${QAIRT_BASE_DIR}"

# Build fastrpc
RUN cd "${QAIRT_DOWNLOAD_DIR}"                                                                  && \
    git clone --depth 1 https://github.com/quic/fastrpc.git --branch v1.0.6                     && \
    cd fastrpc                                                                                  && \
    autoreconf -is                                                                              && \
    BUILD_ARCH="$(dpkg --print-architecture)"                                                   && \
    TARGET_ARCH=arm64                                                                           && \
    TARGET_TRIPLET=aarch64-linux-gnu                                                            && \
    PREFIX="${QAIRT_INSTALL_DIR}/usr"                                                           && \
    LIBDIR="${PREFIX}/lib/${TARGET_TRIPLET}"                                                    && \
    if [ "${BUILD_ARCH}" = "${TARGET_ARCH}" ]; then                                                \
        CC=gcc                                                                                  && \
        AR=ar                                                                                   && \
        RANLIB=ranlib                                                                           && \
        CONFIGURE_ARGS="";                                                                         \
    else                                                                                           \
        CC=${TARGET_TRIPLET}-gcc                                                                && \
        AR=${TARGET_TRIPLET}-ar                                                                 && \
        RANLIB=${TARGET_TRIPLET}-ranlib                                                         && \
        CONFIGURE_ARGS="--host=${TARGET_TRIPLET}";                                                 \
    fi                                                                                          && \
    CFLAGS='-UMACHINE_NAME_PATH -DMACHINE_NAME_PATH=\"/run/device-model\"'                         \
        CC="${CC}" AR="${AR}" RANLIB="${RANLIB}"                                                   \
        ./configure                                                                                \
            ${CONFIGURE_ARGS}                                                                      \
            --prefix="${PREFIX}"                                                                   \
            --libdir="${LIBDIR}"                                                                && \
    make -j"$(nproc)"                                                                           && \
    cp ./src/.libs/libcdsprpc.so* ${QAIRT_INSTALL_DIR}/usr/lib/                                 && \
    aarch64-linux-gnu-strip ${QAIRT_INSTALL_DIR}/usr/lib/libcdsprpc.so*

# Fetch the libs and bin from the QAIRT SDK
RUN if [ -z "$QAIRT_SDK_VERSION" ]; then                                                           \
        echo "ERROR : Stopping build. QAIRT_SDK_VERSION is not provided." >&2;                     \
        exit 1;                                                                                    \
    else                                                                                           \
        export QAIRT_SDK_ZIP_NAME=v${QAIRT_SDK_VERSION}.zip                                     && \
        export QAIRT_SDK_LIB_PATH=${QAIRT_DOWNLOAD_DIR}/qairt/${QAIRT_SDK_VERSION}/lib          && \
        export QAIRT_SDK_BIN_PATH=${QAIRT_DOWNLOAD_DIR}/qairt/${QAIRT_SDK_VERSION}/bin          && \
        wget -t 10 -T 3600 -P ${QAIRT_DOWNLOAD_DIR}                                                \
                https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/${QAIRT_SDK_VERSION}/${QAIRT_SDK_ZIP_NAME} && \
        cd ${QAIRT_DOWNLOAD_DIR}                                                                && \
        unzip ${QAIRT_SDK_ZIP_NAME}                                                             && \
        rm -rf ${QAIRT_SDK_ZIP_NAME}                                                            && \
        cp -r ${QAIRT_DOWNLOAD_DIR}/qairt/${QAIRT_SDK_VERSION}/include/SNPE/*                      \
                ${QAIRT_INSTALL_DIR}/usr/include/.                                              && \
        cp -r ${QAIRT_DOWNLOAD_DIR}/qairt/${QAIRT_SDK_VERSION}/include/QNN/*                       \
                ${QAIRT_INSTALL_DIR}/usr/include/.                                              && \
        cp ${QAIRT_SDK_LIB_PATH}/hexagon-v66/unsigned/* ${QAIRT_ADSP_DIR}                       && \
        cp ${QAIRT_SDK_LIB_PATH}/hexagon-v68/unsigned/* ${QAIRT_ADSP_DIR}                       && \
        cp ${QAIRT_SDK_LIB_PATH}/hexagon-v73/unsigned/* ${QAIRT_ADSP_DIR}                       && \
        cp ${QAIRT_SDK_LIB_PATH}/hexagon-v75/unsigned/* ${QAIRT_ADSP_DIR}                       && \
        cp ${QAIRT_SDK_LIB_PATH}/aarch64-oe-linux-gcc11.2/* ${QAIRT_LIB_DIR}                    && \
        cp ${QAIRT_SDK_BIN_PATH}/aarch64-oe-linux-gcc11.2/* ${QAIRT_BIN_DIR}                    && \
        rm -rf ${QAIRT_DOWNLOAD_DIR}/qairt;                                                        \
    fi

# As per requirement, Python 3.12 is required. Debian trixie, provides Python 3.13 by
# default and there is no way to install 3.12 through the APT. So, get it from python
# builder.
FROM --platform=arm64 python:3.12-slim AS python_builder

# QAIRT Image
FROM --platform=arm64 debian:trixie-slim AS qairt_deploy_arm64

# Set base directory
ENV QAIRT_BASE_DIR=/mnt/work
ENV QAIRT_INSTALL_DIR=${QAIRT_BASE_DIR}/deploy

# Install required package
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc                   && \
    apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive                                                                 \
    apt-get install -y --no-install-recommends                                                     \
                    libatomic1 libyaml-0-2 gpg curl ca-certificates                             && \
    update-ca-certificates                                                                      && \
    install -d -m 0700 /var/lib/apt/gnupg                                                       && \
    install -d -m 0755 /etc/apt/keyrings                                                        && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x33EF0ACBC6FE252590ABBAF21C70EB0C444248D7" | \
    env GNUPGHOME=/var/lib/apt/gnupg gpg --dearmor                                                 \
            -o /etc/apt/keyrings/qcom-ppa.gpg                                                   && \
    echo "deb [signed-by=/etc/apt/keyrings/qcom-ppa.gpg] https://ppa.launchpadcontent.net/ubuntu-qcom-iot/qcom-ppa/ubuntu noble main" \
    > /etc/apt/sources.list.d/qcom-ppa.list                                                     && \
    apt update &&                                                                                  \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends qcom-adreno1      && \
    apt-get autoremove -y                                                                       && \
    apt-get clean &&                                                                               \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

COPY --from=python_builder /usr/local /opt/python

# Install Python packages in virtual environment
ENV VIRTUAL_ENV=/opt/venv
RUN /opt/python/bin/python3 -m venv ${VIRTUAL_ENV}                                              && \
    . ${VIRTUAL_ENV}/bin/activate                                                               && \
    pip3 install --no-cache-dir numpy>=1.24.4 opencv-python-headless>=4.10.0.84 pillow>=10.4.0

# Set virtual environment as default
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Set workdir
WORKDIR "${QAIRT_BASE_DIR}"

# Create USER and add to video group for accessing v4ls devices
RUN addgroup qcom                                                                               && \
    useradd -s /bin/bash -m -g qcom qairt                                                       && \
    usermod -aG video qairt                                                                     && \
    usermod -aG kmem qairt                                                                      && \
    echo qairt:asd | chpasswd

# Copy libraries and binaries from builder stage
COPY --from=qairt_builder ${QAIRT_INSTALL_DIR}/usr /usr

# Add python wrapper code
COPY src/python ${QAIRT_BASE_DIR}/src/python

# Increase max number of fd to be opened by one process
RUN ulimit -n 16192

# Fix ownership
RUN chown -R qairt:qcom ${QAIRT_BASE_DIR}

# Change user to qairt
USER qairt

# Set workdir
WORKDIR "${QAIRT_BASE_DIR}"
