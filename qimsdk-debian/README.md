# About The QIMSDK-Debian Docker Image

## Table of Contents

* [QIMSDK Docker Images](#Docker_images)
    * [qimsdk-build](#qimsdk_build)
    * [qimsdk-deploy](#qimsdk_deploy)
* [Scripts](#Scripts)
    * [build.sh](#build.sh)
    * [env_setup.sh](#env_setup.sh)
    * [setup.sh](#setup.sh)
* [Workflow](#Workflow)
    * [How to build](#How_to_build)
    * [How to add new QCOM GStreamer plugin](#How_to_add_new_QCOM_GStreamer_plugin)
    * [Running the qimsdk deploy container](#Running_the_container)
    * [How to use the qimsdk-debian container](#Using_the_container)

<div id="Docker_images">

## QIMSDK Docker Images

Two QIMSDK docker images are built. One for target GStreamer multimedia framework binary compilation. One for device target GStreamer runtime use.
- Build image (qimsdk-build) is based on an debian trixie image, provided by platform team.
- Deploy image (qimsdk-deploy) is based on a bare debian:trixie OS docker image.

<div id="qimsdk_build">

### qimsdk-build

    1. Start from Debian Trixie
    2. Add deb-src for everything
    3. Install build time dependencies, needed for gst-plugins-imsdk compilation
    4. Create deploy and prebuilt directories to install binaries to be propagated to deploy image
    5. Create qimsdk build directory and logs directory
    6. Set up download directory and download open-source projects which need to be patched
    7. Setup Tensorflow Lite 2.20
    8. Fetch meta layers with patches needed
    9. Fetch and install QNP release
    10. Fetch QCOM gst source code from github
    11. Copy build and install scripts to build image
    12. Source container helper scripts from bashrc
    14. Copy tflite headers and libs using qimsdk-copy-tf-lite-headers-to-sysroot
    15. Apply patches to open-source projects which need to be patched
    16. Call incremental build function which builds open-source and QCOM GStreamer plugins

<div id="qimsdk_deploy">

### qimsdk-deploy

    1. Start from base debian:trixie image
    2. Install runtime dependency Open Source packages to deploy image
    3. Add QCOM PPA and install QCOM dependencies
    4. Add qimsdk user
    5. Copy built binaries from QIMSDK Build Image
    6. Copy deb packages to device image
    7. Install deb packages to deploy image and remove the directory after install
    8. Add environment variables

<div id="Scripts">

## Scripts

The functions inside these scripts are generally for building and maintaining the docker images.

<div id="build.sh">

### build.sh

Handles the compilation and installation of open-source and QCOM GStreamer plugins.

- qimsdk-cmake-configure - Configures a CMake project with security-hardened flags and custom build options
- qimsdk-cmake-compile - Compiles a configured CMake target with logging
- qimsdk-cmake-install - Installs CMake build artifacts to debug and deployment directories
- qimsdk-debian-rules-build - Wrapper function that calls configure, compile and install for projects, which need to be built using debian/rules
- qimsdk-cmake-build - Wrapper function that calls configure, compile and install for CMake projects
- qimsdk-debian-rules-build-\<name-of-project\> - Builds specific open-source component with custom configuration
- qimsdk-debian-rules-clean-\<name-of-project\> - Cleans build directory for specific open-source component
- qimsdk-cmake-build-gst-plugins-imsdk - Base QCOM GStreamer plugins that the others depend on are built. After which, a hardcoded list of QCOM GStreamer plugins is built in parallel. If one wishes to add a new GStreamer plugin to build using CMake, simply add the plugin directory name under gst-plugins-imsdk/ source dir to the list.
- qimsdk-incremental-build - Main entry point that builds all GStreamer components in sequence with success reporting. Also calls qimsdk-cmake-build-gst-plugins-imsdk, to build QCOM GStreamer plugins.

<div id="env_setup.sh">

### env_setup.sh

env_setup.sh is a script which sources all other scripts inside scripts dir inside build image environment.

<div id="setup.sh">

### setup.sh

Handles patching, library propagation, and dependency management for GStreamer plugins and TensorFlow Lite components.

- qimsdk-apply-patch - A wrapper for git am command that applies patch files
- qimsdk-apply-patches - Master wrapper that calls functions to apply patches to all required open-source projects
- qimsdk-apply-patches-\<open-source-project\> - Applies patches specifically to targeted open source package
- qimsdk-copy-tf-lite-headers-to-sysroot - Copies all necessary headers to the sysroot while maintaining proper directory structure

<div id="Workflow">

## Workflow

<div id="How_to_build">

### How to build

Building qimsdk-deploy: minimal set of runtime binaries needed to execute gst use-cases are available in this image.

```bash
docker build  --platform linux/arm64 --target qimsdk-deploy -t <desired-image-name> .
```

<div id="How_to_add_new_QCOM_GStreamer_plugin">

### How to add new QCOM GStreamer plugin

***NOTE: Adding a new QCOM GStreamer plugin to the qimsdk-cmake-build-gst-plugins-imsdk function***

1. Add source code and top-level CMakeLists.txt file in Project Directory.
  - Project Directory Name should be same as project name.
  - It is recommended to add projects as subdirectiories of /mnt/work/src/gst-plugins-imsdk
  - Example: /mnt/work/src/gst-plugins-imsdk/\<Project-Directory-Name\>

2. Add in top level CMakeLists.txt file option (with default value OFF) to add as subdirectory \<Project-Directory-Name\>

3. For new project to be compiled automatically during `qimsdk-incremental-build`, newly created option from last step needs to be added to "qimsdk-cmake-build-gst-plugins-imsdk" with value ON in /mnt/work/scripts/build.sh

```bash
# Incremental build all gst-plugins-imsdk
function qimsdk-cmake-build-gst-plugins-imsdk() {
...
...
...
        `-DENABLE_GST_PLUGIN_<plugin name>=ON `
...
...
...
        print-green "${FUNCNAME} completed successfully!"
}
```

<div id="Running_the_container">

### Running the qimsdk deploy container

In order to run the qimsdk container with GStreamer functionalities inside, it must be run from the qimsdk-deploy image built earlier, container needs to be ran with 'host' network mode. GPU devices, video devices, and other needed user volumes need to be mounted as such:

```bash
docker run -it -d --net host --device /dev/video0 --device /dev/video1 --device /dev/video2 --device /dev/video3 --device /dev/dri/card0 --device /dev/dri/renderD128 --device /dev/dma_heap -v /run/user/1000:/run/user/1000 -v /etc/OpenCL/vendors:/etc/OpenCL/vendors -v /etc/labels:/etc/labels -v /etc/media:/etc/media -v /etc/models:/etc/models -h qimsdk --name qimsdk <desired-image-name>
```

<div id="Using_the_container">

### How to use the qimsdk-debian container

To execute a bash shell in container, run the following command:

```bash
docker exec -ti qimsdk bash
```
