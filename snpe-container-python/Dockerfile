# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

ARG QML_ARG_BASE_IMAGE
# QML Image
FROM ${QML_ARG_BASE_IMAGE} AS qml_builder

RUN dpkg --add-architecture arm64

# Installing required apt packages
RUN apt-get update                                                                              && \
    apt-get install -y curl unzip git autoconf automake libtool build-essential libbsd-dev         \
            libbsd-dev:arm64 libyaml-dev libyaml-dev:arm64 pkg-config m4                           \
            crossbuild-essential-arm64 binutils-aarch64-linux-gnu                               && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# Set base directory
ARG QML_ARG_BASE_DIR
ENV QML_BASE_DIR=${QML_ARG_BASE_DIR}
ENV QML_DOWNLOAD_DIR=${QML_ARG_BASE_DIR}/downloads
ENV QML_INSTALL_DIR=${QML_ARG_BASE_DIR}/deploy

# Create necessary directories
RUN mkdir -p ${QML_DOWNLOAD_DIR} ${QML_INSTALL_DIR}

# Add scripts
ADD scripts/docker/ ${QML_BASE_DIR}/scripts

# Set workdir
WORKDIR "${QML_BASE_DIR}"

# Set base directory
ARG QML_ARG_SDK_VERSION
ENV QML_SDK_VERSION=${QML_ARG_SDK_VERSION}

ARG QML_ARG_TARGET_PLATFORM
ENV QML_TARGET_PLATFORM=${QML_ARG_TARGET_PLATFORM}

# Build fastrpc
RUN cd "${QML_DOWNLOAD_DIR}"                                                                    && \
    git clone --depth 1 https://github.com/quic/fastrpc.git                                     && \
    cd ${QML_DOWNLOAD_DIR}/fastrpc                                                              && \
    autoreconf -is                                                                              && \
    BUILD_ARCH="$(dpkg --print-architecture)"                                                   && \
    TARGET_ARCH=arm64                                                                           && \
    TARGET_TRIPLET=aarch64-linux-gnu                                                            && \
    PREFIX="${QML_INSTALL_DIR}/usr"                                                             && \
    LIBDIR="${PREFIX}/lib/${TARGET_TRIPLET}"                                                    && \
    mkdir -p ${LIBDIR}                                                                          && \
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
    fi &&                                                                                          \
    CFLAGS='-UMACHINE_NAME_PATH -DMACHINE_NAME_PATH=\"/run/device-model\"'                         \
    CC="${CC}" AR="${AR}" RANLIB="${RANLIB}"                                                       \
    ./configure                                                                                    \
        ${CONFIGURE_ARGS}                                                                          \
        --prefix="${PREFIX}"                                                                       \
        --libdir="${LIBDIR}"                                                                    && \
    make -j"$(nproc)"  &&                                                                          \
    make install

# Copy SNPE libraries and binaries to /usr/lib/ and /usr/bin/ and models to /opt
RUN mkdir -p ${QML_INSTALL_DIR}/snpe/usr/lib/rfsa/adsp/                                         && \
    mkdir -p ${QML_INSTALL_DIR}/snpe/usr/bin/                                                   && \
    mkdir -p ${QML_INSTALL_DIR}/snpe/opt/                                                       && \
    bash ${QML_BASE_DIR}/scripts/all_scripts.sh qml-install-libraries-snpe

RUN mkdir -p ${QML_INSTALL_DIR}/snpe/usr/lib                                                    && \
    cp -P ${QML_INSTALL_DIR}/usr/lib/aarch64-linux-gnu/libcdsprpc.so*                              \
          ${QML_INSTALL_DIR}/snpe/usr/lib/                                                      && \
    cp -P ${QML_INSTALL_DIR}/usr/lib/aarch64-linux-gnu/libadsprpc.so*                              \
          ${QML_INSTALL_DIR}/snpe/usr/lib/

# QML Image
FROM --platform=arm64 ${QML_ARG_BASE_IMAGE} AS qml_arm64

# Set base directory
ARG QML_ARG_BASE_DIR
ENV QML_BASE_DIR=${QML_ARG_BASE_DIR}

# Enable color prompt
# Install required apt packages
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc                   && \
    apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive                                                                 \
    apt-get install -y --no-install-recommends python3 python3-pip python3-venv                    \
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

# Install Python packages in virtual environment
ENV VIRTUAL_ENV=${QML_BASE_DIR}/venv
RUN python3 -m venv ${VIRTUAL_ENV}                                                              && \
    . ${VIRTUAL_ENV}/bin/activate                                                               && \
    pip3 install --no-cache-dir numpy>=1.24.4 opencv-python-headless>=4.10.0.84 pillow>=10.4.0

# Set virtual environment as default
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Set workdir
WORKDIR "${QML_BASE_DIR}"

# Add python wrapper code
COPY src/python ${QML_BASE_DIR}/src/python

# Copy libraries and binaries from builder stage
COPY --from=qml_builder ${QML_ARG_BASE_DIR}/deploy/snpe/usr/lib/ /usr/lib/
