# TensorFlow Lite Development Image for Debian
FROM debian:trixie-slim AS tflite_build

# Add deb-src for everything
RUN sed -Ei 's/^Types: deb$/Types: deb deb-src/'  /etc/apt/sources.list.d/debian.sources

# Add arm64 to dpkg
RUN dpkg --add-architecture arm64

# Packages installed for the native arch, needed to establish the build system:
#   git cmake wget xz-utils curl gpg
#   gobject-introspection locales-all ninja-build
#   debhelper crossbuild-essential-arm64 binutils-aarch64-linux-gnu
#   pkgconf:arm64 libc6:arm64 libgcc-s1:arm64 libstdc++6:arm64

# Build time dependencies for TensorFlow Lite:
#   libprotobuf-dev:arm64, protobuf-compiler:arm64

# Build time dependencies for FastRPC:
#   libyaml-dev:arm64, libbsd-dev:arm64

# Installing required apt packages
RUN apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends           \
            ca-certificates git rsync unzip cmake wget xz-utils curl gpg                           \
            gobject-introspection locales-all ninja-build debhelper crossbuild-essential-arm64     \
            binutils-aarch64-linux-gnu pkgconf:arm64 libc6:arm64 libgcc-s1:arm64                   \
            libstdc++6:arm64 libprotobuf-dev:arm64 protobuf-compiler:arm64                         \
            libyaml-dev:arm64 libbsd-dev:arm64                                                  && \
    update-ca-certificates                                                                      && \
    apt -y upgrade                                                                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Set target sysroot for cross-compilation system
ENV TFLITE_TARGET_SYSROOT="/"

# Set base directory
ENV TFLITE_BASE_DIR=/mnt/work
ENV TFLITE_TMP_DIR=${TFLITE_BASE_DIR}/tmp
RUN mkdir -p ${TFLITE_TMP_DIR}

# Add host-tools directory
ENV TFLITE_HOST_TOOLS_DIR=${TFLITE_BASE_DIR}/host-tools

# Add tflite install directory
ENV TFLITE_INSTALL_DIR=${TFLITE_BASE_DIR}/deploy
ENV TFLITE_INSTALL_LIB_DIR=${TFLITE_INSTALL_DIR}/usr/lib

RUN mkdir -p ${TFLITE_INSTALL_LIB_DIR}

# Set up dirs used by fastrpc, comprising of skel binaries for each dsp version
ENV TFLITE_V66_CDSP_DIR=${TFLITE_INSTALL_DIR}/usr/share/qcom/v66
ENV TFLITE_V68_CDSP_DIR=${TFLITE_INSTALL_DIR}/usr/share/qcom/v68
ENV TFLITE_V73_CDSP_DIR=${TFLITE_INSTALL_DIR}/usr/share/qcom/v73
ENV TFLITE_V75_CDSP_DIR=${TFLITE_INSTALL_DIR}/usr/share/qcom/v75
RUN mkdir -p ${TFLITE_V66_CDSP_DIR} ${TFLITE_V68_CDSP_DIR} ${TFLITE_V73_CDSP_DIR}                  \
        ${TFLITE_V75_CDSP_DIR}

# Add tflite debug install directory
ENV TFLITE_INSTALL_DEBUG_DIR=${TFLITE_BASE_DIR}/deploy_dbg

# Add tflite build directory and logs directory
ENV TFLITE_BUILD_DIR=${TFLITE_BASE_DIR}/build
ENV TFLITE_LOGS_DIR=${TFLITE_BASE_DIR}/logs
RUN mkdir -p ${TFLITE_BUILD_DIR}
RUN mkdir -p ${TFLITE_LOGS_DIR}

# Set up download directory
ENV TFLITE_DOWNLOAD_DIR=${TFLITE_BASE_DIR}/downloads
RUN mkdir -p ${TFLITE_DOWNLOAD_DIR}

RUN git config --global user.name "username"                                                    && \
    git config --global user.email "email"

