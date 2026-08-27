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
ENV QAIRT_SDK_VERSION=${QAIRT_ARG_SDK_VERSION}
ENV QAIRT_SDK_ROOT=/opt/qcom/qairt

# Set up dirs used by fastrpc, comprising of skel binaries for each dsp version
ENV QAIRT_V66_CDSP_DIR=${QAIRT_INSTALL_DIR}/usr/share/qcom/v66
ENV QAIRT_V68_CDSP_DIR=${QAIRT_INSTALL_DIR}/usr/share/qcom/v68
ENV QAIRT_V73_CDSP_DIR=${QAIRT_INSTALL_DIR}/usr/share/qcom/v73
ENV QAIRT_V75_CDSP_DIR=${QAIRT_INSTALL_DIR}/usr/share/qcom/v75

# Create necessary directories
RUN mkdir -p ${QAIRT_DOWNLOAD_DIR} ${QAIRT_INSTALL_DIR} ${QAIRT_LIB_DIR} ${QAIRT_BIN_DIR}          \
             ${QAIRT_V66_CDSP_DIR} ${QAIRT_V68_CDSP_DIR} ${QAIRT_V73_CDSP_DIR}                     \
             ${QAIRT_V75_CDSP_DIR} ${QAIRT_INSTALL_DIR}/usr/include

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
        [ ! -d "${QAIRT_DOWNLOAD_DIR}/qairt/${QAIRT_SDK_VERSION}/include/QAIRT" ] ||               \
                cp -rf "${QAIRT_DOWNLOAD_DIR}/qairt/${QAIRT_SDK_VERSION}/include/QAIRT"            \
                "${QAIRT_INSTALL_DIR}/usr/include/"                                             && \
        cp ${QAIRT_SDK_LIB_PATH}/hexagon-v66/unsigned/* ${QAIRT_V66_CDSP_DIR}                   && \
        cp ${QAIRT_SDK_LIB_PATH}/hexagon-v68/unsigned/* ${QAIRT_V68_CDSP_DIR}                   && \
        cp ${QAIRT_SDK_LIB_PATH}/hexagon-v73/unsigned/* ${QAIRT_V73_CDSP_DIR}                   && \
        cp ${QAIRT_SDK_LIB_PATH}/hexagon-v75/unsigned/* ${QAIRT_V75_CDSP_DIR}                   && \
        cp ${QAIRT_SDK_LIB_PATH}/aarch64-oe-linux-gcc11.2/* ${QAIRT_LIB_DIR}                    && \
        cp ${QAIRT_SDK_BIN_PATH}/aarch64-oe-linux-gcc11.2/* ${QAIRT_BIN_DIR};                      \
    fi

# QAIRT PYTHON SDK expects following:
# 1. /sdk.yaml
# 2. /lib/aarch64-oe-linux-gcc11.2/<QNN_SNPE_LIBS>
# 4. /lib/aarch64-oe-linux-gcc11.2/lib/python (pruned for ARM)

ENV QAIRT_SDK_PRUNED=${QAIRT_INSTALL_DIR}${QAIRT_SDK_ROOT}

RUN mkdir -p ${QAIRT_SDK_PRUNED}                                                                && \
    mkdir -p ${QAIRT_SDK_PRUNED}/lib                                                            && \
    mkdir -p ${QAIRT_SDK_PRUNED}/lib/python                                                     && \
    cp ${QAIRT_DOWNLOAD_DIR}/qairt/${QAIRT_SDK_VERSION}/sdk.yaml ${QAIRT_SDK_PRUNED}            && \
    cp ${QAIRT_DOWNLOAD_DIR}/qairt/${QAIRT_SDK_VERSION}/bin/check-python-dependency                \
       ${QAIRT_SDK_PRUNED}/

# Copy pruned version of python
RUN cd ${QAIRT_DOWNLOAD_DIR}/qairt/${QAIRT_SDK_VERSION}/lib/python                              && \
    find .                                                                                         \
      -type d \(                                                                                   \
        -name "linux-x86_64" -o                                                                    \
        -name "x86-64-linux-clang" -o                                                              \
        -name "windows-x86_64" -o                                                                  \
        -name "windows-arm64ec" -o                                                                 \
        -name "arm64ec-windows-msvc"                                                               \
      \) -prune -o                                                                                 \
      -type f -print | while read file; do                                                         \
        mkdir -p ${QAIRT_SDK_PRUNED}/lib/python/$(dirname "$file");                                \
        cp "$file" ${QAIRT_SDK_PRUNED}/lib/python/"$file";                                         \
      done                                                                                      && \
    rm -rf ${QAIRT_DOWNLOAD_DIR}/qairt

# As per requirement, Python 3.12 is required. Debian trixie, provides Python 3.13 by
# default and there is no way to install 3.12 through the APT. So, get it from python
# builder.
FROM --platform=arm64 python:3.12-slim AS python_builder

# QAIRT Image
FROM --platform=arm64 debian:trixie-slim AS qairt_deploy_arm64

# Set base directory
ENV QAIRT_BASE_DIR=/mnt/work
ENV QAIRT_INSTALL_DIR=${QAIRT_BASE_DIR}/deploy
ENV QAIRT_SDK_ROOT=/opt/qcom/qairt
ENV QAIRT_SDK_PRUNED=${QAIRT_INSTALL_DIR}${QAIRT_SDK_ROOT}

# Install required package
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc                   && \
    apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive                                                                 \
    apt-get install -y --no-install-recommends                                                     \
                    libatomic1 libyaml-0-2 gpg curl ca-certificates nano                        && \
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

# Create yaml file specifying directories of dsp skel binaries needed for fastrpc
RUN mkdir -p /usr/share/qcom/conf.d                                                             && \
    {                                                                                              \
        echo '# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.';               \
        echo '# SPDX-License-Identifier: MIT';                                                     \
        echo 'machines:';                                                                          \
        echo '  Qualcomm Technologies, Inc. SDM845 HDK:';                                          \
        echo '    DSP_LIBRARY_PATH: v66';                                                          \
        echo '  Qualcomm QCS615 IQ 615 EVK:';                                                      \
        echo '    DSP_LIBRARY_PATH: v66';                                                          \
        echo '  Qualcomm Technologies, Inc. QCS615 Ride (IQ-615 Beta EVK):';                       \
        echo '    DSP_LIBRARY_PATH: v66';                                                          \
        echo '  Qualcomm Technologies, Inc. Robotics RB3gen2:';                                    \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Robotics RB3gen2 addons vision mezz platform:';        \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Glymur CRD:';                                          \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Kaanapali MTP:';                                       \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Purwa IoT EVK:';                                       \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. QCM6490 IDP:';                                         \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Thundercomm RUBIK Pi 3:';                                                          \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Radxa Dragon Q6A:';                                                                \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Robotics RB5:';                                        \
        echo '    DSP_LIBRARY_PATH: v68';                                                          \
        echo '  Qualcomm Technologies, Inc. Lemans EVK:';                                          \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Addons IQ 9075 EVK:';                                  \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Hamoa IoT EVK:';                                       \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Shikra CQS EVK:';                                      \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. SM8750 MTP:';                                          \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm SA8775P Ride:';                                                           \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm SA8775P Ride Rev3:';                                                      \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Lemans Ride:';                                         \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Qualcomm Technologies, Inc. Lemans Ride Rev3:';                                    \
        echo '    DSP_LIBRARY_PATH: v73';                                                          \
        echo '  Arduino VENTUNO Q:';                                                               \
        echo '    DSP_LIBRARY_PATH: v75';                                                          \
        echo '  Qualcomm Technologies, Inc. Monaco EVK:';                                          \
        echo '    DSP_LIBRARY_PATH: v75';                                                          \
        echo '  Qualcomm Technologies, Inc. Monaco Monza addons:';                                 \
        echo '    DSP_LIBRARY_PATH: v75';                                                          \
        echo '  Qualcomm Technologies, Inc. QCS8300 Ride:';                                        \
        echo '    DSP_LIBRARY_PATH: v75';                                                          \
    } > /usr/share/qcom/conf.d/hexagon-dsp-binaries.yaml

COPY --from=python_builder /usr/local /opt/python

# Create USER and add to video group for accessing v4ls devices
RUN addgroup qcom                                                                               && \
    useradd -s /bin/bash -m -g qcom qairt                                                       && \
    usermod -aG video qairt                                                                     && \
    usermod -aG kmem qairt                                                                      && \
    echo qairt:asd | chpasswd

# Set workdir
WORKDIR "${QAIRT_BASE_DIR}"

# Setup python virtual environment
ENV VIRTUAL_ENV=/opt/venv
RUN /opt/python/bin/python3 -m venv ${VIRTUAL_ENV}                                              && \
    chown -R qairt:qcom ${VIRTUAL_ENV}

# Set virtual environment as default
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV QAIRT_SDK_ROOT=/opt/qcom/qairt

# Copy SNPE python wrapper scripts
COPY src/python ${QAIRT_BASE_DIR}/src/python

# Copy libraries and binaries from builder stage
COPY --from=qairt_builder ${QAIRT_INSTALL_DIR}/usr /usr

# Copy qairt pruned SDK from build stage
RUN mkdir -p ${QAIRT_SDK_ROOT}
COPY --from=qairt_builder --chown=qairt:qcom                                                       \
    ${QAIRT_SDK_PRUNED} ${QAIRT_SDK_ROOT}

RUN ln -s /usr/lib ${QAIRT_SDK_ROOT}/lib/aarch64-oe-linux-gcc11.2

RUN grep -q '"debian"' ${QAIRT_SDK_ROOT}/lib/python/qti/aisw/core/model_level_api/utils/__init__.py || \
    sed -i '/oe_identifiers/ s/"ubuntu"[[:space:]]*]/"ubuntu", "debian"]/' \
        ${QAIRT_SDK_ROOT}/lib/python/qti/aisw/core/model_level_api/utils/__init__.py && \
    grep -q '"debian"' ${QAIRT_SDK_ROOT}/lib/python/qti/aisw/genai/__init__.py || \
    sed -i '/oe_identifiers/ s/"ubuntu"[[:space:]]*]/"ubuntu", "debian"]/' \
        ${QAIRT_SDK_ROOT}/lib/python/qti/aisw/genai/__init__.py && \
    grep -q '"debian"' ${QAIRT_SDK_ROOT}/lib/python/qairt/__init__.py || \
    sed -i '/oe_identifiers/ s/"ubuntu"[[:space:]]*]/"ubuntu", "debian"]/' \
        ${QAIRT_SDK_ROOT}/lib/python/qairt/__init__.py

# Fix ownership
RUN chown -R qairt:qcom ${QAIRT_BASE_DIR}

# Change user to qairt
USER qairt

# Install required packages from the python QAIRT SDK
RUN pip install --no-cache-dir --no-input  qairt-dev $(                                            \
    sed -n '/required_packages = {/,/^    }/p' ${QAIRT_SDK_ROOT}/check-python-dependency           \
  | sed -n 's/.*"\(.*\)": "\(.*\)".*/\1==\2/p'                                                     \
)

# Set workdir
WORKDIR "${QAIRT_BASE_DIR}"
