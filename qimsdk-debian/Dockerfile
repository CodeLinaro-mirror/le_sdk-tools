# Input argm for base image name
ARG QIMSDK_ARG_IMAGE_NAME

# QIMSDK Development Image
FROM build AS qimsdk-build

# build time dependencies, needed for gst-plugins-qti-oss compilation:
# gst-plugins-qti-oss is not an apt package, so we need to install its build dependencies manually
#   instead of doing it using 'apt-get build-dep'
#  gst-plugin-mlaconverter:       libeigen3-dev
#  gst-plugin-mlaclassification:  libcairo-dev
#  gst-plugin-mlmetaparser:       libjson-glib-dev
#  gst-plugin-msgbroker:          libmosquitto-dev,
#                                 librdkafka-dev
#  gst-plugin-overlay:            opencl-headers
#  gst-plugin-redissink:          libhiredis-dev
#  gst-plugin-rtspbin:            libgstrtspserver-1.0-dev
#  gst-plugin-restricted-zonedbg: libgstreamer-plugins-bad1.0-dev

# Installing dependencies, needed in order for gst plugins to load succesfully runtime:
#  gstreamer base plugins:        gobject-introspection,
#                                 flex,
#                                 bison,
#                                 libglib2.0-0,
#  glimagesink:                   gstreamer1.0-gl,
#                                 gstreamer1.0-plugins-good,
#                                 libgraphene-1.0-dev,
#                                 libgl1,
#                                 libegl1,
#                                 libwayland-egl1,
#                                 libwayland-dev
#  opencl for tflite:             ocl-icd-libopencl1,
#                                 mesa-opencl-icd,
#                                 libopencl-clang-19-dev
#  software encoder needed for
#    rtspsrc usecases:            gstreamer1.0-plugins-ugly
#  pulseaudio runtime dependency: pulseaudio

# Installing required apt packages
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y                               \
        git tar unzip ssh rsync bash-completion jq cmake android-tools-adb wget pipx xz-utils curl \
        gobject-introspection flex bison locales-all meson ninja-build gpg git-buildpackage        \
        libeigen3-dev libcairo-dev libjson-glib-dev libmosquitto-dev opencl-headers libhiredis-dev \
        libgstrtspserver-1.0-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-gl libglib2.0-0      \
        gstreamer1.0-plugins-good libgl1 libegl1 libwayland-egl1 pulseaudio ocl-icd-libopencl1     \
        gstreamer1.0-plugins-ugly mesa-opencl-icd libopencl-clang-19-dev librdkafka-dev         && \
        apt-get build-dep -y gst-plugins-base1.0 gst-plugins-good1.0                            && \
        apt -y upgrade                                                                          && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Set base directory
ENV QIMSDK_BASE_DIR=/mnt/work
ENV QIMSDK_TMP_DIR=${QIMSDK_BASE_DIR}/tmp
RUN mkdir -p ${QIMSDK_TMP_DIR}

# Add qimsdk install directory
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy

# Add qimsdk prebuilt directory
ENV QIMSDK_PREBUILT_DIR=${QIMSDK_BASE_DIR}/prebuilt

# Add qimsdk debug install directory
ENV QIMSDK_INSTALL_DEBUG_DIR=${QIMSDK_BASE_DIR}/deploy_dbg

# Add qimsdk build directory and logs directory
ENV QIMSDK_BUILD_DIR=${QIMSDK_BASE_DIR}/build
ENV QIMSDK_LOGS_DIR=${QIMSDK_BASE_DIR}/logs
RUN mkdir -p ${QIMSDK_BUILD_DIR}
RUN mkdir -p ${QIMSDK_LOGS_DIR}
RUN mkdir -p ${QIMSDK_PREBUILT_DIR}

# Set up download directory
ENV QIMSDK_DOWNLOAD_DIR=${QIMSDK_BASE_DIR}/downloads
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}

# gst-plugins-base: fetch
RUN git clone https://salsa.debian.org/gstreamer-team/gst-plugins-base1.0.git                      \
    ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-base1.0

# gst-plugins-good: fetch
RUN git clone https://salsa.debian.org/gstreamer-team/gst-plugins-good1.0.git                      \
    ${QIMSDK_DOWNLOAD_DIR}/gst-plugins-good1.0

# Setup Tensorflow Lite 2.20
ENV QIMSDK_TF_SRC_TAR=/usr/src/tensorflow-lite-2.20.tar.gz
ENV QIMSDK_TF_SRC_DIR=/usr/src/tensorflow-2.20

RUN tar -xvzf ${QIMSDK_TF_SRC_TAR} -C /usr/src/

# Initialize environment variables
ENV QIMSDK_SRC_DIR=${QIMSDK_BASE_DIR}/src
ENV QIMSDK_PATH_TO_GST_META=${QIMSDK_SRC_DIR}/meta-qti-gst