# Clone Tensorflow Lite
ENV TFLITE_TF_LITE_MAJOR="2"
ENV TFLITE_TF_LITE_MINOR="16"
ENV TFLITE_TF_LITE_PATCH="2"
ENV TFLITE_TF_SRC_DIR=${TFLITE_DOWNLOAD_DIR}/tensorflow
RUN git config --global http.postBuffer 157286400                                               && \
    git clone --progress https://github.com/tensorflow/tensorflow.git --single-branch              \
            --branch r${TFLITE_TF_LITE_MAJOR}.${TFLITE_TF_LITE_MINOR} ${TFLITE_TF_SRC_DIR}

# Clone meta-qcom-distro and apply tflite patches for it
ENV TFLITE_META_QCOM_DISTRO_DIR=${TFLITE_DOWNLOAD_DIR}/meta-qcom-distro
ENV TFLITE_TFLITE_PATCHES_DIR=${TFLITE_META_QCOM_DISTRO_DIR}/recipes-ml/tflite/files/tflite
RUN git clone https://github.com/qualcomm-linux/meta-qcom-distro.git --single-branch --branch main \
            ${TFLITE_META_QCOM_DISTRO_DIR}                                                      && \
    git -C ${TFLITE_TF_SRC_DIR}                                                                    \
            am ${TFLITE_TFLITE_PATCHES_DIR}/0*                                                  && \
    git -C ${TFLITE_TF_SRC_DIR}                                                                    \
            am ${TFLITE_TFLITE_PATCHES_DIR}/${TFLITE_TF_LITE_MAJOR}.${TFLITE_TF_LITE_MINOR}/0*

# Clone flatbuffers. Use the exact git tag as specified in tflite dependency
ENV TFLITE_FLATBUFFERS_23_5_26_SRC_DIR=${TFLITE_DOWNLOAD_DIR}/flatbuffers_23.5.26
ENV TFLITE_FLATBUFFERS_23_5_26_INSTALL_DIR=${TFLITE_HOST_TOOLS_DIR}/flatbuffers_23.5.26/usr
RUN TFLITE_FLATBUFFERS_23_5_26_TAG=$(cat ${TFLITE_TF_SRC_DIR}/tensorflow/lite/tools/cmake/modules/flatbuffers.cmake | \
            grep GIT_TAG | rev | cut -d ' ' -f 1 | rev)                                         && \
    git clone --progress https://github.com/google/flatbuffers.git                                 \
            --single-branch --branch master ${TFLITE_FLATBUFFERS_23_5_26_SRC_DIR}               && \
    git -C ${TFLITE_FLATBUFFERS_23_5_26_SRC_DIR} checkout -b work ${TFLITE_FLATBUFFERS_23_5_26_TAG}

# Clone abseil-cpp. Use the git tag compatible with tflite 2.16
ENV TFLITE_ABSEIL_CPP_DIR=${TFLITE_DOWNLOAD_DIR}/abseil-cpp
RUN TFLITE_ABSEIL_CPP_TAG=d38452e1ee03523a208362186fd42248ff2609f6                              && \
    git clone --progress https://github.com/abseil/abseil-cpp.git                                  \
            --single-branch --branch lts_2025_08_14 ${TFLITE_ABSEIL_CPP_DIR}                    && \
    git -C ${TFLITE_ABSEIL_CPP_DIR} checkout -b work ${TFLITE_ABSEIL_CPP_TAG}

# Add CMake redirects
COPY cmake ${TFLITE_DOWNLOAD_DIR}/cmake

# Build fastrpc
RUN cd "${TFLITE_DOWNLOAD_DIR}"                                                                 && \
    git clone --depth 1 https://github.com/quic/fastrpc.git --branch v1.0.6                     && \
    cd fastrpc                                                                                  && \
    autoreconf -is                                                                              && \
    BUILD_ARCH="$(dpkg --print-architecture)"                                                   && \
    TARGET_ARCH=arm64                                                                           && \
    TARGET_TRIPLET=aarch64-linux-gnu                                                            && \
    PREFIX="${TFLITE_INSTALL_DIR}/usr"                                                          && \
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
    cp ./src/.libs/libcdsprpc.so* ${TFLITE_INSTALL_DIR}/usr/lib/                                && \
    aarch64-linux-gnu-strip ${TFLITE_INSTALL_DIR}/usr/lib/libcdsprpc.so*

