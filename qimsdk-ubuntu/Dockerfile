# QIMSDK Device Image
FROM --platform=arm64 ubuntu:24.04 AS qimsdk_ubun_image

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Installing required apt packages
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y bash-completion git           \
        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-tools                      \
        gstreamer1.0-plugins-base-apps libgstrtspserver-1.0-0 gstreamer1.0-nice libhiredis1.1.0    \
        python3 python3-gst-1.0 libjpeg62 libprotobuf32t64 libdaemon0 mosquitto                    \
        libopencv-imgproc406t64 libopencv-calib3d406t64 libopencv-imgcodecs406t64                  \
        libopencv-highgui406t64                                                                 && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Set up download directory
ENV QIMSDK_DOWNLOAD_DIR=/mnt/work
RUN mkdir -p ${QIMSDK_DOWNLOAD_DIR}
WORKDIR ${QIMSDK_DOWNLOAD_DIR}

ARG QIMSDK_ARG_IMSDK_SRC_BRANCH
ENV QIMSDK_IMSDK_SRC_BRANCH=${QIMSDK_ARG_IMSDK_SRC_BRANCH}
ARG QIMSDK_ARG_SOLUTIONS_BRANCH
ENV QIMSDK_SOLUTIONS_BRANCH=${QIMSDK_ARG_SOLUTIONS_BRANCH}

RUN git clone https://git.codelinaro.org/clo/le/platform/vendor/qcom-opensource/gst-plugins-qti-oss.git \
        -b ${QIMSDK_IMSDK_SRC_BRANCH}                                                           && \
    cd gst-plugins-qti-oss                                                                      && \
    git fetch origin ${QIMSDK_IMSDK_SRC_BRANCH}                                                 && \
    git checkout FETCH_HEAD                                                                     && \
    cp gst-plugin-tools/gst-scripts/demo_setup_wizard.sh /usr/bin

RUN git clone https://git.codelinaro.org/clo/le/solutions-microservices.git                        \
        -b ${QIMSDK_SOLUTIONS_BRANCH}                                                           && \
    cd solutions-microservices                                                                  && \
    git fetch origin ${QIMSDK_SOLUTIONS_BRANCH}                                                 && \
    git checkout FETCH_HEAD                                                                     && \
    cp microservices/qimsdk/pipelines/ppe/qimsdk_ppe.sh /usr/bin                                && \
    cp microservices/qimsdk/pipelines/person-detect/qimsdk_person_detect.sh /usr/bin            && \
    apt remove -y git                                                                           && \
    rm -rf ${QIMSDK_DOWNLOAD_DIR}

# Change user to ubuntu
USER ubuntu

# Change workdir to user home
WORKDIR /home/ubuntu
