# QIM SDK Debian

## Table of Contents

* [Prerequisites](#Prerequisites)
  * [Ubuntu Version](#Ubuntu_Version)
  * [Ubuntu Packages](#Ubuntu_Packages)
  * [How to increase Max user watches and max user instances on host system](#Max_user_watches)
  * [Docker Must Be Configured On The Host System (one time)](#Docker_Host_System)
  * [Add internal docker registry mirror. (optional)](#Add_internal_docker_registry_mirror)
  * [Proxy. (optional)](#Proxy)
* [Docker Images](#Docker_Images)
  * [AIML Build Image](#AIML_Build_Image)
  * [AIML Deploy Image](#AIML_Deploy_Image)
  * [QIMSDK Debug Image](#QIMSDK_Debug_Image)
  * [QIMSDK Build Image](#QIMSDK_Build_Image)
  * [QIMSDK Deploy Image](#QIMSDK_Deploy_Image)
* [Debug Variant - Host Side Helper Scripts And Configuration](#Host_Side_Helper_Scripts)
  * [How to fill out Configuration JSON Files](#How_to_fill_out_Configuration_JSON_Files)
  * [Docker Host Side Helper Scripts](#Docker_Host_Side_Helper_Scripts)
  * [Docker Debug Container Side Helper Scripts](#Docker_Debug_Container_Side_Helper_Scripts)
* [Development Workflow](#Development_Workflow)
  * [Initial One Time Setup](#Initial_One_Time_Setup)
  * [Continuous Development After Initial Setup](#Continuous_Development_After_Initial_Setup)
* [Examples For Development](#Examples_For_Development)
  * [Remote Device With Disabled Verity](#Remote_Device_With_Disabled_Verity)
  * [Local Device With Verity Check](#Local_Device_With_Verity_Check)
  * [Contributing to the GStreamer Project](#Contributing_to_the_GStreamer_Project)
  * [Starting the container with docker-compose](#Starting_the_container_with_docker_compose)
  * [Device Docker Clean Up](#Device_Docker_Clean_Up)
  * [Development when device is not connected to host build machine](#When_device_is_not_connected)
* [Docker Container Renaming](#Docker_Container_Renaming)
  * [Rename Docker Device Container](#Rename_Docker_Device_Container)
* [Release Variant - Manual Commands Instead Of Scripts](#Manual_Commands_Instead_Of_Scripts)
  * [Docker Build](#Docker_Build)
  * [Save QIMSDK Deploy Image in archive to be loaded from later](#Save_QIMSDK_Deploy_Image)
  * [Sync result product with other machine (OPTIONAL)](#Sync_result_product)
  * [Push QIMSDK Deploy Image archive to the device](#Push_Deploy_Image_to_the_device)
  * [Load QIMSDK Deploy Image](#Load_QIMSDK_Deploy_Image)
  * [Run QIMSDK Deploy Container](#Run_QIMSDK_Deploy_Container)
  * [Execute QIMSDK Deploy Container](#Execute_QIMSDK_Deploy_Container)
* [Contributing to qimsdk-debian open-source repository](#Contributing_to_open-source)

<div id="Prerequisites">

## Prerequisites

<div id="Ubuntu_Version">

### Ubuntu Version

Ubuntu 22.04 or 24.04 is required for host ARM system

<div id="Ubuntu_Packages">

### Ubuntu Packages

Prerequisite packages must be installed on the host (one time)

```bash
sudo apt install -y jq tofrodos
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq
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
sudo fromdos -f /etc/docker/daemon.json
sudo systemctl daemon-reload
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
sudo systemctl daemon-reload
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
docker run hello-world
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
- They are based on two aiml images, provided by platform team. One for development, One for device target, accordingly.
- A Third QIMSDK debug image is only used when working in an environment which requires continuous development.

NOTE: aiml images' Dockerfile source is in https://github.com/qualcomm-linux/aiml-container-test/tree/main repository.
- In Debug configuration user provides a directory in local file system, where aiml-container-test repository is synced.
- In Release configuration qimsdk debian image that is deployed on the device is based on a ready-built docker image ghcr.io/koenkooi/aiml-container-test, uploaded to qualcomm docker repository.

<div id="AIML_Build_Image">

### AIML Build Image
1. Start from debian trixie slim base image
2. Install required open source packages
3. Apply necessary changes to projects to be built
4. Build and install qimsdk dependencies: libtensorflow_lite

<div id="AIML_Deploy_Image">

### AIML Deploy Image
1. Start from debian trixie slim base image
2. Install required open source packages
3. Install packages with qimsdk dependency libs: mesa, gles, freedreno libs etc.
4. Copy dependency libs from qimsdk dependencies built in aiml build image: libtensorflow_lite

<div id="QIMSDK_Debug_Image">

### QIMSDK Debug Image
1. Start from AIML Build Image
2. Alter git configuration in QIMSDK Build Image to use gst meta layers locally provided by user in config json instead of codelinaro
3. Alter git configuration in QIMSDK Build Image to use gst source code locally provided by user in config json instead of codelinaro
4. Copy helper scripts to build image
5. Set dev environment variables for build image

<div id="QIMSDK_Build_Image">

### QIMSDK Build Image
1. Start from AIML Build Image
2. Install required open source packages to build image
3. Install required open source packages for deploy image to build image
4. Copy build and install scripts to build image
5. Fetch meta layers with patches needed and apply patches to opensource gst repositories
6. Fetch gst source code from codelinaro
7. Call wrapper function to build and install plugins

<div id="QIMSDK_Deploy_Image">

### QIMSDK Deploy Image
1. Start from AIML Deploy Image
2. Install runtime dependency Open Source packages to deploy image
3. Copy built binaries from QIMSDK Build Image
4. Add qimsdk user
5. Add environment variables

<div id="Host_Side_Helper_Scripts">

## Debug Variant - Host Side Helper Scripts And Configuration

In debug variant of the environment, qimsdk-debian/scripts-dbg scripts can be used to build QIMSDK Build Image and run a debug container from it on developer machine, in which given gst code can be continuously altered, built and deployed.

More details on how this is done can be found below.

<div id="How_to_fill_out_Configuration_JSON_Files">

### How to fill out Configuration JSON Files

In qimsdk-debian project, two configuration json files are used:
 - One is generic config json *(config.json)*. Used to configure environment compilation.
 - The others are target specific json *(\<target-name\>.json)*. Used to configure containers to be run for that specific target.

Config json files *(config.json)* must contain the following data:
 1. ***MANDATORY*** - **Additional_tag_container** - Additional tag for debug container - allows for personalization of the names of the docker containers according to their purpose - allows to avoid container conflict if more than one user on the same machine.
 2. ***MANDATORY*** - **Additional_tag_image** - Additional tag for docker image - allows for personalization of the names of the docker images according to their purpose - allows to avoid image conflicts if more than one user on the same machine.
 3. ***MANDATORY*** - **Docker_image_path** - Remote ssh destination or local path to sync docker images or artifacts
 4. ***MANDATORY*** -  **Target_device_ID** - adb device ID of the target device qimsdk is to be installed on. Any faux value can still be provided and compilation will carry on.
 5. ***MANDATORY*** - **IM_SDK_Source_Dir** - PATH to IM SDK sources directory, which contains all gst plugins. ***Note: Path provided must point to gst-plugins-qti-oss directory! Code checked out on local branch imsdk.lnx.2.0.0 will be built. Ensure desired code is checked out on imsdk.lnx.2.0.0 branch before proceeding with debug variant QIMSDK build!***
 6. ***MANDATORY*** - **IM_SDK_Meta_Dir** - PATH to meta IM SDK directory, which contains recipes for all gst plugins. ***Note: Path provided must point to meta-qti-gst directory! Code checked out on local branch imsdk.lnx.2.0.0 will be built. Ensure desired code is checked out on imsdk.lnx.2.0.0 branch before proceeding with debug variant QIMSDK build!***
 7. ***MANDATORY*** - **Path_to_aiml_container** - PATH to folder, containing base AIML Dockerfile. ***Note: Path provided must point to code from latest origin/main branch of https://github.com/qualcomm-linux/aiml-container-test repo. User must have this repository cloned locally in build machine storage. Path must point to that directory.***
 8. ***OPTIONAL*** - **MAP_sources_to_dev_container** - If IM_SDK_Source_Dir, LE_Services_Source_Dir is wanted to be mapped to the build container, then this attribute should be filled as "TRUE" or "ENABLE" or "ENABLED" ***Note: Default is FALSE***

Target specific json files *(\<target-name\>.json)* must contain the following data:
 1. ***OPTIONAL*** - **Exports** - set of variables, which will be exported in docker container in platform
 2. ***MANDATORY*** - **Soc** - A list of different Soc names that target could be referred to. Needed for qimsdk to recognise what system it is trying to work with.
 3. ***OPTIONAL*** - **User_Exports** - User variables, which will be exported as environment variables in qimsdk device container.
 4. ***OPTIONAL*** - **User_Libraries_To_Mount** - User libraries to mount to device docker container.
 5. ***OPTIONAL*** - **User_Specific_Mappings** - User specific mappings to be mounted during device docker run container function.

<div id="Docker_Host_Side_Helper_Scripts">

### Docker Host Side Helper Scripts

When using the environment in debug mode, these functions are for building and maintaining docker images and containers.

***In order for the functions inside docker_env_setup.sh to work on the host, the script must be sourced***

```bash
cd sdk-tools/qimsdk-debian
source scripts-dbg/docker_env_setup.sh
```

The developer generally needs to build the deploy image, load it to the device and run the QIMSDK deploy container.

- qimsdk-device-prepare - Prepare device after reboot
- qimsdk-docker-build-image            \<path-to-config-json> - Alter QIMSDK Build Image to use gst code and meta layers provided by user in config json. Afterwards, build QIMSDK Build Image and Build QIMSDK Deploy Image with needed artifacts from build image.
- qimsdk-docker-device-update-image    \<path-to-config-json> - Update QIMSDK Deploy Image to the device
- qimsdk-docker-device-save-image      \<path-to-config-json> - Save QIMSDK Deploy Image as a tar file, compose file and run command
- qimsdk-docker-device-load-image      \<path-to-config-json> - Loads QIMSDK Deploy Image on the device
- qimsdk-docker-device-run-container \<path-to-config-json> - Run device container from QIMSDK Deploy Image
- qimsdk-docker-device-rm-container    \<path-to-config-json> - Remove device container
- qimsdk-docker-device-start-container \<path-to-config-json> - Start device container
- qimsdk-docker-device-stop-container  \<path-to-config-json> - Stop device container
- qimsdk-docker-device-command  \<path-to-config-json> \<CMD> - Execute CMD in device container
- qimsdk-docker-device-shell           \<path-to-config-json> - Start shell in the docker container on the device
- qimsdk-docker-device-images-cleanup  \<path-to-config-json> - Docker device images clean up
- qimsdk-docker-host-images-cleanup                           - Docker host images clean up

<div id="Docker_Debug_Container_Side_Helper_Scripts">

### Docker Debug Container Side Helper Scripts

These functions are for building and maintaining debug docker images and containers.

***In order to build and run debug container, the script must be sourced***

```bash
source scripts-dbgs/docker_env_setup.sh
```

 - qimsdk-dbg-docker-build-image       \<path-to-config-json> - Alter QIMSDK Build Image to use gst code and meta layers provided by user in config json. Afterwards, build QIMSDK Build Image
 - qimsdk-dbg-docker-run-container     \<path-to-config-json> - Run Debug container where developer can continuously edit and compile gst code provided in config json
 - qimsdk-dbg-load-artifacts           \<path-to-config-json> - Load artifacts from specified Docker_image_path in configuration json file and install them to the device. They are installed in a shared directory between device and device container
 - qimsdk-dbg-load-artifacts-dbg       \<path-to-config-json> - Load debug artifacts from specified Docker_image_path in configuration json file and install them to the device. They are installed in a shared directory between device and device container

These functions are available immediately inside development container:

 - qimsdk-incremental-build-qti - Incremental build of all qti gst plugins
 - qimsdk-help-build - Display all cmake functions to build/clean any gst plugin
 - qimsdk-incremental-build - Incremental build of all gst plugins
 - qimsdk-dbg-save-artifacts - Save release variant artifacts to specified Docker_image_path in configuration json file. They can then be loaded using the load functions in the environment
 - qimsdk-dbg-save-artifacts-dbg - Save debug variant artifacts to specified Docker_image_path in configuration json file. They can then be loaded using the load functions in the environment
 - qimsdk-dbg-push-artifacts - Push release variant artifacts to device with specified id in configuration json file
 - qimsdk-dbg-push-artifacts-dbg - Push debug variant artifacts  to device with specified id in configuration json file

### Changing environment for deploy image size optimization

If the user wishes to reduce the size of qimsdk-debian deploy image, that can be done by no longer installing the runtime dependency apt packages.

Instead, these packages' minimal set of needed libraries and other contents can be copied over from build image.
That can reduce deploy image size by approximately 1.01GB.

From Dockerfile snippet in deploy image, which installs apt packages:

```
RUN apt-get update                                                                              && \
        DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y                               \
        adduser bash-completion nano libhiredis1.1.0 gstreamer1.0-tools ocl-icd-libopencl1 wget    \
        mesa-opencl-icd libopencl-clang-19-dev libgstrtspserver-1.0-0 libopencv-imgproc410         \
        gstreamer1.0-plugins-good pulseaudio gstreamer1.0-plugins-base gstreamer1.0-gl             \
        libgraphene-1.0-dev libgl1 libegl1 libwayland-egl1 libwayland-dev                          \
        gstreamer1.0-plugins-ugly                                                               && \
        apt -y upgrade                                                                          && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*
```

**These packages need to be removed from apt install list:**

ocl-icd-libopencl1 wget mesa-opencl-icd libopencl-clang-19-dev libgstrtspserver-1.0-0 libopencv-imgproc410 gstreamer1.0-plugins-good pulseaudio gstreamer1.0-plugins-base gstreamer1.0-gl libgraphene-1.0-dev libgl1 libegl1 libwayland-egl1 libwayland-dev gstreamer1.0-plugins-ugly

This snippet in Dockerfile describing the deploy image, needs to be deleted:

```
# Add deb-src for everything
RUN sed -Ei 's/^Types: deb$/Types: deb deb-src/'  /etc/apt/sources.list.d/debian.sources        && \
    wget --no-check-certificate https://github.com/qualcomm-linux/qcom-deb-images/raw/refs/heads/main/debos-recipes/overlays/qsc-deb-releases/etc/apt/keyrings/qsc-deb-releases.asc -O /etc/apt/keyrings/qsc-deb-releases.asc

COPY <<EOF /etc/apt/sources.list.d/qsc-deb-releases.sources
# QArtifactory qsc-deb-releases repository
# NB: publishing Sources indices for deb-src isn't supported by Artifactory,
# but sources are published with other packages files
Types: deb
URIs: https://qartifactory-edge.qualcomm.com/artifactory/qsc-deb-releases
Suites: trixie-overlay
Components: main
Signed-By: /etc/apt/keyrings/qsc-deb-releases.asc
Enabled: yes
EOF

# Update again
# Install the basic mesa dependencies to make our build work
# Install libegl-mesa0 which contains the mesa vendor library for EGL.
RUN DEBIAN_FRONTEND=noninteractive apt-get update                                               && \
    apt -y install mesa-common-dev libegl-dev libgles-dev libgl1-mesa-dri libegl-mesa0          && \
        apt -y upgrade                                                                          && \
        apt-get autoremove -y                                                                   && \
        apt-get clean                                                                           && \
        rm -rf /var/lib/apt/lists* /var/tmp/*
```

In place of qimsdk-propagate-prebuilt-libs in Dockerfile section describing the build image, qimsdk-propagate-all-prebuilt-libs needs to be called.

Instead of:

```
# Sync prebuilt libs
RUN bash /root/.bashrc qimsdk-propagate-prebuilt-libs
```

It should look like this:

```
# Sync prebuilt libs
RUN bash /root/.bashrc qimsdk-propagate-all-prebuilt-libs
```

<div id="Development_Workflow">

## Development Workflow

<div id="Initial_One_Time_Setup">

### Initial One Time Setup

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

#### Save Compiled Docker Image, Compose file and Run Command To Remote Docker_image_path

```bash
qimsdk-docker-device-save-image <path-to-config-json>
```

#### Load Saved Docker Image From Remote Docker_image_path To Locally Connected Device

```bash
qimsdk-docker-device-load-image <path-to-config-json>
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
# Save docker image, compose file and run command to Docker_image_path
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

Inside the development container, New CMake project can be added to extend qimsdk functionalities.

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

<div id="Starting_the_container_with_docker_compose">

### Starting the container with docker-compose

```bash
docker-compose -f <docker-compose.yml> up -d
```

Docker compose file gets automatically generated by `qimsdk-docker-device-save-image <path-to-config-json>` command, user need to manually transfer it to the device and pass it to the docker-compose command.


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

<div id="When_device_is_not_connected">

### Development when device is not connected to host build machine

**Prerequisites**:

- In order to use this functionality, there are some requirements:
  - sdk-tools directory is needed in Build machine, where QIMSDK device image is generated.
  - sdk-tools directory is needed in Remote PC, connected to device.

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
# Save docker image, compose file and run command
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
python3 DockerEssentials.py -j <path-to-qimsdk-debian-project>\targets\config.json load_image
```

2. Run container via python

```powershell
# Run container
python3 DockerEssentials.py -j <path-to-qimsdk-debian-project>\targets\config.json run_container
```

3. Load artifacts to the existing docker container in device

3.1 Load release artifacts

```powershell
python3 DockerEssentials.py -j <path-to-qimsdk-debian-project>\targets\config.json load_artifacts -v release
```

3.2 Load debug artifacts
```powershell
python3 DockerEssentials.py -j <path-to-qimsdk-debian-project>\targets\config.json load_artifacts -v debug
```

<div id="Docker_Container_Renaming">

## Docker Container Renaming

<div id="Rename_Docker_Device_Container">

### Rename Docker Device Container

Device Container can be renamed by using the "Additional_tag_container" in *config.json*

*Note: Keep in mind that "qimsdk" prefix will be automatically prepend to that name.*

<div id="Manual_Commands_Instead_Of_Scripts">

## Release Variant - Manual Commands Instead Of Scripts

In Release variant, qimsdk-debian build image can directly compile gst plugin code from codelinaro. After, gst plugins, together with dependencies can be propagated to deploy image and installed on device to run qimsdk-debian deploy container

In that case, the intermediate QIMSDK Debug Image is not built, and QIMSDK Deploy Image is not altered to use custom code provided by the user.

<div id="Docker_Build">

### Docker Build

  AIML Build and Deploy images need to be built as they are dependencies of QIMSDK Images. User needs to go to directory where aiml Dockerfile project is synced.

  Instructions how to build the two needed aiml docker images can be found here:
  https://github.com/qualcomm-linux/aiml-container-test/blob/main/README.md

  After building AIML images, return to sdk-tools/qimsdk-debian directory.

  <div name="docker_build">Dockerfile arguments have default values, but they can be customized using **--build-arg** flag in docker build command.</div>
  <ul>

  ```bash
  # Build qimsdk-debian deploy docker image
  DOCKER_BUILDKIT=1 docker build                                                                   \
      --progress=plain --target qimsdk-deploy <path/to/Dockerfile/directory> -t <generated-image-name>
  ```
  </ul>

Once QIMSDK Deploy Image has been built, the following needs to be done to setup the environment on the device:

<div id="Save_QIMSDK_Deploy_Image">

### Save QIMSDK Deploy Image in archive to be loaded from later:
```bash
docker save <generated-image-name>:latest -o qimsdk.tar
```

<div id="Sync_result_product">

### Sync result product with other machine (OPTIONAL):
```bash
rsync -a qimsdk.tar /path/on/remote/destination/
```

<div id="Push_Deploy_Image_to_the_device">

### Push QIMSDK Deploy Image archive to the device.
```bash
adb push qimsdk.tar /tmp/
```

<div id="Load_QIMSDK_Deploy_Image">

### Load QIMSDK Deploy Image
```bash
### adb shell
docker load -i /tmp/qimsdk.tar
```

<div id="Run_QIMSDK_Deploy_Container">

### Run QIMSDK Deploy Container
  <h3 style="color:red">
    <b>Create a shell file with the following content:</b>
  </h3>

```bash
### adb shell
docker run -it -d --net host                                                                       \
--device /dev/video0 --device /dev/video1 --device /dev/video2 --device /dev/video3                \
--device /dev/dri/card0 --device /dev/dri/renderD128 -v /run/user/1000:/run/user/1000              \
-v /etc/labels:/etc/labels -v /etc/media:/etc/media -v /etc/models:/etc/models                     \
-h qimsdk --name <desired-container-name> <generated-image-name>
```

<div id="Execute_QIMSDK_Deploy_Container">

### Execute QIMSDK Deploy Container
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

<div id="Contributing_to_open-source">

## Contributing to qimsdk-debian open-source repository

When making changes to qimsdk-debian, open-source repository hosted in github needs to be kept up to date.

Any changes in the following files need to be propagated to https://github.com/qualcomm-linux/aiml-container-test repo:

```
├── Dockerfile
├── README.md
├── scripts
    ├── build.sh
    ├── env_setup.sh
    └── setup.sh
```

### Steps to update open-source github.com repository

Changed contents in Dockerfile need to overwrite last part of aiml-container-test/Dockerfile, which holds the source code for the qimsdk-build and qimsdk-deploy images. That code is identical to local Dockerflie code.

Changed contents in README.md file need to overwrite the part of aiml-container-test/README.md after '## About The QIMSDK-Debian Docker Image' heading , which is identical to local README.md content.

Changed contents of scripts directory are copied over directly to aiml-container-test/scripts directory.