# QAIRT (QNN SDK): fetch and copy the needed headers and libraries
ARG TFLITE_ARG_QNP_VERSION
RUN if [ -z "$TFLITE_ARG_QNP_VERSION" ]; then                                                      \
        echo "WARN : TFLITE_ARG_QNP_VERSION is not provided. Skipping QNN installation." >&2;      \
    else                                                                                           \
        export TFLITE_QNP_SDK=v${TFLITE_ARG_QNP_VERSION}.zip                                    && \
        export TFLITE_QNN_LIB_PATH=${TFLITE_DOWNLOAD_DIR}/qairt/${TFLITE_ARG_QNP_VERSION}/lib/  && \
        wget -t 10 -T 3600 -P ${TFLITE_DOWNLOAD_DIR}                                               \
        https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/${TFLITE_ARG_QNP_VERSION}/${TFLITE_QNP_SDK} && \
        cd ${TFLITE_DOWNLOAD_DIR}                                                               && \
        unzip ${TFLITE_QNP_SDK}                                                                 && \
        rm -f ${TFLITE_QNP_SDK}                                                                 && \
        TFLITE_ARG_QNP_SDK_VERSION=$(ls qairt)                                                  && \
        cp -r ${TFLITE_DOWNLOAD_DIR}/qairt/${TFLITE_ARG_QNP_SDK_VERSION}/include/QNN/*             \
            /usr/include/.                                                                      && \
        cp ${TFLITE_QNN_LIB_PATH}/hexagon-v66/unsigned/* ${TFLITE_V66_CDSP_DIR}/                && \
        cp ${TFLITE_QNN_LIB_PATH}/hexagon-v68/unsigned/* ${TFLITE_V68_CDSP_DIR}/                && \
        cp ${TFLITE_QNN_LIB_PATH}/hexagon-v73/unsigned/* ${TFLITE_V73_CDSP_DIR}/                && \
        cp ${TFLITE_QNN_LIB_PATH}/hexagon-v75/unsigned/* ${TFLITE_V75_CDSP_DIR}/                && \
        find "${TFLITE_QNN_LIB_PATH}/aarch64-oe-linux-gcc11.2"                                     \
            -maxdepth 1 -type f                                                                    \
            \(                                                                                     \
                -name 'libQnnGenAiTransformerCpuOpPkg.so' -o                                       \
                -name 'libhta_hexagon_runtime_qnn.so' -o                                           \
                -name 'libPlatformValidatorShared.so' -o                                           \
                -name 'libQnnChrometraceProfilingReader.so' -o                                     \
                -name 'libQnnCpu.so' -o                                                            \
                -name 'libQnnDspNetRunExtensions.so' -o                                            \
                -name 'libQnnDsp.so' -o                                                            \
                -name 'libQnnGenAiTransformerModel.so' -o                                          \
                -name 'libQnnGenAiTransformer.so' -o                                               \
                -name 'libQnnGpuNetRunExtensions.so' -o                                            \
                -name 'libQnnGpuProfilingReader.so' -o                                             \
                -name 'libQnnGpu.so' -o                                                            \
                -name 'libQnnHtaNetRunExtensions.so' -o                                            \
                -name 'libQnnHta.so' -o                                                            \
                -name 'libQnnHtpNetRunExtensions.so' -o                                            \
                -name 'libQnnHtpOptraceProfilingReader.so' -o                                      \
                -name 'libQnnHtpPrepare.so' -o                                                     \
                -name 'libQnnHtpProfilingReader.so' -o                                             \
                -name 'libQnnHtp.so' -o                                                            \
                -name 'libQnnDspV66Stub.so' -o                                                     \
                -name 'libQnnDspV66CalculatorStub.so' -o                                           \
                -name 'libQnnHtpV68CalculatorStub.so' -o                                           \
                -name 'libQnnHtpV68Stub.so' -o                                                     \
                -name 'libQnnHtpV73CalculatorStub.so' -o                                           \
                -name 'libQnnHtpV73Stub.so' -o                                                     \
                -name 'libQnnHtpV75CalculatorStub.so' -o                                           \
                -name 'libQnnHtpV75Stub.so' -o                                                     \
                -name 'libQnnIr.so' -o                                                             \
                -name 'libQnnJsonProfilingReader.so' -o                                            \
                -name 'libQnnModelDlc.so' -o                                                       \
                -name 'libQnnSaver.so' -o                                                          \
                -name 'libQnnSystem.so' -o                                                         \
                -name 'libQnnTFLiteDelegate.so'                                                    \
            \)                                                                                     \
            -exec cp -t "${TFLITE_INSTALL_LIB_DIR}/" {} +                                       && \
        rm -rf ${TFLITE_DOWNLOAD_DIR}/qairt;                                                       \
    fi

# Add development image scripts
ENV TFLITE_SCRIPTS=${TFLITE_BASE_DIR}/scripts/
COPY scripts ${TFLITE_SCRIPTS}

# Source container helper scripts from bashrc
RUN echo "source ${TFLITE_SCRIPTS}/env_setup.sh" >> /root/.bashrc

# Change workdir back to base dir from downloads dir
WORKDIR ${TFLITE_BASE_DIR}

# Build TensorFlow Lite and dependencies
RUN bash /root/.bashrc tflite-incremental-build

# --------------------------------------------------------------------------------------------------

# TFLITE Device Image
FROM --platform=linux/arm64 debian:trixie-slim AS tflite_deploy_arm64

# Set base directory
ENV TFLITE_BASE_DIR=/mnt/work
ENV TFLITE_INSTALL_DIR=${TFLITE_BASE_DIR}/deploy

# Installing dependencies, needed in order for gst plugins to load succesfully runtime:
#  fast rpc runtime dependency:   libyaml-0-2:arm64
RUN apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends           \
            adduser bash-completion nano libyaml-0-2                                            && \
    apt -y upgrade                                                                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Add QTI PPA and install QTI dependencies
#  gpg curl:                        install PPA
#  qcom-adreno1:                    adreno

RUN apt-get update                                                                              && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gpg curl             \
            ca-certificates                                                                     && \
    update-ca-certificates                                                                      && \
    install -d -m 0700 /var/lib/apt/gnupg                                                       && \
    install -d -m 0755 /etc/apt/keyrings                                                        && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x33EF0ACBC6FE252590ABBAF21C70EB0C444248D7" | \
            env GNUPGHOME=/var/lib/apt/gnupg gpg --dearmor                                         \
            -o /etc/apt/keyrings/qcom-ppa.gpg                                                   && \
    echo "deb [signed-by=/etc/apt/keyrings/qcom-ppa.gpg] https://ppa.launchpadcontent.net/ubuntu-qcom-iot/qcom-ppa/ubuntu noble main" \
            > /etc/apt/sources.list.d/qcom-ppa.list                                             && \
    apt update                                                                                  && \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends                          \
            qcom-adreno1                                                                        && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*                                                       && \
    rm -f /etc/profile.d/qcom-adreno-profile.sh /usr/lib/qcom-adreno-vars.sh

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

# Create USER and add to video group for accessing v4ls devices
RUN addgroup qcom                                                                               && \
    useradd -s /bin/bash -m -g qcom tflite                                                      && \
    usermod -aG video tflite                                                                    && \
    usermod -aG kmem tflite                                                                     && \
    echo tflite:asd | chpasswd

# Increase max number of fd to be opened by one process
RUN ulimit -n 16192

# Copy installed binaries to device image
COPY --from=tflite_build ${TFLITE_INSTALL_DIR}/usr /usr

# Change workdir to user home
WORKDIR /home/tflite

# Change user to tflite
USER tflite
