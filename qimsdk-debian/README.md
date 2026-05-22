# About The QIMSDK-Debian Docker Image

## Table of Contents

* [QIMSDK Docker Images](#Docker_images)
    * [qimsdk_build](#qimsdk_build)
    * [qimsdk_deploy_arm64](#qimsdk_deploy)
* [Scripts](#Scripts)
    * [build.sh](#build.sh)
    * [env_setup.sh](#env_setup.sh)
    * [setup.sh](#setup.sh)
* [Workflow](#Workflow)
    * [How to build](#How_to_build)
    * [How to add new QCOM GStreamer plugin](#How_to_add_new_QCOM_GStreamer_plugin)
    * [Running the qimsdk deploy container](#Running_the_container)
    * [How to use the qimsdk-debian container](#Using_the_container)
    * [Adding custom user configurations to deploy container](#Adding_custom_user_configurations)

<div id="Docker_images">

## QIMSDK Docker Images

Two QIMSDK Docker images are provided:

- Build Image (qimsdk_build):
  - Based on Debian Trixie
  - Matches the host architecture
  - Handles GStreamer multimedia framework compilation

- Deploy Image (qimsdk_deploy_arm64):
  - Based on Debian Trixie
  - Specifically for ARM64 architecture
  - Contains only the necessary runtime components for target devices
This separation allows for efficient development on the host system while ensuring proper deployment to ARM64-based target devices.

<div id="qimsdk_build">

### qimsdk_build (based on host architecture)

    1. Start from Debian Trixie
    2. Add deb-src for everything
    3. Install build time dependencies, needed for gst-plugins-imsdk compilation
    4. Create deploy and prebuilt directories to install binaries to be propagated to deploy image
    5. Create qimsdk build directory and logs directory
    6. Set up download directory and download open-source projects which need to be patched
    7. Setup Tensorflow Lite 2.20
    8. Fetch meta layers with patches needed
    9. Fetch and install QNP release
    10. Fetch open-source camera-service repo needed to enable camera functionality
    11. Fetch QCOM gst source code from github
    12. Copy build and install scripts to build image
    13. Source container helper scripts from bashrc
    14. Copy tflite headers and libs using qimsdk-copy-tf-lite-headers-to-sysroot
    15. Apply patches to open-source projects which need to be patched
    16. Call incremental build function which builds open-source and QCOM GStreamer plugins

<div id="qimsdk_deploy">

### qimsdk_deploy_arm64 (based on arm64 architecture)

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
- qimsdk-cmake-build-camera-service - Build and install open-source project needed in order to enable camera functionality.
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

Building qimsdk_deploy_arm64: minimal set of runtime binaries needed to execute gst use-cases are available in this image.

```bash
docker build --build-arg QIMSDK_ARG_QNP_VERSION=<version, e.g. 2.39.0.250925> --target qimsdk_deploy_arm64 -t <desired-image-name> .
```
In the docker build command above, provide the version of QAIRT SDK that you want to install, e.g. *--build-arg QIMSDK_ARG_QNP_VERSION=2.39.0.250925*. If this argument is not provided, the QNN and SNPE plugins will be disabled in the image.

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

In order to run the qimsdk container with GStreamer functionalities inside, it must be run from the qimsdk_deploy_arm64 image built earlier, container needs to be ran with 'host' network mode. GPU devices, video devices, and other needed user volumes need to be mounted. CDI json for the specific platform contains all of these needed platform mountings. Because of the basic design principles of Docker, an .env file is needed for the environment variables inside device container as well.

CDI files are located in: qimsdk-debian/cdi/\<hardware\>-\<platform\>-qimsdk.json;
The CDI file needed for the specific hardware platform needs to be copied to /etc/cdi/ directory in device storage. (Create directory if it does not exist)

.env files are located in: qimsdk-debian/env/\<hardware\>-\<platform\>-qimsdk.env;
The .env file needed for the specific hardware platform needs to be copied to /etc/docker/env/ directory in device storage. (Create directory if it does not exist)

Command to run the qimsdk device deploy container:

```bash
adb push qimsdk-debian/cdi/<hardware>-<platform>-qimsdk.json /etc/cdi/qimsdk.json
adb push qimsdk-debian/env/<hardware>-<platform>-qimsdk.env /etc/docker/env/qimsdk.env
docker run -it -d --net host --env-file /etc/docker/env/qimsdk.env --device qualcomm.com/device=qimsdk -h qimsdk --name qimsdk <desired-image-name>
```

<div id="Using_the_container">

### How to use the qimsdk-debian container

To execute a bash shell in container, run the following command:

```bash
docker exec -ti qimsdk bash
```

<div id="Adding_custom_user_configurations">

### Adding custom user configurations to deploy container

If qimsdk-debian deploy container user wants to use extra devices or volumes, those can be added to the CDI file.
One such example is when USB Camera is attached to device, and user would like to use it from inside deploy container:

***These steps need to be run inside device shell***

```bash
# After attaching USB Camera, v4l devices /dev/video2 and /dev/video3 appear on platform
$ ls -lah /dev/video*
crw-rw---- 1 root video 81, 2 Sep 17 14:22 /dev/video0
crw-rw---- 1 root video 81, 3 Sep 17 14:22 /dev/video1
crw-rw---- 1 root video 81, 2 Sep 17 14:22 /dev/video2
crw-rw---- 1 root video 81, 3 Sep 17 14:22 /dev/video3
crw-rw---- 1 root video 81, 2 Sep 17 14:22 /dev/video32
crw-rw---- 1 root video 81, 3 Sep 17 14:22 /dev/video33

# Which exactly are the new v4l device nodes to appear can be easily verified by unplugging the USB
#    Camera and running the command once again. Here we can see that they are /dev/video2 and /dev/video3:
$ ls -lah /dev/video*
crw-rw---- 1 root video 81, 2 Sep 17 14:22 /dev/video0
crw-rw---- 1 root video 81, 3 Sep 17 14:22 /dev/video1
crw-rw---- 1 root video 81, 2 Sep 17 14:22 /dev/video32
crw-rw---- 1 root video 81, 3 Sep 17 14:22 /dev/video33

# Add following lines to the /etc/cdi/qimsdk.json file in the deviceNodes section using an editor of choice:
vi /etc/cdi/qimsdk.json
```

```json
{
    "deviceNodes": [
    ...
          },
          {
            "path": "/dev/video2",
            "uid": 0,
            "gid": 44
          },
          {
            "path": "/dev/video3",
            "uid": 0,
            "gid": 44
          },
          {
    ...
```

```bash
# After that's done, the container needs to be removed and a new one needs to be run, if already running
docker rm -f qimsdk
docker run -it -d --net host --env-file /etc/docker/env/qimsdk.env --device qualcomm.com/device=qimsdk -h qimsdk --name qimsdk <desired-image-name>
```
