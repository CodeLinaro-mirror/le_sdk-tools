# Qualcomm Machine Learning

This project provides tools for simplified access to Qualcomm hardware accelerators for Machine Learning
The docker build generates device image on host files system. The device image can be easily loaded and started on the device

## Table of Contents

* [Prerequisites](#Prerequisites)
  * [Ubuntu Version](#Ubuntu_Version)
  * [Ubuntu Packages](#Ubuntu_Packages)
  * [How to increase Max user watches and max user instances on host system](#Max_user_watches)
  * [Add internal docker registry mirror. (optional)](#Add_internal_docker_registry_mirror)
  * [Docker Must Be Configured On The Host System (one time)](#Docker_Host_System)
* [Docker Images](#Docker_Images)
  * [QML Image](#QML_Image)
* [Host Side Helper Scripts And Configuration](#Host_Side_Helper_Scripts_And_Configuration)
  * [How to fill out Configuration JSON File](#How_to_fill_out_Configuration_JSON_File)
  * [Docker Host Side Helper Scripts](#Docker_Host_Side_Helper_Scripts)
* [Development Workflow](#Development_Workflow)
  * [Initial One Time Setup](#Initial_One_Time_Setup)
  * [Continuous Development After Initial Setup](#Continuous_Development_After_Initial_Setup)
* [Examples For Development](#Examples_For_Development)
  * [Remote Device With Disabled Verity](#Remote_Device_With_Disabled_Verity)
  * [Local Device With Verity Check](#Local_Device_With_Verity_Check)
  * [Device Docker Clean Up](#Device_Docker_Clean_Up)

<div id="Prerequisites">

## Prerequisites

<div id="Ubuntu_Version">

### Ubuntu Version

Ubuntu 18.04 or Ubuntu 20.04 or Ubuntu 22.04 is required for host file system

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

Only one docker image QML is build for device

<div id="QML_Image">

### QML Image
1. Start from specified base image
2. Add required libs and tools for simplified usage of Qualcomm hardware accelerators

<div id="Host_Side_Helper_Scripts_And_Configuration">

## Host Side Helper Scripts And Configuration

<div id="How_to_fill_out_Configuration_JSON_File">

### How to fill out Configuration JSON File

The json file must contain certain data :

 1. ***MANDATORY*** - **Acceleration_engines** - An array of Acceleration engines to be used in QML environment. If not needed, leave as is in the example config json. ***Every Acceleration engine from the array must contain:***
    * 1.1. ***MANDATORY*** - **Acceleration_engine** - Acceleration engine to be used. If not needed, leave this field and the "Acceleration_engine_path" field with "-" value
    * 1.2. ***MANDATORY*** - **Acceleration_engine_version** - SDK Version for Acceleration engine. Example Value `"v2.22.0.240425"`
 2. ***MANDATORY*** - **Base_Image** - Base docker image to be used on the device
 ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
 3. ***MANDATORY*** - **Target_platform** - Target device platform, which can be kalama or qcs6490 or qrb5165 or qcm6490
 4. ***OPTIONAL*** - **Additional_tag_container** - Additional tag for container - allows for personalization of the names of the docker containers according to their purpose (to not set an additional tag just leave the value for this field empty)
 5. ***OPTIONAL*** - **Additional_tag_image** - Additional tag for docker image - allows for personalization of the names of the docker images according to their purpose (to not set an additional tag just leave the value for this field empty)
 6. ***MANDATORY*** - **URL** - Remote destination To be able to sync to this destination folder
 7.  ***MANDATORY*** -  **DeviceID** - adb devices command ID of the device.

The json files must be created in the ```targets/``` directory. Example json files for each supported combination are located in ```targets/``` directory.

***Once you have created the configuration file in ```targets/```, the image can be built***

The functions in ```/scripts/docker_env_setup.sh``` provide the necessary build, load, run, start, stop and remove commands. All of them receive the path to the configuration json file as their first and only argument, as shown in the examples below

<div id="Docker_Host_Side_Helper_Scripts">

### Docker Host Side Helper Scripts

These functions are for building and maintaining docker images and containers.

***In order for the functions inside docker_env_setup.sh to work on the host, the script must be sourced***

```bash
source scripts/host/docker_env_setup.sh
```

The developer generally needs to build the image, load the image to the device and run the container.

- qml-docker-build-image <path-to-config-json> - Build docker image based on Dockerfile
- qml-docker-device-update-image - Updates the device images to the device
- qml-docker-device-run-container - Run device container

<div id="Development_Workflow">

## Development Workflow

<div id="Initial_One_Time_Setup">

### Initial One Time Setup

#### Prepare Device Connected To Local PC After Image Or Metabuild Flash

***Please note that this step MUST be invoked only once after device, connected to local PC, is flashed with new images or metabuild***

***Please note that adb is single instance. All adb servers in other containers or host OS MUST be killed***

```bash
qml-device-prepare
adb disable-verity
adb reboot
```

#### Prepare Device After Reboot

***Please note that this step needs to be invoked only once after device, connected to local PC, is started***

```bash
qml-device-prepare
```

<div id="Continuous_Development_After_Initial_Setup">

### Continuous Development After Initial Setup

#### Compiling Device Docker Image

```bash
qml-docker-build-image <path-to-config-json>
```

#### Update Compiled Image To The Locally Connected Device

```bash
qml-docker-device-update-image <path-to-config-json>
```

#### Run Device Container

```bash
qml-docker-device-run-container <path-to-config-json>
```

<div id="Examples_For_Development">

## Examples For Development

<div id="Remote_Device_With_Disabled_Verity">

### Remote Device With Disabled Verity

- Scenario is:
  - Device connected to remote machine
  - Device with disabled verity
  - Incremental Build


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
qml-device-prepare
adb disable-verity
adb reboot
# Prepare Device For Work
qml-device-prepare
```

#### **Continuous Development**

Build docker image, update image to the device, run device container

```bash
# Build docker image
qml-docker-build-image <path-to-config-json>
# Update docker image on the device
qml-docker-device-update-image <path-to-config-json>
# Run device container
qml-docker-device-run-container <path-to-config-json>
```

<div id="Device_Docker_Clean_Up">

### Device Docker Clean Up

- Scenario is:
  - Device storage is full and docker image clean up is required
