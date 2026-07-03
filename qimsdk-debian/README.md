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
      * [Setting up the platform](#Platform_model_file_and_folder_setup)
      * [How to run the qimsdk deploy container](#Run_the_qimsdk_device_deploy_container)
    * [How to use the qimsdk-debian container](#Using_the_container)
    * [Adding custom user configurations to deploy container](#Adding_custom_user_configurations)
* [Important notes](#Important_notes)
    * [Mandatory model data folder naming convention and container mapping](#Model_data_folder_naming_convention_and_container_mapping)
    * [qimsdk-debian deploy container root user limitation](#Root_user_limitation)

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
    12. Fetch QCOM solutions-microservices code needed for qimsdk microservices apps
    13. Copy build and install scripts to build image
    14. Source container helper scripts from bashrc
    15. Copy tflite headers and libs using qimsdk-copy-tf-lite-headers-to-sysroot
    16. Apply patches to open-source projects which need to be patched
    17. Call incremental build function which builds open-source and QCOM GStreamer plugins

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

Building the qimsdk_deploy_arm64 image: minimal set of runtime binaries needed to execute gst use-cases are available in this image.

```bash
docker build \
  --build-arg QIMSDK_ARG_QNP_VERSION=<version, e.g. 2.46.0.260424> \
  --build-arg QIMSDK_ARG_CAMERA_SERVICE_TAG=<camera-service-commit-id> \
  --build-arg QIMSDK_ARG_GST_PLUGINS_TAG=<gstreamer-plugins-commit-id> \
  --target qimsdk_deploy_arm64 \
  -t <desired-image-name> .
```
#### An example with concrete values:
```bash
docker build \
  --build-arg QIMSDK_ARG_QNP_VERSION=2.46.0.260424 \
  --build-arg QIMSDK_ARG_CAMERA_SERVICE_TAG=abc123def456 \
  --build-arg QIMSDK_ARG_GST_PLUGINS_TAG=789xyz456uvw \
  --target qimsdk_deploy_arm64 \
  -t my-qimsdk-image .
```
#### Notes:

- QIMSDK_ARG_QNP_VERSION: Controls the QAIRT SDK version. If omitted, QNN and SNPE plugins will be disabled.
- QIMSDK_ARG_CAMERA_SERVICE_TAG: Should match the exact commit ID or tag of the camera-service repository.
- QIMSDK_ARG_GST_PLUGINS_TAG: Should point to the desired commit ID or tag for the IM SDK (GStreamer plugins) sources.

This ensures all components are pinned to reproducible versions during the image build.

<div id="How_to_add_new_QCOM_GStreamer_plugin">

### How to add a new QCOM GStreamer plugin

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

In order to run the qimsdk container with GStreamer functionalities inside, please make use of the qimsdk arm64 deploy image built earlier and specify the 'host' network mode.

Any required platform resources like GPU, DSP, video device nodes and any other system folders/volumes need to be propagated and explicitly exposed to the Docker container.

This is achieved with the help of:

* uploading a matching target-specfic CDI file;
* uploading a matching target-specific ENV file;
* creating all of the required target folders used for the local model data storage;
* uploading the model-specific data accordingly;
* setting the appropriate target model data file and folder access permissions;
* listing the model-specific platform to container folder/volume mappings in the container run command.

A few of these platform device/folder/volume bindings are specified through CDI files - one for each supported target platform and OS combination.

In view of the basic Docker design principles, a corresponding ENV (environment variable - *.env) file is also needed for exposing the environment variable values of interest inside the device container as well.

> **Note:** CDI files are located in: qimsdk-debian/cdi/\<hardware\>-\<platform\>-qimsdk.json;

The CDI file needed for a specific hardware platform needs to be copied to the /etc/cdi/ directory on the target device storage.

Please create this directory first, if it does not exist as follows:

```bash
sudo mkdir -p /etc/cdi
sudo chmod 755 /etc/cdi
```

> **Note:** the ENV files are located in: qimsdk-debian/env/\<hardware\>-\<platform\>-qimsdk.env;

The ENV file needed for a specific hardware platform needs to be copied to the /etc/docker/env/ directory on the target device storage.

Please create this directory first, if it does not exist as follows:

```bash
sudo mkdir -p /etc/docker/env
sudo chmod 755 /etc/docker/env
```

<div id="Platform_model_file_and_folder_setup">

### Platform model file and folder setup
The following directories must be created under the user’s home directory to store test files:

> **Note:** The `HOME` directory depends on the target platform OS:
> - `/root` on Qualcomm QLI platforms
> - `/home/ubuntu` on Qualcomm Ubuntu platforms

Set the root path for the user content by exporting one of the following environment variables in a platform terminal, depending on your platform and preference:

```bash
# For QLI platforms — content stored under the root home directory
export QIMSDK_USER_CONTENTS_ROOT=/root

# For Ubuntu platforms — content stored under the ubuntu home directory
export QIMSDK_USER_CONTENTS_ROOT=/home/ubuntu

# For any platform — content stored under /etc, independent of the OS type
export QIMSDK_USER_CONTENTS_ROOT=/etc
```

Then create the required directories:

```bash
mkdir -p ${QIMSDK_USER_CONTENTS_ROOT}/media
mkdir -p ${QIMSDK_USER_CONTENTS_ROOT}/models
mkdir -p ${QIMSDK_USER_CONTENTS_ROOT}/labels
mkdir -p ${QIMSDK_USER_CONTENTS_ROOT}/configs
```

Apply the correct permissions to each directory and its contents.
> **Note:** Use `sudo` when the `QIMSDK_USER_CONTENTS_ROOT` value is set to `/etc` for any non-root platform user:

```bash
# media
find ${QIMSDK_USER_CONTENTS_ROOT}/media/ -type d -exec chmod 755 {} \;
find ${QIMSDK_USER_CONTENTS_ROOT}/media/ -type f -exec chmod 644 {} \;

# models
find ${QIMSDK_USER_CONTENTS_ROOT}/models/ -type d -exec chmod 755 {} \;
find ${QIMSDK_USER_CONTENTS_ROOT}/models/ -type f -exec chmod 644 {} \;

# labels
find ${QIMSDK_USER_CONTENTS_ROOT}/labels/ -type d -exec chmod 755 {} \;
find ${QIMSDK_USER_CONTENTS_ROOT}/labels/ -type f -exec chmod 644 {} \;

# configs
find ${QIMSDK_USER_CONTENTS_ROOT}/configs/ -type d -exec chmod 755 {} \;
find ${QIMSDK_USER_CONTENTS_ROOT}/configs/ -type f -exec chmod 644 {} \;
```

**Before running the arm64 deploy container, please upload your models and model-specific data into these newly created platform model data folders.**

#### Talos (QCS615) Video node configuration
An additional step is required for Talos (qcs615) to configure the video node, as it uses an upstream video driver. This upstream driver can assign any device node between /dev/video0 and /dev/video28.

***Run the following command to list the video devices:***

```bash
v4l2-ctl --list-devices
```
***Example:***

```bash
Qualcomm Venus video decoder (plat:aa00000.video-codec:dec):
    /dev/video2

Qualcomm Venus video encoder (plat:aa00000.video-codec:enc):
    /dev/video3
```

Identify the relevant device nodes and add them to the cdi.json file that has been deployed to the target system.

```json
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

<div id="Run_the_qimsdk_device_deploy_container">

### How to run the qimsdk device deploy container

> **Note:** If your platform and OS combo do not support adb connectivity, please use the onboard Ethernet/WLAN network to access the device over ssh and adapt the execution of the commands listed below accordingly.

First, set the `QIMSDK_USER_CONTENTS_ROOT` environment variable to match where your media, models, labels and configs are stored on the target device (if not done already):

```bash
# For QLI platforms — content stored under the root home directory
export QIMSDK_USER_CONTENTS_ROOT=/root

# For Ubuntu platforms — content stored under the ubuntu home directory
export QIMSDK_USER_CONTENTS_ROOT=/home/ubuntu

# For any platform — content stored under /etc, independent of the OS type
export QIMSDK_USER_CONTENTS_ROOT=/etc
```

Then push the CDI and ENV files and run the container.

```bash
adb push qimsdk-debian/cdi/<hardware>-<platform>-qimsdk.json /etc/cdi/qimsdk.json
adb push qimsdk-debian/env/<hardware>-<platform>-qimsdk.env /etc/docker/env/qimsdk.env
```

>**Note:** When the `QIMSDK_USER_CONTENTS_ROOT` environment variable value is `/root` or `/home/ubuntu`** (the model content shall be mounted into the `/home/qimsdk/` folder inside the container):

Push the deploy Docker image to the device and load it

```bash
export QIMSDK_DEVICE_TEST_PATH="<target_device_path>"
export QIMSDK_DOCKER_IMAGE="<path_to_docker_image_file>"
adb shell mkdir -p "${QIMSDK_DEVICE_TEST_PATH}"
adb push "${QIMSDK_DOCKER_IMAGE}" "${QIMSDK_DEVICE_TEST_PATH}/${QIMSDK_DOCKER_IMAGE}"
adb shell docker load -i "${QIMSDK_DEVICE_TEST_PATH}/${QIMSDK_DOCKER_IMAGE}"
```

Now run the deploy Docker container

```bash
adb shell docker run -it -d --net host \
  --env-file /etc/docker/env/qimsdk.env \
  --device qualcomm.com/device=qimsdk \
  -v ${QIMSDK_USER_CONTENTS_ROOT}/media:/home/qimsdk/media \
  -v ${QIMSDK_USER_CONTENTS_ROOT}/models:/home/qimsdk/models \
  -v ${QIMSDK_USER_CONTENTS_ROOT}/labels:/home/qimsdk/labels \
  -v ${QIMSDK_USER_CONTENTS_ROOT}/configs:/home/qimsdk/configs \
  -h qimsdk --name qimsdk <desired-image-name>
```

> **Note:** When the `QIMSDK_USER_CONTENTS_ROOT` environment variable value is `/etc`** (the model content shall be mounted into the `/etc/` folder inside the container):

```bash
adb shell docker run -it -d --net host \
  --env-file /etc/docker/env/qimsdk.env \
  --device qualcomm.com/device=qimsdk \
  -v ${QIMSDK_USER_CONTENTS_ROOT}/media:/etc/media \
  -v ${QIMSDK_USER_CONTENTS_ROOT}/models:/etc/models \
  -v ${QIMSDK_USER_CONTENTS_ROOT}/labels:/etc/labels \
  -v ${QIMSDK_USER_CONTENTS_ROOT}/configs:/etc/configs \
  -h qimsdk --name qimsdk <desired-image-name>
```

<div id="Using_the_container">

### How to use the qimsdk-debian container

To execute a bash shell in container, run the following command:

```bash
docker exec -it qimsdk bash
```

<div id="Adding_custom_user_configurations">

### Adding custom user configurations to the deploy container

If qimsdk-debian deploy container user wants to use extra devices or volumes, those can be added to the CDI file.

One such example is when a USB Camera is attached to the target device, and the user would like to use it from inside the deploy container:

***These steps need to be run inside a device terminal:***

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

<div id="Important_notes">

## Important notes

<div id="Model_data_folder_naming_convention_and_container_mapping">

### Mandatory model data folder naming convention and container mapping

* The platform model folder naming and layout must follow the structure defined in the [#Setting up the platform](#Platform_model_file_and_folder_setup) section!

> **Important Notice:** Any deviation from this exact folder layout and folder naming convention might result in your models failing to be correctly identified, located, loaded and utilized due to a potential violation of any target device SELinux policy restrictions in place!

<div id="Root_user_limitation">

### qimsdk-debian deploy container root user limitation

* The qimsdk-debian device Docker container image is meant to be run only with the **qimsdk** user ID.
* The qimsdk-debian device Docker container **qimsdk** user is not part of the **sudo group** by design, hence lacking permissions to install any new packages, or make any root file system modifications for security concerns.
* In order to temporarily allow for the qimsdk-debian device Docker container to run with **root** user ID and root permissions, please refer to the following steps below:
    * edit the **qimsdk-debian/.bash_aliases** file with commenting out the following text lines as follows:
      ```bash
      # [ "$(id -u)" = "0" ] && exec gosu qimsdk bash
      ```
    * save and rebuild the Docker image as usual, e.g.:
      ```bash
      docker build \
      --build-arg QIMSDK_ARG_QNP_VERSION=<version, e.g. 2.46.0.260424> \
      --build-arg QIMSDK_ARG_CAMERA_SERVICE_TAG=<camera-service-commit-id> \
      --build-arg QIMSDK_ARG_GST_PLUGINS_TAG=<gstreamer-plugins-commit-id> \
      --target qimsdk_deploy_arm64 \
      -t <desired-image-name> .
      ```
    * finally, run the container as root:
      ```bash
      docker run -it -d --net host --env-file /etc/docker/env/qimsdk.env --device qualcomm.com/device=qimsdk -h qimsdk --user root --name qimsdk <desired-image-name>
      ```
    * validate you are logged in as root inside the container, e.g.:
      ```bash
      export DOCKER_ID=$(docker ps -aq)
      docker exec -it ${DOCKER_ID} bash
      whoami
      ```
    * to restore the original qimsdk non-root user enforced state, please edit the /root/.bash_aliases file within the existing container and uncomment the edits made. This would allow users to retain any locally made container modifications instead of rebuilding a new container and losing their state.
    * please keep in mind that once the original qimsdk user configuration has been restored, users cannot go back to the root user state without removing the existing container instance and recreating a new one, as already outlined.
