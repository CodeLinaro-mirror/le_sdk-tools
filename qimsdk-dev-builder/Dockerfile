# Mandatory for --target qimsdk_app_deploy only: the qimsdk-debian deploy image to base it on
ARG QIMSDK_ARG_DEPLOY_BASE_IMAGE=qimsdk-deploy-base-image-not-set
# Platform of that deploy image; arm64, so an x86 host never looks for an amd64 variant of it
ARG QIMSDK_ARG_DEPLOY_PLATFORM=linux/arm64

# QIMSDK Builder Image
FROM debian:trixie-slim AS qimsdk_dev_builder

# Add root to plugdev group
RUN usermod -aG plugdev root

# Add deb-src for everything
RUN sed -Ei 's/^Types: deb$/Types: deb deb-src/'  /etc/apt/sources.list.d/debian.sources

# Add arm64 to dpkg
RUN dpkg --add-architecture arm64

# Packages installed for the native arch, needed to establish the scripts + the cmake build system:
#   gpg curl ca-certificates git wget cmake crossbuild-essential-arm64 binutils-aarch64-linux-gnu
#   rsync dpkg-dev pkgconf:arm64 libc6:arm64 libgcc-s1:arm64 libstdc++6:arm64

# Build time dependencies, needed for qimsdk's gstreamer/gst-plugin-base compilation:
#   libgstreamer1.0-dev:arm64 libgstreamer-plugins-base1.0-dev:arm64 libglib2.0-dev:arm64
#   libjson-glib-dev:arm64

# App Builder SDK (cpp): libyaml-cpp-dev:arm64

# Installing required apt packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends gpg curl  \
            ca-certificates git wget cmake crossbuild-essential-arm64 binutils-aarch64-linux-gnu   \
            rsync dpkg-dev pkgconf:arm64 libc6:arm64 libgcc-s1:arm64 libstdc++6:arm64              \
            libgstreamer1.0-dev:arm64 libgstreamer-plugins-base1.0-dev:arm64                       \
            libglib2.0-dev:arm64 libjson-glib-dev:arm64 libyaml-cpp-dev:arm64                   && \
    apt -y upgrade                                                                              && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Set target sysroot for cross-compilation system
ENV QIMSDK_TARGET_SYSROOT="/"

# Set base directory
ENV QIMSDK_BASE_DIR=/mnt/work
ENV QIMSDK_TMP_DIR=${QIMSDK_BASE_DIR}/tmp
RUN mkdir -p ${QIMSDK_TMP_DIR}

# Add qimsdk install directory
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
ENV QIMSDK_INSTALL_LIB_DIR=${QIMSDK_INSTALL_DIR}/usr/lib
RUN mkdir -p ${QIMSDK_INSTALL_LIB_DIR}

# Add qimsdk debug install directory
ENV QIMSDK_INSTALL_DEBUG_DIR=${QIMSDK_BASE_DIR}/deploy_dbg

# Add qimsdk build directory and logs directory
ENV QIMSDK_BUILD_DIR=${QIMSDK_BASE_DIR}/build
ENV QIMSDK_LOGS_DIR=${QIMSDK_BASE_DIR}/logs
RUN mkdir -p ${QIMSDK_BUILD_DIR}
RUN mkdir -p ${QIMSDK_LOGS_DIR}

# Add development image scripts
ENV QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/scripts/
COPY scripts-dbg/common.sh ${QIMSDK_SCRIPTS}/common.sh

# Set up download directory
ENV QIMSDK_DOWNLOAD_DIR=${QIMSDK_BASE_DIR}/downloads
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}

# Set max build jobs
ARG QIMSDK_ARG_MAX_JOBS
ENV QIMSDK_MAX_JOBS="${QIMSDK_ARG_MAX_JOBS}"

