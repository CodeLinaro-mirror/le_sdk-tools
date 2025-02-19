# QIM SDK

## Table of Contents

* [Prerequisites](#Prerequisites)
  * [Ubuntu Version](#Ubuntu_Version)
  * [Ubuntu Packages](#Ubuntu_Packages)
  * [How to increase Max user watches and max user instances on host system](#Max_user_watches)
  * [Add internal docker registry mirror. (optional)](#Add_internal_docker_registry_mirror)
  * [Proxy. (optional)](#Proxy)
  * [Docker Must Be Configured On The Host System (one time)](#Docker_Host_System)
* [Docker Images](#Docker_Images)
  * [QIMSDK Dev Image](#QIMSDK_Dev_Image)
  * [QIMSDK Device Image](#QIMSDK_Device_Image)
* [Host Side Helper Scripts And Configuration](#Host_Side_Helper_Scripts_And_Configuration)
  * [How to fill out Configuration JSON Files](#How_to_fill_out_Configuration_JSON_Files)
  * [Docker Host Side Helper Scripts](#Docker_Host_Side_Helper_Scripts)
  * [Docker Development Container Side Helper Scripts](#Docker_Development_Container_Side_Helper_Scripts)
* [Development Workflow](#Development_Workflow)
  * [Initial One Time Setup](#Initial_One_Time_Setup)
  * [Continuous Development After Initial Setup](#Continuous_Development_After_Initial_Setup)
* [Docker Container In CDI Mode](#Docker_Container_In_CDI_Mode)
  * [Prerequisites For CDI](#Prerequisites_For_CDI)
  * [Running The Container In CDI Mode](#Running_The_Container_In_CDI_Mode)
* [Examples For Development](#Examples_For_Development)
  * [Remote Device With Disabled Verity](#Remote_Device_With_Disabled_Verity)
  * [Local Device With Verity Check](#Local_Device_With_Verity_Check)
  * [Device Docker Clean Up](#Device_Docker_Clean_Up)
  * [Development when device is not connected to host build machine](#Development_when_device_is_not_connected_to_host_build_machine)
  * [Contributing to the GStreamer Project](#Contributing_to_the_GStreamer_Project)
  * [Starting the container with docker-compose](#Starting_the_container_with_docker_compose)
  * [Starting the wayland](#Starting_the_wayland)
* [Manual Commands Instead Of Scripts](#Manual_Commands_Instead_Of_Scripts)
* [Docker Container Renaming](#Docker_Container_Renaming)
  * [Rename device's Docker container from host development container](#Rename_device's_Docker_container_from_host_development_container)
  * [Rename Docker Device Container](#Rename_Docker_Device_Container)

<div id="Prerequisites">

## Prerequisites

<div id="Ubuntu_Version">

### Ubuntu Version

Ubuntu 18.04 or Ubuntu 20.04 or Ubuntu 22.04 is required for host file system

<div id="Ubuntu_Packages">

### Ubuntu Packages

Prerequisite packages must be installed on the host (one time)

```bash
sudo apt install -y jq tofrodos qemu-user-static qemu-system-arm
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq
wget http://archive.ubuntu.com/ubuntu/pool/universe/q/qemu/qemu-user-static_6.2+dfsg-2ubuntu6_amd64.deb
sudo dpkg -i qemu-user-static_6.2+dfsg-2ubuntu6_amd64.deb
rm qemu-user-static_6.2+dfsg-2ubuntu6_amd64.deb
```

<h3 style="color:red">
  <b>Do NOT install yq via snap</b>
</h3>

If this happened then remove it:

```bash
sudo snap remove yq
```

And then stop the snapd service
```bash
sudo systemctl stop snapd
```

Goto [Ubuntu Packages](#Ubuntu_Packages) and try to install yq with the instructions mentioned in Ubuntu Packages


<div id="Max_user_watches">

### Max user watches and max user instances must be increased on the host system

**Add these two lines to */etc/sysctl.conf* and reboot the PC**

```bash
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=542288
```

<div id="Docker_Host_System">

### Docker Must Be Configured On The Host System (one time)

#### Cleanup Old Versions

```bash
sudo apt remove docker-desktop
rm -r $HOME/.docker/desktop
sudo rm /usr/local/bin/com.docker.cli
sudo apt purge docker-desktop
```

#### Setup Docker Remote Repository

```bash
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### Install Docker Engine

```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli
```

#### Add User to Docker Group

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

<div id="Add_internal_docker_registry_mirror">

### Add internal docker registry mirror. (optional)

#### Note: Using a tab instead of space and other invisible whitespace characters may break the proper work of json configuration files and later may lead to 'docker.service failed to start' error.

1. Add corresponding *docker-registry-mirror-url* value in the tag "registry-mirrors" in: /etc/docker/daemon.json

```json
{
        "registry-mirrors": [<docker-registry-mirror-url>]
}
```

2. Restart the docker service to take the new settings.

```bash
sudo fromdos /etc/docker/daemon.json
sudo systemctl restart docker
```

***Please note that until PC reboot, *newgrp docker* should be invoked on every new console open***

<div id="Proxy">

### Proxy. (optional)

#### Note: Using a tab instead of space and other invisible whitespace characters may break the proper work of json configuration files and later may lead to 'docker.service failed to start' error.

1. Add corresponding *http-proxy-url*, *https-proxy-url* and *no-proxy-url* values in the tag "http-proxy", *https-proxy* and *no-proxy* in: /etc/docker/daemon.json

```json
{
        "proxies": {
                "http-proxy": <http-proxy-url>,
                "https-proxy": <https-proxy-url>,
                "no-proxy": <no-proxy-url>
        }
}
```

2. Restart the docker service to take the new settings.

```bash
sudo fromdos -f /etc/docker/daemon.json
sudo systemctl restart docker
```

3. Set proxy related environment variables in bash, before invoking docker build commands

```bash
export http_proxy=<http-proxy-url>
export https_proxy=<https-proxy-url>
export no_proxy=<no-proxy-url>
```

***Please note that until PC reboot, *newgrp docker* should be invoked on every new console open***

#### To test if Docker setup was successful

```bash
docker run arm64v8/hello-world
```

#### In case run arm64v8/hello-world fails: Steps to install arm64 qemu Docker driver

If above hello world command not successfull, please try these steps:

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx rm builder
docker buildx create --name builder --driver docker-container --use
docker buildx inspect --bootstrap
```

#### How to change Docker image installation directory?

If trying to run build image script results in ```No space left on device```, this can be fixed by moving docker directory to ```/local/mnt```

***Here are the necessary steps:***

```bash
# Stop docker
service docker stop
# Verify no docker process is running
ps faux
# Check docker directory structure
sudo ls /var/lib/docker/
# Backup current docker dir
tar -zcC /var/lib docker > /mnt/pd0/var_lib_docker-backup-$(date +%s).tar.gz
# Move the docker dir to a new partition
mv /var/lib/docker /local/mnt/docker
# Make a symlink to the docker dir in the new partition
ln -s /local/mnt/docker /var/lib/docker
# Make sure docker directory structure has remained unchanged
sudo ls /var/lib/docker/
# Start docker
service docker start
```

***Restart all containers after moving docker directory***

<div id="Docker_Images">

## Docker Images

Two QIMSDK docker images are built. One for development. One for device target.

<div id="QIMSDK_Dev_Image">

### QIMSDK Dev Image
1. Start from specified base image
2. Install required open source packages to dev image
3. Copy helper build and install scripts to dev image
4. Copy private headers and patches needed
5. Set up download dir for Open Source gst plugins
6. Apply necessary changes to Open Source plugins
7. Get gst source code from provided path in config json
8. Call wrapper function to build and install plugins

<div id="QIMSDK_Device_Image">

### QIMSDK Device Image
1. Install runtime dependency Open Source packages to device image
2. Copy built binaries from development Image
3. Add qimsdk user

<div id="Host_Side_Helper_Scripts_And_Configuration">

## Host Side Helper Scripts And Configuration

<div id="How_to_fill_out_Configuration_JSON_Files">

### How to fill out Configuration JSON Files

Two configuration json files are used in QIMSDK project:
 - One is generic config json *(config.json)*. Used to configure environment compilation.
 - The others are target specific json *(mappings_\<target-name\>.json)*. Used to configure containers to be run for that specific target.

Config json files *(config.json)* must contain the following data:
 1. ***OPTIONAL*** - **Additional_tag_container** - Additional tag for container - allows for personalization of the names of the docker containers according to their purpose (to not set an additional tag just leave the value for this field empty)
 2. ***OPTIONAL*** - **Additional_tag_image** - Additional tag for docker image - allows for personalization of the names of the docker images according to their purpose (to not set an additional tag just leave the value for this field empty)
 3. ***OPTIONAL*** - **Docker_image_path** - Remote ssh destination or local path to sync docker images or artifacts
 4. ***MANDATORY*** -  **Target_device_ID** - adb devices command ID of the device.
 5. ***MANDATORY;*** -  **Supported_targets** - Supported platforms
 6. ***MANDATORY*** - **IM_SDK_Source_Dir** - PATH to IM SDK sources directory, which contains all gst plugins. ***Note: Path provided must point to gst-plugins-qti-oss directory!***
 7. ***MANDATORY*** - **IM_SDK_Meta_Dir** - PATH to meta IM SDK directory, which contains recipes for all gst plugins. ***Note: Path provided must point to meta-qti-gst directory!***
 8. ***MANDATORY*** - **Solution_Microservices_Dir** - PATH to solutions-microservices directory, which contains all qimsdk microservices shell scripts. ***Note: Path provided must point to solutions-microservices directory!***
 9. ***MANDATORY*** - **LE_Services_Source_Dir** - PATH to le-services directory, which contains source code of camera recorder client and camera metadata libs compiled inside dev container. ***Note: Path provided must point to le-services directory!***
 10. ***MANDATORY*** - **Path_to_eSDK_dir** - Path to extended SDK directory ***Note: Should be unarchived***
 11. ***OPTIONAL*** - **MAP_sources_to_dev_container** - If IM_SDK_Source_Dir, LE_Services_Source_Dir or Solution_Microservices_Dir is wanted to be mapped to the development container, then this attribute should be filled as "TRUE" or "ENABLE" or "ENABLED" ***Note: Default is FALSE***

Target specific json files *(mappings_\<target-name\>.json)* must contain the following data:
 1. ***OPTIONAL*** - **Exports** - set of variables, which will be exported in docker container in platform
 2. ***OPTIONAL*** - **Platform_Libraries_To_Mount** - Platform libraries to mount to device docker container.
 3. ***OPTIONAL*** - **Platform_Specific_Mappings** - Platform specific mappings to be mounted during device docker run container function.

<div id="Docker_Host_Side_Helper_Scripts">

### Docker Host Side Helper Scripts

These functions are for building and maintaining docker images and containers.

***In order for the functions inside docker_env_setup.sh to work on the host, the script must be sourced***

```bash
source scripts/docker_env_setup.sh
```

The developer generally needs to build the image, load the image to the device and run the container.

- qimsdk-device-prepare - Prepare device after reboot
- qimsdk-docker-build-image            \<path-to-config-json> - Build docker image based on Dockerfile
- qimsdk-docker-device-update-image    \<path-to-config-json> - Update selected device image to the device
- qimsdk-docker-device-save-image      \<path-to-config-json> - Save selected device image and run command
- qimsdk-docker-device-load-image      \<path-to-config-json> - Loads device image on the device
- qimsdk-docker-device-run-container   \<path-to-config-json> - Run device container
- qimsdk-docker-device-run-cdi-container \<path-to-config-json> - Run device container in CDI mode
- qimsdk-docker-device-rm-container    \<path-to-config-json> - Remove device container
- qimsdk-docker-device-start-container \<path-to-config-json> - Start device container
- qimsdk-docker-device-stop-container  \<path-to-config-json> - Stop device container
- qimsdk-docker-device-command  \<path-to-config-json> \<CMD> - Execute CMD in device container
- qimsdk-docker-device-shell           \<path-to-config-json> - Start shell in the docker container on the device
- qimsdk-docker-device-images-cleanup  \<path-to-config-json> - Docker device images clean up
- qimsdk-docker-host-images-cleanup                           - Docker host images clean up

<div id="Docker_Development_Container_Side_Helper_Scripts">

### Docker Development Container Side Helper Scripts

These functions are for building and maintaining development docker images and containers.

***In order to build and run development container, the script must be sourced***

```bash
source scripts/docker_env_setup.sh
```

 - qimsdk-dev-docker-build-image       \<path-to-config-json> - Build development image
 - qimsdk-dev-docker-run-container     \<path-to-config-json> - Run development container
 - qimsdk-dev-load-artifacts           \<path-to-config-json> - Load artifacts from specified Docker_image_path in configuration json file and install them to the device. They are installed in a shared directory between device and device container
 - qimsdk-dev-load-artifacts-dbg       \<path-to-config-json> - Load debug artifacts from specified Docker_image_path in configuration json file and install them to the device. They are installed in a shared directory between device and device container

These functions are available immediately inside development container:

 - qimsdk-incremental-build - Incremental build of gst plugins
 - qimsdk-dev-save-artifacts - Save release variant artifacts to specified Docker_image_path in configuration json file. They can then be loaded using the load functions in the environment.
 - qimsdk-dev-save-artifacts-dbg - Save debug variant artifacts to specified Docker_image_path in configuration json file. They can then be loaded using the load functions in the environment.
 - qimsdk-dev-push-artifacts - Push release variant artifacts to device with specified id in configuration json file
 - qimsdk-dev-push-artifacts-dbg - Push debug variant artifacts  to device with specified id in configuration json file

<div id="Development_Workflow">

## Development Workflow

<div id="Initial_One_Time_Setup">

### Initial One Time Setup

# Steps for eSDK Installation

## eSDK

### Prerequisites:

python3 locales diffstat gawk cpio gcc g++ libxml-simple-perl must be installed on the host (once)

```bash
sudo apt install -y python3 locales diffstat gawk cpio gcc g++ libxml-simple-perl
```

#### eSDK Instalation example:

```bash
cd <path/to/eSDK/shell/file>
chmod a+r <sample-qcom-ARM-toolchain-ext.sh>
umask 022
./sample-qcom-ARM-toolchain-ext.sh -y -d <some/destination/directory>
```

#### JSON should be filled:
```bash
{
  ...
  "Path_to_eSDK_dir" : "<some/destination/directory>",
  ...
}
```

#### Prepare Device Connected To Local PC After Image Or Metabuild Flash

***Please note that this step MUST be invoked only once after device, connected to local PC, is flashed with new images or metabuild***

***Please note that adb is single instance. All adb servers in other containers or host OS MUST be killed***

```bash
qimsdk-device-prepare
adb disable-verity
adb reboot
```

#### Prepare Device After Reboot

***Please note that this step needs to be invoked only once after device, connected to local PC, is started***

```bash
qimsdk-device-prepare
```

<div id="Continuous_Development_After_Initial_Setup">

### Continuous Development After Initial Setup

#### Compiling Device Docker Image

```bash
qimsdk-docker-build-image <path-to-config-json>
```

#### Update Compiled Image To The Locally Connected Device

```bash
qimsdk-docker-device-update-image <path-to-config-json>
```

#### Save Compiled Docker Image and Run Command To Remote Docker_image_path

```bash
qimsdk-docker-device-save-image <path-to-config-json>
```

#### Load Saved Docker Image From Remote Docker_image_path To Locally Connected Device

```bash
qimsdk-docker-device-load-image <path-to-config-json>
```

#### Run Device Container

```bash
qimsdk-docker-device-run-container <path-to-config-json>
```

<div id="Docker_Container_In_CDI_Mode">

## Docker Container In CDI Mode

<div id="Prerequisites_For_CDI">

### Prerequisites For CDI

1. Docker version 25 or higher is required on the device.
2. CDI feature must be enabled in device's */etc/docker/daemon.json* file, if it is not enabled.

  ```json
  {
    "features": {
      "cdi": true
    }
  }
  ```
3. Docker service needs to be restarted in order the new changes to take effect.
```bash
systemctl restart docker
```
*Note: If restarting the docker service fails, please check /etc/docker/daemon.json for syntax errors.*

<div id="Running_The_Container_In_CDI_Mode">

### Running The Container In CDI Mode
To run the container in CDI mode **qimsdk-docker-device-run-cdi-container** command should be invoked instead of **qimsdk-docker-device-run-container**.
```bash
qimsdk-docker-device-run-cdi-container <path-to-config-json>
```

<div id="Examples_For_Development">

## Examples For Development

<div id="Remote_Device_With_Disabled_Verity">

### Remote Device With Disabled Verity

- Scenario is:
  - Device connected to remote machine
  - Device with disabled verity
  - Incremental Build

#### Initial Setup

Prepare the environment on remote machine with device connected to it

```bash
# Remote machine with device connected to it
############################################
# Prepare Device For Work
qimsdk-device-prepare
```

#### Continuous Development

Build docker image and save the docker image to file on build machine

```bash
# Build machine
###############
# Build docker image
qimsdk-docker-build-image <path-to-config-json>
# Save docker image and run command to Docker_image_path
qimsdk-docker-device-save-image <path-to-config-json>
```

Load docker image and run the container on remote machine with device connected to it

```bash
# Remote machine with device connected to it
############################################
# Load docker image from Docker_image_path
qimsdk-docker-device-load-image <path-to-config-json>
# Run device container
qimsdk-docker-device-run-container <path-to-config-json>
```

<div id="Local_Device_With_Verity_Check">

### Local Device With Verity Check

- Scenario is:
  - Locally connected device
  - Device with verity check
  - Incremental Build

#### Initial Setup

Prepare the environment

```bash
# Disable device verity check
qimsdk-device-prepare
adb disable-verity
adb reboot
# Prepare Device For Work
qimsdk-device-prepare
```

#### Continuous Development

Build docker image, update image to the device, run device container

```bash
# Build docker image
qimsdk-docker-build-image <path-to-config-json>
# Update docker image on the device
qimsdk-docker-device-update-image <path-to-config-json>
# Run device container
qimsdk-docker-device-run-container <path-to-config-json>
```

<div id="Contributing_to_the_GStreamer_Project">

### Contributing to the GStreamer Project

Inside the development container, New CMake and Meson projects can be added to extend qimsdk functionalities.

***Please NOTE: ssh config and git config are not propagated to development container environmens. This is because during development container use, root user is needed in order to manipulate and access /usr/lib and /usr/include. This is a very important requirement and prerequisite for development and compilation. Hence why host user cannot be used in development container instead of root user.***

#### A new CMake Project

1. Add source code and top-level CMakeLists.txt file in Project Directory.
  - Project Directory Name should be same as project name.
  - It is recommended to add projects as subdirectiories of /mnt/work/src/gst-plugins-qti-oss
  - Example: /mnt/work/src/gst-plugins-qti-oss/\<Project-Directory-Name\>

2. In /mnt/work/tmp/scripts/build.sh, add a function which calls base qimsdk-cmake-build function

```bash
# CMake Build <Project-Directory-Name>
function qimsdk-cmake-build-<Project-Directory-Name>() {
    local CONFIG_FLAGS="-DFLAG0=flag-value -DFLAG1=flag-value"

    qimsdk-cmake-build <Path/To/Project/Directory> ${CONFIG_FLAGS}
}
```

3. For new project to be compiled automatically during `qimsdk-incremental-build`, newly created function from last steps needs to be added to "qimsdk-incremental-build" in /mnt/work/tmp/scripts/build.sh

```bash
# Configure and build gst plugins
function qimsdk-incremental-build() {
...
...
...
        qimsdk-cmake-build-<Project-Directory-Name>
...
...
...
        print-green "QIMSDK GStreamer targets built successfully !!!"
}
```

4. Add cleanup function to /mnt/work/tmp/scripts/build.sh

```bash
# Clean CMake <Project-Directory-Name> build directory
function qimsdk-cmake-clean-<Project-Directory-Name>() {
    rm -rf ${QIMSDK_BUILD_DIR}/<Project-Directory-Name>

    print-green "${FUNCNAME} completed succesfully!"
}
```

#### A new Meson Project

1. Add source code and build description meson.build file in Project Directory.
  - Project Directory Name should be same as project name.
  - It is recommended to add projects as subdirectiories of /mnt/work/src/gst-plugins-qti-oss
  - Example: /mnt/work/src/gst-plugins-qti-oss/\<Project-Directory-Name\>

2. In /mnt/work/tmp/scripts/build.sh, add a function which calls base qimsdk-meson-build function

```bash
# Meson Build <Project-Directory-Name>
function qimsdk-meson-build-<Project-Directory-Name>() {
    local CONFIG_FLAGS="--flag0 flag-value --flag1 flag-value"
    local DESTINATION_DIR='/'

    qimsdk-meson-build <Path/To/Project/Directory> ${DESTINATION_DIR} ${CONFIG_FLAGS}
}
```

3. For new project to be compiled automatically during `qimsdk-incremental-build`, newly created function from last steps needs to be added to "qimsdk-incremental-build" in /mnt/work/tmp/scripts/build.sh

```bash
# Configure and build gst plugins
function qimsdk-incremental-build() {
...
...
...
        qimsdk-meson-build-<Project-Directory-Name>
...
...
...
        print-green "QIMSDK GStreamer targets built successfully !!!"
}
```

4. Add cleanup function to /mnt/work/tmp/scripts/build.sh

```bash
# Clean Meson <Project-Directory-Name> build directory
function qimsdk-meson-clean-<Project-Directory-Name>() {
    rm -rf ${QIMSDK_BUILD_DIR}/<Project-Directory-Name>

    print-green "${FUNCNAME} completed succesfully!"
}
```

<div id="Starting_the_container_with_docker_compose">

### Starting the container with docker-compose

```bash
docker-compose up -d -f <docker-compose.yml>
```

<div id="Starting_the_wayland">

### Starting the wayland

<h3 style="color:orange">In Scarthgap wayland needs to be started explicitly with the following command</h3>

```bash
adb shell "export GBM_BACKEND=msm && export XDG_RUNTIME_DIR=/dev/socket/weston && mkdir -p $XDG_RUNTIME_DIR  && weston --continue-without-input --idle-time=0"
```

<div id="Manual_Commands_Instead_Of_Scripts">

## Manual Commands Instead Of Scripts

<h3 style="color:orange">Prerequisites:</h3>

  - Instructions how to set up projects to be built inside QIMSDK Development container:
    - The following open-source projects need to be downloaded by the user.
    - Once synced, code for the following projects must be made available in <current/docker/dir>/tmp directory:
    <div name="gst-plugins-qti-oss"> gst-plugins-qti-oss</div>
    <ul>
      <div style="color:#90EE90">DIR: tmp/gst-plugins-qti-oss</div>

      ```bash
      # Example line to send synced project to temporary directory to be used by dev container:
      ln -s <path/to/sources>/gst-plugins-qti-oss <current/docker/dir>/tmp/gst-plugins-qti-oss
      ```
    </ul>

    <div name="meta-qti-gst"> meta-qti-gst</div>
    <ul>
      <div style="color:#90EE90">DIR: tmp/meta-qti-gst</div>

      ```bash
      # Example line to send synced project to temporary directory to be used by dev container:
      ln -s <path/to/sources>/meta-qti-gst <current/docker/dir>/tmp/meta-qti-gst
      ```

    </ul>

    <div name="solutions-microservices"> solutions-microservices</div>
    <ul>
      <div style="color:#90EE90">DIR: tmp/solutions-microservices</div>

      ```bash
      # Example line to send synced project to temporary directory to be used by dev container:
      ln -s <path/to/sources>/solutions-microservices <current/docker/dir>/tmp/solutions-microservices
      ```

      <div style="color:#90EE90">Update docker-compose files in solutions-microservices</div>

      ```bash
      # Example line to update docker-compose files in solutions-microservices:
      python3 <path/to/qimsdk>/scripts/tools/YamlUpdater.py
              -j <path/to/qimsdk>/targets/config.json
              -s <path/to/solutions-microservices>
      ```

    </ul>

    <div name="le-services"> le-services</div>
    <ul>
      <div style="color:#90EE90">DIR: tmp/le-services</div>

      ```bash
      # Example line to send synced project to temporary directory to be used by dev container:
      ln -s <path/to/sources>/le-services <current/docker/dir>/tmp/le-services
      ```

    </ul>

    <div name="headers"> HEADERS
    <ul>
      <div style="color:#90EE90">DIR: headers</div>

      ```bash
        cd <path/to/unarchived/eSDK/directory>/tmp/sysroots/${TARGET}/

        rsync -aR ./usr/include/fastcv/fastcv.h                                                    \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/iot-core-algs/ib2c.h                                               \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/properties.h                                                       \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/properties_def.h                                                   \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/log.h                                                              \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/system/camera_metadata.h                                           \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/system/camera_metadata_tags.h                                      \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/system/camera_vendor_tags.h                                        \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/hardware/graphics.h                                                \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/iot-core-algs/videoctrl.h                                          \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/hardware/native_handle.h                                           \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/dfs_factory.h                                                      \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/mv.h                                                               \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/mvSRW.h                                                            \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/mvVM.h                                                             \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/mvVSLAM.h                                                          \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rv.h                                                               \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvAE.h                                                             \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvCamera.h                                                         \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvDFS.h                                                            \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvGoalDetection.h                                                  \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvLog.h                                                            \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvNAVMAP.h                                                         \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvPLANNER.h                                                        \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvQueue.h                                                          \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvVIO.h                                                            \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvVM.h                                                             \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvVSLAM.h                                                          \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvVWSLAM.h                                                         \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rvWOD.h                                                            \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rv_dfs_base.h                                                      \
            <current/docker/dir>/tmp/headers/                                                   && \
        rsync -aR ./usr/include/rv_multi_dfs_base.h                                                \
            <current/docker/dir>/tmp/headers/
      ```
    </ul>

    <div>Get source code of gst-plugins-base-1.24.9 and gst-plugins-good-1.24.9
    <ul>
      <div name="gst-plugins-base", style="color:#90EE90">gst-plugins-base-1.24.9</div>

      ```bash
      wget -t 2 -T 30 --passive-ftp -P <current/docker/dir>/tmp/                                   \
        'https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.24.9.tar.xz' && \
        cd <current/docker/dir>/tmp/ && tar -xf gst-plugins-base-1.24.9.tar.xz                  && \
        rm -f gst-plugins-base-1.24.9.tar.xz
      ```

      <div name="gst-plugins-good", style="color:#90EE90">gst-plugins-good-1.24.9</div>

      ```bash
      wget -t 2 -T 30 --passive-ftp -P <current/docker/dir>/tmp/                                   \
        'https://gstreamer.freedesktop.org/src/gst-plugins-good/gst-plugins-good-1.24.9.tar.xz' && \
        cd <current/docker/dir>/tmp/ && tar -xf gst-plugins-good-1.24.9.tar.xz                  && \
        rm -f gst-plugins-good-1.24.9.tar.xz
      ```
    </ul>
    </div>

    <div name="patches"> PATCHES
    <ul>
      <div style="color:#90EE90">DIR: patches</div>

      content of patches directory:
      <div name="gst-plugins-base">gst-plugins-base-1.24.9</div>

      ```bash
        rsync -a <path/to/unarchived/eSDK/directory>/layers/meta-qti-gst/recipes-gst/gstreamer/gstreamer1.0-plugins-base/1.24/*.patch \
          <current/docker/dir>/tmp/patches/gst-plugins-base-1.24.9/
      ```
      <div name="gst-plugins-good">gst-plugins-good-1.24.9</div>

      ```bash
        rsync -a <path/to/unarchived/eSDK/directory>/layers/meta-qti-gst/recipes-gst/gstreamer/gstreamer1.0-plugins-good/1.24/*.patch \
          <current/docker/dir>/tmp/patches/gst-plugins-good-1.24.9/
      ```
    </ul>

    <div name="python">RecipeParser
      <div style="color:#6495ED">Take advantage of RecipeParser.py</div>
      <div style="color:#6495ED">Please note that supported targets are qcs6490, qcs9100 and qcs8300</div>

      <ul>
      <div style="color:#90EE90">BBPatchParser</div>
      <div style="color:#6495ED">
        Generates a json file with content of patches for every open source project.
        List of git changes that need to be applied is generated in corresponding correct sequence.
      </div>

        python3 ${QIMSDK_DOCKER_DIR}/scripts/tools/RecipeParser.py                                 \
                -l <path/to/unarchived/eSDK/directory>/layers                                      \
                -m <path/to/unarchived/eSDK/directory>/layers/meta-qti-gst                         \
                -p <target>                                                                        \
                -t <current/docker/dir>/tmp/                                                       \
                BBPatchParser

        mv <current/docker/dir>/tmp/<target>_recipes_patches.json <current/docker/dir>/tmp/recipes_patches.json
      </ul>

      <ul>
      <div style="color:#90EE90">BuildCodeGenerator</div>
      <div style="color:#6495ED">
        Automatically add build and clean functions for qti plugins.
      </div>

        python3 ${QIMSDK_DOCKER_DIR}/scripts/tools/RecipeParser.py                                 \
                -l <path/to/unarchived/eSDK/directory>/layers/                                     \
                -m <path/to/unarchived/eSDK/directory>/layers/meta-qti-gst                         \
                -p <target>                                                                        \
                -t <current/docker/dir>/tmp/                                                       \
                BuildCodeGenerator
      </ul>

      <ul>
      <div style="color:#90EE90">RuntimeFlagsGenerator</div>
      <div style="color:#6495ED">
        Generate json file with content of runtime flags with upcomming data from gstreamer recipes.
      </div>

        python3 ${QIMSDK_DOCKER_DIR}/scripts/tools/RecipeParser.py                                 \
                -l <path/to/unarchived/eSDK/directory>/layers/                                     \
                -m <path/to/unarchived/eSDK/directory>/layers/meta-qti-gst                         \
                -p <target>                                                                        \
                -t <current/docker/dir>/tmp/                                                       \
                RuntimeFlagsGenerator
      </ul>

    </div>

### Docker Build

  <div name="qnp"> QNP
  <ul>
  <div style="color:#90EE90">QNP version</div>
    QNP Version is set in Dockerfile as

    ENV QIMSDK_QNP_SDK=v2.24.0.240626.zip

  but it can be modified as

    ENV QIMSDK_QNP_SDK=v<major version>.<minor version>.<patch version>.<YY><MM><DD>.zip

  in Dockerfile

  </ul>
  </div>

  <div name="docker_build">Dockerfile arguments have default values, but they can be customized using **--build-arg** flag in docker build command, like so:</div>
  <ul>
  <div style="color:#FF4500">Variant Host</div>

  ```bash
  DOCKER_BUILDKIT=1 docker build                                                                   \
      --build-arg QIMSDK_ARG_BASE_DIR=/mnt/work                                                    \
      --progress=plain --target QIMSDK_device_image <path/to/Dockerfile/directory> -t <generated-image-name>
  ```
  </ul>

Once QIMSDK Device Image has been built, the following needs to be done to setup the environment on the device:

### Save QIMSDK Device Image in archive to be loaded from later:
```bash
docker save <generated-image-name>:latest -o qimsdk.tar
```

### Sync result product with other machine (OPTIONAL):
```bash
rsync -a qimsdk.tar /path/on/remote/destination/
```

### Push QIMSDK Device Image archive to the device.
```bash
adb push qimsdk.tar /tmp/
```

### Load QIMSDK Device Image
```bash
### adb shell
docker load -i /tmp/qimsdk.tar
```

### Run QIMSDK Device Container
  <h3 style="color:red">
    <b>Create a shell file with the following content:</b>
  </h3>

```bash
### adb shell
docker run -it -d                                                                                  \
--device /dev/dri/card0                                                                            \
--device /dev/dri/renderD128                                                                       \
--device /dev/kgsl-3d0                                                                             \
--device /dev/video32                                                                              \
--device /dev/video33                                                                              \
--device /dev/dma_heap/system                                                                      \
--device /dev/dma_heap/qcom,system                                                                 \
--device /dev/fastrpc-cdsp                                                                         \
-v /dev/socket/weston:/dev/socket/weston                                                           \
-v /tmp/socket/cam_server/:/tmp/socket/cam_server/                                                 \
-v /var/run/pulse/native:/var/run/pulse/native                                                     \
-v /usr/lib/gbm/default_fmt_alignment.xml:/usr/lib/gbm/default_fmt_alignment.xml                   \
-v /usr/lib/gbm/msm_gbm.so:/usr/lib/gbm/msm_gbm.so                                                 \
-v /usr/lib/gbm/msm_gbm.so.1:/usr/lib/gbm/msm_gbm.so.1                                             \
-v /usr/lib/gbm/msm_gbm.so.1.0.0:/usr/lib/gbm/msm_gbm.so.1.0.0                                     \
-v /usr/lib/libgbm.so.1:/usr/lib/libgbm.so.1                                                       \
-v /usr/lib/libgbm.so.1.0.0:/usr/lib/libgbm.so.1.0.0                                               \
-v /usr/lib/libatomic.so.1:/usr/lib/libatomic.so.1                                                 \
-v /usr/lib/libatomic.so.1.2.0:/usr/lib/libatomic.so.1.2.0                                         \
-v /usr/lib/libgsl.so:/usr/lib/libgsl.so                                                           \
-v /usr/lib/libgsl.so.1:/usr/lib/libgsl.so.1                                                       \
-v /usr/lib/libdmabufheap.so.0:/usr/lib/libdmabufheap.so.0                                         \
-v /usr/lib/libhta_hexagon_runtime_snpe.so:/usr/lib/libhta_hexagon_runtime_snpe.so                 \
-v /usr/lib/libPlatformValidatorShared.so:/usr/lib/libPlatformValidatorShared.so                   \
-v /usr/lib/libSNPE.so:/usr/lib/libSNPE.so                                                         \
-v /usr/lib/libSnpeDspV66Stub.so:/usr/lib/libSnpeDspV66Stub.so                                     \
-v /usr/lib/libSnpeHta.so:/usr/lib/libSnpeHta.so                                                   \
-v /usr/lib/libSnpeHtpPrepare.so:/usr/lib/libSnpeHtpPrepare.so                                     \
-v /usr/lib/libSnpeHtpV68Stub.so:/usr/lib/libSnpeHtpV68Stub.so                                     \
-v /usr/lib/libQnnChrometraceProfilingReader.so:/usr/lib/libQnnChrometraceProfilingReader.so       \
-v /usr/lib/libQnnGpu.so:/usr/lib/libQnnGpu.so                                                     \
-v /usr/lib/libQnnHtpProfilingReader.so:/usr/lib/libQnnHtpProfilingReader.so                       \
-v /usr/lib/libQnnCpu.so:/usr/lib/libQnnCpu.so                                                     \
-v /usr/lib/libQnnDspV66Stub.so:/usr/lib/libQnnDspV66Stub.so                                       \
-v /usr/lib/libQnnHtpNetRunExtensions.so:/usr/lib/libQnnHtpNetRunExtensions.so                     \
-v /usr/lib/libQnnHtp.so:/usr/lib/libQnnHtp.so                                                     \
-v /usr/lib/libQnnJsonProfilingReader.so:/usr/lib/libQnnJsonProfilingReader.so                     \
-v /usr/lib/libQnnDspNetRunExtensions.so:/usr/lib/libQnnDspNetRunExtensions.so                     \
-v /usr/lib/libQnnGpuNetRunExtensions.so:/usr/lib/libQnnGpuNetRunExtensions.so                     \
-v /usr/lib/libQnnHtpOptraceProfilingReader.so:/usr/lib/libQnnHtpOptraceProfilingReader.so         \
-v /usr/lib/libQnnSaver.so:/usr/lib/libQnnSaver.so                                                 \
-v /usr/lib/libQnnDsp.so:/usr/lib/libQnnDsp.so                                                     \
-v /usr/lib/libQnnGpuProfilingReader.so:/usr/lib/libQnnGpuProfilingReader.so                       \
-v /usr/lib/libQnnHtpPrepare.so:/usr/lib/libQnnHtpPrepare.so                                       \
-v /usr/lib/libQnnSystem.so:/usr/lib/libQnnSystem.so                                               \
-v /usr/lib/libQnnHtpV68Stub.so:/usr/lib/libQnnHtpV68Stub.so                                       \
-v /usr/lib/rfsa/adsp/libSnpeHtpV68Skel.so:/usr/lib/rfsa/adsp/libSnpeHtpV68Skel.so                 \
-v /usr/lib/rfsa/adsp/libQnnHtpV68Skel.so:/usr/lib/rfsa/adsp/libQnnHtpV68Skel.so                   \
-v /usr/lib/rfsa/adsp/libQnnHtpV68.so:/usr/lib/rfsa/adsp/libQnnHtpV68.so                           \
-v /usr/lib/rfsa/adsp/libQnnSaver.so:/usr/lib/rfsa/adsp/libQnnSaver.so                             \
-v /usr/lib/rfsa/adsp/libQnnSystem.so:/usr/lib/rfsa/adsp/libQnnSystem.so                           \
-v /usr/lib/libenv_time.so:/usr/lib/libenv_time.so                                                 \
-v /usr/lib/libevaluation_proto.so:/usr/lib/libevaluation_proto.so                                 \
-v /usr/lib/libimage_metrics.so:/usr/lib/libimage_metrics.so                                       \
-v /usr/lib/libjpeg_internal.so:/usr/lib/libjpeg_internal.so                                       \
-v /usr/lib/libtensorflowlite_c.so:/usr/lib/libtensorflowlite_c.so                                 \
-v /usr/lib/libtf_logging.so:/usr/lib/libtf_logging.so                                             \
-v /usr/lib/libVideoCtrl.so:/usr/lib/libVideoCtrl.so                                               \
-v /usr/lib/libIB2C.so:/usr/lib/libIB2C.so                                                         \
-v /usr/lib/libIB2C.so.1:/usr/lib/libIB2C.so.1                                                     \
-v /usr/lib/libIB2C.so.1.0:/usr/lib/libIB2C.so.1.0                                                 \
-v /usr/lib/libEGL_adreno.so:/usr/lib/libEGL_adreno.so                                             \
-v /usr/lib/libEGL_adreno.so.1:/usr/lib/libEGL_adreno.so.1                                         \
-v /usr/lib/libGLESv2_adreno.so:/usr/lib/libGLESv2_adreno.so                                       \
-v /usr/lib/libGLESv2_adreno.so.2:/usr/lib/libGLESv2_adreno.so.2                                   \
-v /usr/lib/libpropertyvault.so.0:/usr/lib/libpropertyvault.so.0                                   \
-v /usr/lib/libpropertyvault.so.0.0.0:/usr/lib/libpropertyvault.so.0.0.0                           \
-v /usr/lib/libwayland-client.so.0:/usr/lib/libwayland-client.so.0                                 \
-v /usr/lib/libwayland-egl.so.1:/usr/lib/libwayland-egl.so.1                                       \
-v /usr/lib/libadreno_utils.so:/usr/lib/libadreno_utils.so                                         \
-v /usr/lib/libadreno_utils.so.1:/usr/lib/libadreno_utils.so.1                                     \
-v /usr/lib/libCB.so:/usr/lib/libCB.so                                                             \
-v /usr/lib/libEGL.so:/usr/lib/libEGL.so                                                           \
-v /usr/lib/libEGL.so.1:/usr/lib/libEGL.so.1                                                       \
-v /usr/lib/libEGL.so.1.0:/usr/lib/libEGL.so.1.0                                                   \
-v /usr/lib/libEGL.so.1.0.0:/usr/lib/libEGL.so.1.0.0                                               \
-v /usr/lib/libeglSubDriverWayland.so:/usr/lib/libeglSubDriverWayland.so                           \
-v /usr/lib/libGLESv1_CM.so:/usr/lib/libGLESv1_CM.so                                               \
-v /usr/lib/libGLESv1_CM.so.1:/usr/lib/libGLESv1_CM.so.1                                           \
-v /usr/lib/libGLESv1_CM.so.1.0:/usr/lib/libGLESv1_CM.so.1.0                                       \
-v /usr/lib/libGLESv1_CM.so.1.0.0:/usr/lib/libGLESv1_CM.so.1.0.0                                   \
-v /usr/lib/libGLESv1_CM_adreno.so:/usr/lib/libGLESv1_CM_adreno.so                                 \
-v /usr/lib/libGLESv2.so:/usr/lib/libGLESv2.so                                                     \
-v /usr/lib/libGLESv2.so.2:/usr/lib/libGLESv2.so.2                                                 \
-v /usr/lib/libGLESv2.so.2.0:/usr/lib/libGLESv2.so.2.0                                             \
-v /usr/lib/libGLESv2.so.2.0.0:/usr/lib/libGLESv2.so.2.0.0                                         \
-v /usr/lib/libllvm-glnext.so:/usr/lib/libllvm-glnext.so                                           \
-v /usr/lib/libllvm-glnext.so.1:/usr/lib/libllvm-glnext.so.1                                       \
-v /usr/lib/libllvm-qcom.so:/usr/lib/libllvm-qcom.so                                               \
-v /usr/lib/libllvm-qgl.so:/usr/lib/libllvm-qgl.so                                                 \
-v /usr/lib/libOpenCL.so:/usr/lib/libOpenCL.so                                                     \
-v /usr/lib/libOpenCL_adreno.so:/usr/lib/libOpenCL_adreno.so                                       \
-v /usr/lib/libq3dtools_adreno.so:/usr/lib/libq3dtools_adreno.so                                   \
-v /usr/lib/libq3dtools_esx.so:/usr/lib/libq3dtools_esx.so                                         \
-v /usr/lib/libvulkan_adreno.so:/usr/lib/libvulkan_adreno.so                                       \
-v /usr/lib/libQnnTFLiteDelegate.so:/usr/lib/libQnnTFLiteDelegate.so                               \
-v /usr/lib/libadsprpc.so:/usr/lib/libadsprpc.so                                                   \
-v /usr/lib/libcdsprpc.so:/usr/lib/libcdsprpc.so                                                   \
-v /usr/lib/libcdsprpc.so.1:/usr/lib/libcdsprpc.so.1                                               \
-v /usr/lib/libcdsprpc.so.1.0.0:/usr/lib/libcdsprpc.so.1.0.0                                       \
-v /usr/lib/libfastcvopt.so:/usr/lib/libfastcvopt.so                                               \
-v /usr/lib/libfastcvopt.so.1:/usr/lib/libfastcvopt.so.1                                           \
-v /usr/lib/libfastcvopt.so.1.8.0:/usr/lib/libfastcvopt.so.1.8.0                                   \
-v /usr/lib/dsp/cdsp/cv/v68/KODIAK/libfastcvdsp_skel.so:/usr/lib/dsp/cdsp/cv/v68/KODIAK/libfastcvdsp_skel.so \
-v /usr/lib/dsp/cdsp/cv/v68/KODIAK/libfastcvadsp.so:/usr/lib/dsp/cdsp/cv/v68/KODIAK/libfastcvadsp.so \
-v /usr/lib/libfastcvdsp_stub.so:/usr/lib/libfastcvdsp_stub.so                                     \
-v /usr/lib/libfastcvdsp_stub.so.1:/usr/lib/libfastcvdsp_stub.so.1                                 \
-v /usr/lib/libfastcvdsp_stub.so.1.8.0:/usr/lib/libfastcvdsp_stub.so.1.8.0                         \
-v /usr/lib/libdmabufheap.so.0.0.0:/usr/lib/libdmabufheap.so.0.0.0                                 \
-v /usr/lib/dsp/cdsp/libc++.so.1:/usr/lib/dsp/cdsp/libc++.so.1                                     \
-v /usr/lib/dsp/cdsp/libc++abi.so.1:/usr/lib/dsp/cdsp/libc++abi.so.1                               \
-v /usr/lib/libcamera_metadata.so:/usr/lib/libcamera_metadata.so                                   \
-v /usr/lib/librv.so:/usr/lib/librv.so                                                             \
-v /usr/lib/libmv1.so:/usr/lib/libmv1.so                                                           \
-v /usr/lib/libmv3.so:/usr/lib/libmv3.so                                                           \
-v /etc/labels:/etc/labels                                                                         \
-v /etc/media:/etc/media                                                                           \
-v /etc/models:/etc/models                                                                         \
-e XDG_RUNTIME_DIR=/dev/socket/weston -e WAYLAND_DISPLAY=wayland-1 -e GST_DEBUG_NO_COLOR=1         \
-h qimsdk-<container-name> --user qimsdk --name qimsdk-<container-name> qimsdk-<image-name>
```

<h3 style="color:red">
  <b>
  Please note that list of device and mounted libraries changes frequently,
  so refer to the config.json
    "Platform_Specific_Mappings" attribute for device list
    and
    "Platform_Libraries_To_Mount" attribute for list of libraries to mount

  push the shell file to the device and execute it
  </b>
</h3>

### Execute QIMSDK Device Container
```bash
### adb shell
docker exec -ti <desired-container-name> bash
```

***NOTE: If "No space left on device" error is encountered on the device, a cleanup of all old docker images needs to be done using this command:***

```bash
### adb shell
docker rmi $(docker images | grep "^<none>" | awk '{print $3}' )
docker builder prune -a -f
```

<div id="Device_Docker_Clean_Up">

### Device Docker Clean Up

- Scenario is:
  - Device storage is full and docker image clean up is required

#### Initial Setup

Prepare the environment

```bash
# Prepare Device For Work
qimsdk-device-prepare
```

#### Device Docker Clean Up

Clean up old docker images

```bash
qimsdk-docker-device-images-cleanup
```

<div id="Development_when_device_is_not_connected_to_host_build_machine">

### Development when device is not connected to host build machine

**Prerequisites**:

- In order to use this functionality, there are some requirements:
  - qimsdk-v2.0 directory is needed in Build machine, where QIMSDK device image is generated.
  - qimsdk-v2.0 directory is needed in Remote PC, connected to device.

The following steps can be followed to use QIMSDK device image on a target, connected to a remote PC:

#### Steps to follow on the Build machine:

1. In **Build machine** config json, set ***"Docker_image_path"*** field to path, from which remote machine will copy built QIMSDK image and needed config files. (Path can also be on the remote machine.)

2. Build QIMSDK device image

```bash
# Build docker image
qimsdk-docker-build-image <path-to-config-json>
```

3. Save qimsdk device image to Docker_image_path listed in json

```bash
# Save docker image and run command
qimsdk-docker-device-save-image <path-to-config-json>
```

#### Steps to follow on the Machine, connected to the device:

1. In **Remote machine** config json, set ***"Docker_image_path"*** field to path, where build machine has saved built QIMSDK image and needed config files. (Same as previously set in build image json.)

2. Load QIMSDK device image

```bash
# Load docker image
qimsdk-docker-device-load-image <path-to-config-json>
```

3. Stop and Remove any previous instances of container with same name, to avoid error

```bash
# Stop and Remove container
qimsdk-docker-device-stop-container <path-to-config-json>
qimsdk-docker-device-rm-container <path-to-config-json>
```

4. Run container

```bash
# Run container
qimsdk-docker-device-run-container <path-to-config-json>
```

5. From here any qimsdk-docker-device... functions can be used freely on remote PC.

#### Python scripts to load image, run container and build artifacts from Windows
*Note: Docker_image_path in json file should be path from host machine*

#### Windows

#### Install necessary pip3 packages

```powershell
pip3 install colorama
```

Example for adding adb to powershell path

```powershell
$Env:PATH += ";<path to adb>"
```

1. Load QIMSDK device image via python

```powershell
# Load docker image
python3 DockerEssentials.py -j <path-to-qimsdk-project>\targets\config.json load_image
```

2. Run container via python

```powershell
# Run container
python3 DockerEssentials.py -j <path-to-qimsdk-project>\targets\config.json run_container
```

3. Load artifacts to the existing docker container in device

3.1 Load release artifacts

```powershell
python3 DockerEssentials.py -j <path-to-qimsdk-project>\targets\config.json load_artifacts -v release
```

3.2 Load debug artifacts
```powershell
python3 DockerEssentials.py -j <path-to-qimsdk-project>\targets\config.json load_artifacts -v debug
```

<div id="Docker_Container_Renaming">

## Docker Container Renaming

<div id="Rename_device's_Docker_container_from_host_development_container">

### Rename device's Docker container from host development container
Device's container name from development container can be changed by exporting QIMSDK_CONTAINER_NAME
```bash
export QIMSDK_CONTAINER_NAME=<new-container-name>
```

<div id="Rename_Docker_Device_Container">

### Rename Docker Device Container

Device Container can be renamed by using the "Additional_tag_container" in *config.json*

*Note: Keep in mind that "qimsdk" prefix will be automatically prepend to that name.*