# meta-qti-gst: fetch
RUN git clone --progress https://git.codelinaro.org/clo/le/meta-qti-gst.git                        \
        --single-branch --branch imsdk.lnx.2.0.0 ${QIMSDK_SRC_DIR}/meta-qti-gst

# gst-plugins-qti-oss: fetch
RUN git clone --progress                                                                           \
        https://git.codelinaro.org/clo/le/platform/vendor/qcom-opensource/gst-plugins-qti-oss.git  \
        --single-branch --branch imsdk.lnx.2.0.0 ${QIMSDK_SRC_DIR}/gst-plugins-qti-oss

# Add development image scripts
ENV QIMSDK_SCRIPTS=${QIMSDK_BASE_DIR}/scripts/
COPY scripts ${QIMSDK_SCRIPTS}

# Source container helper scripts from bashrc
RUN echo "source ${QIMSDK_SCRIPTS}/env_setup.sh" >> /root/.bashrc

# Change workdir back to base dir from downloads dir
WORKDIR ${QIMSDK_BASE_DIR}

# Copy the Tensorflow Lite's headers and dependent headers to the sysroot
RUN bash /root/.bashrc qimsdk-copy-tf-lite-headers-to-sysroot

# Sync prebuilt libs
RUN bash /root/.bashrc qimsdk-propagate-prebuilt-libs

# Call wrapper function to apply all patches
RUN bash /root/.bashrc qimsdk-apply-patches

# Call wrapper build function to compile and install gst plugins
RUN bash /root/.bashrc qimsdk-incremental-build

# Create directory to save deb packages
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}/debs/

