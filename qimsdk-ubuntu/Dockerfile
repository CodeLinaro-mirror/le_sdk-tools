# QIMSDK Development Image
FROM --platform=arm64 ubuntu:24.04 AS qimsdk_ubun_image

# Enable color prompt
RUN sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc

# Installing required apt packages
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y bash-completion               \
        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-tools                      \
        gstreamer1.0-plugins-base-apps libgstrtspserver-1.0-0 gstreamer1.0-nice libhiredis1.1.0    \
        python3 python3-gst-1.0 libjpeg62 libprotobuf32t64 libdaemon0 mosquitto                    \
        libopencv-imgproc406t64 libopencv-calib3d406t64 libopencv-imgcodecs406t64                  \
        libopencv-highgui406t64                                                                 && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*

# Change user to ubuntu
USER ubuntu

# Change workdir to user home
WORKDIR /home/ubuntu
