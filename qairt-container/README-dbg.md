# Qualcomm Machine Learning

This project provides tools for simplified access to Qualcomm hardware accelerators for Machine Learning.
The docker build generates device image on host files system. The device image can be easily loaded and started on the device using helper scripts provided.

## Table of Contents

* [Prerequisites](#Prerequisites)
  * [Ubuntu Version](#Ubuntu_Version)
  * [Ubuntu Packages](#Ubuntu_Packages)
  * [How to increase Max user watches and max user instances on host system](#Max_user_watches)
  * [Add internal docker registry mirror. (optional)](#Add_internal_docker_registry_mirror)
  * [Docker Must Be Configured On The Host System (one time)](#Docker_Host_System)
* [Docker Images](#Docker_Images)
  * [QAIRT Image](#QAIRT_Image)
* [Helper Scripts And Configuration](#Helper_Scripts_And_Configuration)
  * [How to fill out Configuration JSON File](#How_to_fill_out_Configuration_JSON_File)
  * [Docker Host Side Helper Scripts](#Docker_Host_Side_Helper_Scripts)
  * [Development Host Side Helper Scripts](#Dev_Host_Side_Helper_Scripts)
* [Development Workflow](#Development_Workflow)
  * [Continuous Development](#Continuous_Development)
* [Examples For Development](#Examples_For_Development)
  * [Developing Python Scripts](#Developing_Python_Scripts)

<div id="Prerequisites">

## Prerequisites

<div id="Ubuntu_Version">

### Ubuntu Version

Ubuntu 24.04 is required for host file system

<div id="Ubuntu_Packages">

### Ubuntu Packages

jq and tofrodos must be installed on the host (one time)

```bash
sudo apt install -y jq tofrodos
```

<div id="Max_user_watches">

### Max user watches and max user instances must be increased on the host system

**Add these two lines to */etc/sysctl.conf* and reboot the PC**

```bash
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=542288
```

<div id="Add_internal_docker_registry_mirror">

### Add internal docker registry mirror. (optional)

#### Note: Using a tab instead of space and other invisible whitespace characters may break the proper work of json configuration files and later may lead docker.service failed to start.

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

<div id="Docker_Host_System(one_time)">

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

***Please note that until PC reboot, *newgrp docker* should be invoked on every new console open***

#### Install arm64 qemu docker driver

```bash
sudo apt-get install qemu-user-static qemu-system-arm
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx rm builder
docker buildx create --name builder --driver docker-container --use
docker buildx inspect --bootstrap
```

#### To Test If Docker Setup Was Successful

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

Only one docker image QAIRT is build for device.

<div id="QAIRT_Image">

### QAIRT Image
1. The multi-stage build approach in Docker helps create smaller, more efficient docker image by separating the build environment from the final runtime environment in separate images. After build is done in the builder image, only the necessary files are copied to the final image and the builder image is discarded.
2. To make use of multi-stage build approach, build a QAIRT_builder image first, download QAIRT SDK..
3. Python builder image is used to get the required python 3.12 libs and bins.
4. Now for the final image QAIRT, start from specified base image.
5. Add required libs and tools for simplified usage of Qualcomm hardware accelerators.
6. Install required Python packages in the default virtual environment.
7. Copy the SDK, model files and python wrappers from the builder image to final image.

<div id="Helper_Scripts_And_Configuration">

## Helper Scripts And Configuration
Directory /targets contains config.json and dev_config.json.
1. config.json contains fields required to build, update and run QAIRT container from host to the device.

<div id="How_to_fill_out_Configuration_JSON_File">

### How to fill out Configuration JSON File

The json file must contain certain data :

 1. ***MANDATORY*** - **QAIRT_version** - SDK Version for QAIRT to be downloaded and installed. Example Value `"v2.25.0.240728"`
 ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
 2. ***OPTIONAL*** - **Additional_tag_container** - Additional tag for container - allows for personalization of the names of the docker containers according to their purpose (to not set an additional tag just leave the value for this field empty)
 3. ***OPTIONAL*** - **Additional_tag_image** - Additional tag for docker image - allows for personalization of the names of the docker images according to their purpose (to not set an additional tag just leave the value for this field empty)
 4. ***MANDATORY*** - **URL** - Remote destination To be able to sync to this destination folder
 5.  ***MANDATORY*** -  **DeviceID** - adb devices command ID of the device.

The json files must be created in the ```targets/``` directory. Example json files for each supported combination are located in ```targets/``` directory.

***Once you have created the configuration file in ```targets/```, the image can be built***

The functions in ```/scripts/docker_env_setup.sh``` provide the necessary docker build, load, and run commands. All of these receive the path to the configuration json file as their first and only argument, as shown in the examples below

<div id="Docker_Host_Side_Helper_Scripts">

### Docker Host Side Helper Scripts

These functions are for building and maintaining docker images and containers.

***In order for the functions inside docker_env_setup.sh to work on the host, the script must be sourced***

```bash
source scripts/docker_env_setup.sh
```

The developer generally needs to build the image, load the image to the device and run the container.

- qairt-docker-build-image <path-to-config-json> - Build docker image based on Dockerfile
- qairt-docker-device-update-image <path-to-config-json> - Updates the device images to the device
- qairt-docker-device-save-image <path-to-config-json> - Saves the device images and sends to the remote
- qairt-docker-device-load-image <path-to-config-json> - Takes the .tar file from remote and loads device image on the device
- qairt-docker-device-run-container <path-to-config-json> - Run device container

<div id="Dev_Host_Side_Helper_Scripts">

### Development Host Side Python Binding Scripts

These functions are used for providing python wrapper scripts to QAIRT tools.

### How to fill out Dev Configuration JSON File

The dev config json file must contain certain data :

 1. ***OPTIONAL*** - **Additional_tag_container** - Additional tag for container - allows for personalization of the names of the docker containers according to their purpose (to not set an additional tag just leave the value for this field empty).
 2. ***OPTIONAL*** - **Additional_tag_image** - Additional tag for docker image - allows for personalization of the names of the docker images according to their purpose (to not set an additional tag just leave the value for this field empty).
 3. ***MANDATORY*** -  **DeviceID** - adb devices command ID of the device.
 4. ***MANDATORY for python wrapper*** -  **Backend** - Can be gpu, dsp or cpu.
 5. ***MANDATORY for python wrapper*** -  **Model** - DLC container model to be used.
 6. ***MANDATORY for python wrapper*** -  **Buffer** - User buffer type, must be one of the following USERBUFFER_TF8, USERBUFFER_TF16 ( for DSP runtime ) or USERBUFFER_FLOAT (for GPU runtime).
 7. ***MANDATORY for python wrapper*** -  **TestExamplesDirectory** - Path to the directory where the input raw images and input.txt is located. (directory path in the host)
 8. ***MANDATORY for python wrapper*** -  **TestOutputDirectoryName** - Name to the directory where the output files will be saved. (directory path in the container)

The dev json file must be created in the ```targets/``` directory, sample file is provided.

***In order for the functions inside dev_env_setup.sh to work on the host, the script must be sourced***

```bash
source scripts/dev_env_setup.sh
```

The developer generally needs to sync updated python scripts to the docker container inside the device and run the test app.

- qairt-sync-python-wrapper <path/to/targets/dev_config.json> - Sync Python wrapper src and test examples to the container
- qairt-run-python-wrapper <path/to/targets/dev_config.json> - Run Python wrapper script on the container

<div id="Development_Workflow">

## Development Workflow

<div id="Continuous_Development">

### Continuous Development

#### Compiling Device Docker Image

```bash
qairt-docker-build-image <path-to-config-json>
```

#### Update Compiled Image To The Locally Connected Device

```bash
qairt-docker-device-update-image <path-to-config-json>
```

#### Save Compiled Docker Image To Remote URL

```bash
qairt-docker-device-save-image <path-to-config-json>
```

#### Load Saved Docker Image From Remote URL To Locally Connected Device

```bash
qairt-docker-device-load-image <path-to-config-json>
```

#### Run Device Container

```bash
qairt-docker-device-run-container <path-to-config-json>
```

<div id="Examples_For_Development">

## Examples For Development

#### Continuous Development

Build docker image and save the docker image to file on build machine

```bash
# Build machine
###############
# Build docker image
qairt-docker-build-image <path-to-config-json>
# Save docker image to url
qairt-docker-device-save-image <path-to-config-json>
```

Load docker image and run the container on remote machine with device connected to it

***NOTE: Ensure proper CDI json, which contains all of the needed platform mountings for the specific platform, is copied to /etc/cdi in device storage, before running the QAIRT container. CDI json for the specific hardware and platform is located in qairt-container/cdi/\<hardware\>_\<platform\>_qiart.json***

For example, if working on qcs6490 hardware target with QLI 2.X platform, the correct CDI json would be qairt-container/cdi/qcs6490_qli_1x_qairt.json

```bash
### push corresponding CDI json to the device
adb push qairt-container/cdi/qcs6490_qli_2x_qairt.json /etc/cdi/
```

```bash
# Remote machine with device connected to it
############################################
# Load docker image from url
qairt-docker-device-load-image <path-to-config-json>
# Run device container
qairt-docker-device-run-container <path-to-config-json>
```


#### Continuous Development

Build docker image, update image to the device, run device container

```bash
# Build docker image
qairt-docker-build-image <path-to-config-json>
# Update docker image on the device
qairt-docker-device-update-image <path-to-config-json>
# Run device container
qairt-docker-device-run-container <path-to-config-json>
```

<div id="Developing_Python_Scripts">

### Developing Python Binding Scripts

- Scenario is:
  - Locally connected device
  - Device with disabled verity
  - Need to do python scripts development

#### Initial Setup

Prepare the environment, build image, update it to device and run the container

```bash
# Build docker image
qairt-docker-build-image <path-to-config-json>
# Update docker image on the device
qairt-docker-device-update-image <path-to-config-json>
# Run device container
qairt-docker-device-run-container <path-to-config-json>
```

#### Continuous Development

Sync python wrapper script, load script to the container, run the test app

```bash
# Sync Python wrapper src and test examples to the container
qairt-sync-python-wrapper <path/to/targets/dev_config.json>
# Run Python wrapper script on the container
qairt-run-python-wrapper <path/to/targets/dev_config.json>
```