# Add the Ubuntu QCOM PPA as source-only (safe to fetch source on Debian)
RUN install -d -m 0755 /etc/apt/keyrings                                                        && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x33EF0ACBC6FE252590ABBAF21C70EB0C444248D7" | \
            gpg --dearmor -o /etc/apt/keyrings/qcom-ppa.gpg                                     && \
    echo "deb-src [signed-by=/etc/apt/keyrings/qcom-ppa.gpg] https://ppa.launchpadcontent.net/ubuntu-qcom-iot/qcom-ppa/ubuntu noble main" \
            > /etc/apt/sources.list.d/qcom-ppa-src.list

# Update and clean, fetch GStreamer base, good and bad plugins
RUN DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    cd ${QIMSDK_DOWNLOAD_DIR}                                                                   && \
    apt source gst-plugins-base1.0 gst-plugins-good1.0 gst-plugins-bad1.0                       && \
    apt-get autoremove -y                                                                       && \
    apt-get clean                                                                               && \
    rm -rf /var/lib/apt/lists* /var/tmp/*

# Automatically save gst source package version and set up gst source directories
RUN GST_PLUGINS_BASE_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base*                       \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION} init          && \
    git config --global --add safe.directory                                                       \
            ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}              && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}                  \
            config --global user.name "username"                                                && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}                  \
            config --global user.email "email"                                                  && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}                  \
            add --all                                                                           && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-${GST_PLUGINS_BASE_VERSION}                  \
            commit -m "Initial Plugins Base Commit"                                             && \
    echo "export GST_PLUGINS_BASE_VERSION=${GST_PLUGINS_BASE_VERSION}" >> /root/.bashrc

RUN GST_PLUGINS_GOOD_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good*                       \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION} init          && \
    git config --global --add safe.directory                                                       \
            ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}              && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}                  \
            config --global user.name "username"                                                && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}                  \
            config --global user.email "email"                                                  && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}                  \
            add --all                                                                           && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-${GST_PLUGINS_GOOD_VERSION}                  \
            commit -m "Initial Plugins Good Commit"                                             && \
    echo "export GST_PLUGINS_GOOD_VERSION=${GST_PLUGINS_GOOD_VERSION}" >> /root/.bashrc

RUN GST_PLUGINS_BAD_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad*                         \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION} init            && \
    git config --global --add safe.directory                                                       \
            ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                    \
            config --global user.name "username"                                                && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                    \
            config --global user.email "email"                                                  && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                    \
            add --all                                                                           && \
    git -C ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-${GST_PLUGINS_BAD_VERSION}                    \
            commit -m "Initial Plugins Bad Commit"                                              && \
    echo "export GST_PLUGINS_BAD_VERSION=${GST_PLUGINS_BAD_VERSION}" >> /root/.bashrc

# Initialize environment variables
ENV QIMSDK_SRC_DIR=${QIMSDK_BASE_DIR}/src

# gst-qti-oss-patches: fetch
ENV QIMSDK_PATH_TO_GST_META=${QIMSDK_SRC_DIR}/gst-qti-oss-patches
RUN GST_PLUGINS_BASE_VERSION=$(find ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base*                       \
            -maxdepth 1 -type d | head -1 | sed 's/.*-//')                                      && \
    mkdir -p ${QIMSDK_PATH_TO_GST_META}                                                         && \
    git -C ${QIMSDK_PATH_TO_GST_META} init                                                      && \
    git -C ${QIMSDK_PATH_TO_GST_META}                                                              \
            remote add origin https://github.com/qualcomm/gst-qti-oss-patches.git               && \
    git -C ${QIMSDK_PATH_TO_GST_META} fetch --depth 1 origin ${GST_PLUGINS_BASE_VERSION}        && \
    git -C ${QIMSDK_PATH_TO_GST_META} checkout FETCH_HEAD

# qimsdk: fetch
ARG QIMSDK_ARG_GST_PLUGINS_TAG
ENV QIMSDK_REPO_DIR=${QIMSDK_SRC_DIR}/qimsdk
RUN mkdir -p ${QIMSDK_REPO_DIR}                                                                 && \
    git -C ${QIMSDK_REPO_DIR} init                                                              && \
    git -C ${QIMSDK_REPO_DIR}                                                                      \
            remote add origin https://github.com/qualcomm/qimsdk.git                            && \
    git -C ${QIMSDK_REPO_DIR} fetch --depth 1 origin "${QIMSDK_ARG_GST_PLUGINS_TAG:-main}"      && \
    git -C ${QIMSDK_REPO_DIR} checkout FETCH_HEAD

# Add development image scripts
ENV QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/scripts/
COPY scripts ${QIMSDK_SCRIPTS}

# Source container helper scripts from bashrc
RUN echo "source ${QIMSDK_SCRIPTS}/env_setup.sh" >> /root/.bashrc

# Change workdir back to base dir from downloads dir
WORKDIR ${QIMSDK_BASE_DIR}

# Call wrapper function to apply all patches
RUN bash /root/.bashrc builder-apply-patches

# Copy all needed headers from QTI-Patched gst-plugins-base/-good/-bad
# Manual copying done instead of compiling open-source gst to reduce image size by avoiding debian-
# rules build and gigabytes worth of dependency packages needed to establish the build environment
ENV GST_HEADERS_DESTINATION=/usr/include/gstreamer-1.0/
RUN cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0-*                                             && \
    rsync -a --relative --prune-empty-dirs  --include='*/' --include='*.h' --exclude='*'           \
            "gst/." "${GST_HEADERS_DESTINATION}/"                                               && \
    cd ./gst-libs                                                                               && \
    rsync -a --relative --prune-empty-dirs  --include='*/' --include='*.h' --exclude='*'           \
            "gst/." "${GST_HEADERS_DESTINATION}/"                                               && \
    cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0-*                                             && \
    rsync -a --relative --prune-empty-dirs  --include='*/' --include='*.h' --exclude='*'           \
            "gst/." "${GST_HEADERS_DESTINATION}/"                                               && \
    cd ./gst-libs                                                                               && \
    rsync -a --relative --prune-empty-dirs  --include='*/' --include='*.h' --exclude='*'           \
            "gst/." "${GST_HEADERS_DESTINATION}/"                                               && \
    cd ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-bad1.0-*                                              && \
    rsync -a --relative --prune-empty-dirs  --include='*/' --include='*.h' --exclude='*'           \
            "gst/." "${GST_HEADERS_DESTINATION}/"                                               && \
    cd ./gst-libs                                                                               && \
    rsync -a --relative --prune-empty-dirs  --include='*/' --include='*.h' --exclude='*'           \
            "gst/." "${GST_HEADERS_DESTINATION}/"                                               && \
    rm -rf ${QIMSDK_DOWNLOAD_DIR}/gst*

# Call wrapper build function to compile and install gst plugins
RUN bash /root/.bashrc builder-incremental-build

# QIMSDK App Deploy Image: the qimsdk-debian deploy image + the app binaries staged in
# ARTIFACT_INSTALL. Build it only after the app is built and staged (see README "App Deploy Image").
#   docker build --target qimsdk_app_deploy                                                        \
#       --build-arg QIMSDK_ARG_DEPLOY_BASE_IMAGE=<qimsdk-debian-deploy-image>                      \
#       [--build-arg QIMSDK_ARG_ARTIFACT_INSTALL=<dir-in-build-context>]                           \
#       -t <image-as-microservice-yaml-file-needs-it> .
# BuildKit skips this stage, and never resolves its base image, when another target is built.
FROM --platform=${QIMSDK_ARG_DEPLOY_PLATFORM} ${QIMSDK_ARG_DEPLOY_BASE_IMAGE} AS qimsdk_app_deploy

ARG QIMSDK_ARG_ARTIFACT_INSTALL=ARTIFACT_INSTALL
COPY --chmod=0755 ${QIMSDK_ARG_ARTIFACT_INSTALL}/ /usr/bin/