# Copy selected packages to install
RUN cp ${QIMSDK_DOWNLOAD_DIR}/*base-1.0_* ${QIMSDK_DOWNLOAD_DIR}/*alsa_*                           \
       ${QIMSDK_DOWNLOAD_DIR}/*gl_* ${QIMSDK_DOWNLOAD_DIR}/*gtk3_* ${QIMSDK_DOWNLOAD_DIR}/*base_*  \
       ${QIMSDK_DOWNLOAD_DIR}/*base-apps_* ${QIMSDK_DOWNLOAD_DIR}/*good_*                          \
       ${QIMSDK_DOWNLOAD_DIR}/*pulseaudio_* ${QIMSDK_DOWNLOAD_DIR}/*x_*                            \
       ${QIMSDK_DOWNLOAD_DIR}/*gl1.0-0_* ${QIMSDK_DOWNLOAD_DIR}/*base1.0-0_1*                      \
       ${QIMSDK_DOWNLOAD_DIR}/debs/

# --------------------------------------------------------------------------------------------------

# QIMSDK Device Image
FROM debian:trixie-slim AS qimsdk-deploy

# Set base directory
ENV QIMSDK_BASE_DIR=/mnt/work
ENV QIMSDK_INSTALL_DIR=${QIMSDK_BASE_DIR}/deploy
ENV QIMSDK_PREBUILT_DIR=${QIMSDK_BASE_DIR}/prebuilt
ENV QIMSDK_DEB_DIR=${QIMSDK_BASE_DIR}/downloads/debs

# Installing dependencies, needed in order for gst plugins to load succesfully runtime:
#  gstreamer base plugins:        gstreamer1.0-tools,
#                                 gstreamer1.0-plugins-base,
#  gst-plugin-redissink:          libhiredis1.1.0
#  gst-plugin-restrictedzonedbg:  libopencv-imgproc410
#  gst-plugin-rtspbin:            libgstrtspserver-1.0-0
#  gst-plugin-msgbroker:          librdkafka1
#  gstreamer base plugins:        gobject-introspection,
#                                 flex,
#                                 bison,
#                                 libglib2.0-0,
#  glimagesink:                   gstreamer1.0-gl,
#                                 gstreamer1.0-plugins-good,
#                                 libgraphene-1.0-dev,
#                                 libgl1,
#                                 libegl1,
#                                 libwayland-egl1,
#                                 libwayland-dev
#  opencl for tflite:             ocl-icd-libopencl1,
#                                 mesa-opencl-icd,
#                                 libopencl-clang-19-dev
#  software encoder needed for
#    rtspsrc usecases:            gstreamer1.0-plugins-ugly
#  pulseaudio runtime dependency: pulseaudio
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y                               \
        adduser bash-completion nano libhiredis1.1.0 gstreamer1.0-tools ocl-icd-libopencl1 wget    \
        mesa-opencl-icd libopencl-clang-19-dev libgstrtspserver-1.0-0 libopencv-imgproc410         \
        gstreamer1.0-plugins-good pulseaudio gstreamer1.0-plugins-base gstreamer1.0-gl             \
        libgraphene-1.0-dev libgl1 libegl1 libwayland-egl1 libwayland-dev librdkafka1              \
        gstreamer1.0-plugins-ugly                                                               && \
        apt -y upgrade                                                                          && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Enable Backports repo, grab mesa from there
COPY <<EOF /etc/apt/sources.list.d/trixie-backports.sources
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

COPY <<EOF /etc/apt/preferences.d/debian-backports.pref
# for binary packages built from these source packages, score the version from
# Debian backports higher as to get hardware enabled or better hardware support

Package: src:alsa-ucm-conf:any src:firmware-free:any src:firmware-nonfree:any src:linux:any src:linux-signed-arm64:any src:mesa:any
Pin: release n=trixie-backports
Pin-Priority: 900
EOF

# Update again
# Install the basic mesa dependencies to make our build work
# Install libegl-mesa0 which contains the mesa vendor library for EGL.
RUN DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    apt -y install --no-install-recommends mesa-common-dev libegl-dev libgles-dev                  \
        libgl1-mesa-dri libegl-mesa0 libgles2 mesa-opencl-icd clpeak                               \
        gir1.2-gst-plugins-base-1.0                                                             && \
        apt -y upgrade                                                                          && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Create USER and add to video group for accessing v4ls devices
RUN addgroup qcom                                                                               && \
    useradd -s /bin/bash -m -g qcom qimsdk                                                      && \
    usermod -aG video qimsdk                                                                    && \
    usermod -aG kmem qimsdk                                                                     && \
    echo qimsdk:asd | chpasswd

# Increase max number of fd to be opened by one process
RUN ulimit -n 16192

# Copy installed binaries to device image
COPY --from=qimsdk-build ${QIMSDK_INSTALL_DIR}/usr /usr

# Copy prebuilt binaries to device image
COPY --from=qimsdk-build ${QIMSDK_PREBUILT_DIR}/usr /usr

# Copy deb packages to device image
COPY --from=qimsdk-build /mnt/work/downloads/debs ${QIMSDK_DEB_DIR}

# Install deb packages to deploy image and remove the directory after install
RUN dpkg -i ${QIMSDK_DEB_DIR}/* && rm -rf ${QIMSDK_DEB_DIR}

# Copy prebuilt libraries from AIML to device image

# Dependencies of qtioverlay,
#                 gstqtivoverlay,
#                 gstqtimlvdetection,
#                 gstqtimlaclassification,
#                 gstqtimlvpose,
#                 gstqtimlvclassification
COPY --from=deploy /usr/lib/aarch64-linux-gnu/libexpat.so*               /usr/lib/aarch64-linux-gnu/
COPY --from=deploy /usr/lib/aarch64-linux-gnu/libbrotlidec.so*           /usr/lib/aarch64-linux-gnu/
COPY --from=deploy /usr/lib/aarch64-linux-gnu/libbrotlicommon.so*        /usr/lib/aarch64-linux-gnu/
# Dependency of gstqtivoverlay,
#               gstqtimldemux,
#               gstqtimlvdetection,
#               gstqtimltflite,
#               gstqtivcomposer,
#               gstqtimlvconverter,
#               gstqtimlvsuperresolution,
#               gstqtimetamux,
#               qtioverlay,
#               gstqtimlaconverter,
#               gstqtivtransform,
#               gstqtimlaclassification,
#               qtisocketsink,
#               ml-vdetection-qpd,
#               ml-vpose-posenet,
#               ml-vdetection-yolov8,
#               ml-vdetection-yolov5,
#               ml-vsuperresolution-srnet,
#               ml-vclassification-qfr,
#               ml-aclassification-yamnet,
#               ml-vdetection-east-textdt,
#               ml-vsegmentation-deeplab-argmax,
#               ml-vdetection-qfd,
#               ml-vclassification-mobilenet,
#               ml-vsegmentation-midas-v2,
#               ml-vdetection-ssd-mobilenet,
#               ml-vdetection-yolo-nas,
#               ml-vpose-hrnet,
#               ml-vsegmentation-yolov8,
#               ml-vclassification-ocr,
#               ml-vpose-lite-3dmm,
#               gstqtimlvsegmentation,
#               gstvideo4linux2,
#               qtisocketsrc,
#               meta-transform-roi-label-moving-average,
#               ml-meta-parser-json,
#               gstqtimlvpose,
#               gstqtivsplit,
#               gstqtimlmetaextractor,
#               gstqtimlvclassification
COPY --from=deploy /usr/lib/aarch64-linux-gnu/libdrm.so*                 /usr/lib/aarch64-linux-gnu/

# Change user to qimsdk
USER qimsdk

# Change workdir to user home
WORKDIR /home/qimsdk

# Add glimagesink exports
ENV DISPLAY=:0

# Add gstreamer exports
ENV GST_DEBUG_NO_COLOR=1
ENV GST_DEBUG=2
ENV GST_PLUGIN_SCANNER="/usr/lib/aarch64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner"
ENV XDG_RUNTIME_DIR="/run/user/1000"
