# QNN Docker

This project builds/Deploy the Qualcomm Nueral Network library for K2L which run **Linux Embedded** on **Arm64**.
The docker build can generate :
Deploy folders which can be synced with the final container image. This functionality is working for **Linux Embedded** targets from host file system and from docker image container.

## Table of Contents

* [Prerequisites](#Prerequisites)
  * [Ubuntu Version](#Ubuntu_Version)
  * [Ubuntu Packages](#Ubuntu_Packages)
  * [How to increase Max user watches and max user instances on host system](#Max_user_watches)
  * [Add internal docker registry mirror. (optional)](#Add_internal_docker_registry_mirror)
  * [Docker Must Be Configured On The Host System (one time)](#Docker_Host_System)
* [Docker Images](#Docker_Images)
  * [qnn-tools-builder](#qnn-tools-builder)
  * [qnn-tools-image](#qnn-tools-image)
* [Host Side Helper Scripts And Configuration](#Host_Side_Helper_Scripts_And_Configuration)
  * [How to fill out Configuration JSON File](#How_to_fill_out_Configuration_JSON_File)
  * [Host Side Helper Scripts](#Host_Side_Helper_Scripts)
  * [Helper Scripts Inside The Container](#Helper_Scripts_Inside_The_Container)
* [Development Workflow](#Development_Workflow)
  * [Initial One Time Setup](#Initial_One_Time_Setup)
  * [Continuous Development After Initial Setup](#Continuous_Development_After_Initial_Setup)
* [Examples For Development](#Examples_For_Development)
  * [QNN Applications](#QNN_Applications)

<div id="Prerequisites">

## Prerequisites

<div id="Ubuntu_Version">

### Ubuntu Version

Ubuntu 18.04 or Ubuntu 20.04 or Ubuntu 22.04 is required

<div id="Ubuntu_Packages">

### Ubuntu Packages

jq must be installed on the host (one time)

```bash
sudo apt install -y jq
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

<div id="qnn_builder">
### qnn_builder:
    1. Clone QNN libs from host
    2. Put artifacts into Deploy directories

<div id="qnn">
### qnn:
    1. Install additional developer tools
    2. Copy qnn artifacts from builder

<div id="Host_Side_Helper_Scripts_And_Configuration">

## Host Side Helper Scripts And Configuration

<div id="How_to_fill_out_Configuration_JSON_File">

### How to fill out Configuration JSON File

The json file must contain certain data :
 1. ***MANDATORY*** - **Qnn_Version** - SDK Version for QNP to be downloaded and installed. Example Value `"v2.25.0.240728"`
 2. ***MANDATORY*** - **Base_Image** - Base docker image to be used on the device. By default, it's ubuntu:24.04
 3. ***MANDATORY*** -  **Target_platform** - Target device platform, which can be kalama, qcs6490, qrb5165, etc.
 4. ***OPTIONAL*** - **Additional_tag** - Additional tag to be appended to the name of the container and image - allows for personalization of the names of the docker containers according to their purpose (to not set an additional tag just leave the value for this field empty)
 5. ***MANDATORY*** - **URL** - Remote destination to be able to sync image tar to this destination folder
 6. ***MANDATORY*** -  **DeviceID** - adb devices command ID of the device.

The json files must be created in the ```targets/``` directory. Example json files for each supported combination are located in ```targets/``` directory.

***Once you have created the configuration file in ```targets/```, the image can be built***

The functions in ```\/scripts/host/docker_env_setup.sh``` provide the necessary build, run, start, stop and remove commands. All of them receive the path to the configuration json file as their first and only argument, as shown in the examples bellow

<div id="Host_Side_Helper_Scripts">

### Host Side Helper Scripts

***In order for the functions inside docker_env_setup.sh to work on the host, the script must be sourced***

```bash
source scripts/host/docker_env_setup.sh
```


qnn-device-prepare <Device-ID (optional argument)>
    Prepare device after reboot
qnn-tools-build-image <targets/.json>
    Build qnn-tools docker image on host
qnn-tools-device-run-container <targets/.json>
    Run qnn container on device
qnn-tools-device-start-container <targets/.json>
    Once image is loaded, start the container
qnn-tools-save-image <targets/.json>
    Save selected docker image on host
qnn-tools-device-load-image <targets/.json>
    Load selected docker image image on device
qnn-tools-device-rm-container <targets/.json>
    Remove the container from device
qnn-tools-device-stop-container <targets/.json>
    Stop the container on device
qnn-tools-device-images-cleanup <targets/.json>
    Remove docker images from device


The developer generally needs to build the image, load the image to the device and run the container.

- qnn-tools-build-image <path-to-config-json> - Build docker image based on Dockerfile
- qnn-tools-device-run-container <path-to-config-json> - Run loaded qnn-tools  image
- qnn-device-prepare <Optional Device Id> - Prepare device after reboot
- qnn-tools-save-image <path-to-config-json> - Saves the device images
- qnn-tools-device-load-image <path-to-config-json> - Takes the .tar file from host and loads device image on the device
- qnn-tools-device-rm-container <path-to-config-json> - Remove device container
- qnn-tools-device-start-container <path-to-config-json> - Start device container
- qnn-tools-device-stop-container <path-to-config-json> - Stop device container
- qnn-tools-device-images-cleanup <path-to-config-json> - Docker device images clean up


<div id="Development_Workflow">

## Development Workflow

<div id="Initial_One_Time_Setup">

### Initial One Time Setup
#### Prepare Device Connected To Local PC After Image Or Metabuild Flash

***Please note that this step MUST be invoked only once after device, connected to local PC, is flashed with new images or metabuild***

***Please note that adb is single instance. All adb servers in other containers or host OS MUST be killed***

```bash
qnn-device-prepare
adb disable-verity
adb reboot
```

#### Prepare Device After Reboot

***Please note that this step needs to be invoked only once after device, connected to local PC, is started***

```bash
qnn-device-prepare
```

<div id="Continuous_Development_After_Initial_Setup">

### Continuous Development After Initial Setup

#### Compiling Device Docker Image

```bash
qnn-tools-build-image <path-to-config-json>
```
#### Save Compiled Docker Image To Remote URL

```bash
qnn-tools-save-image <path-to-config-json>
```

#### Load Saved Docker Image From Remote URL To Locally Connected Device

```bash
qnn-tools-device-load-image <path-to-config-json>
```

#### Run Device Container

```bash
qnn-tools-device-run-container <path-to-config-json>
```


<div id="QNN_Applications">

### QNN Applications

push RAW files to device
```bash
adb push <RAW Files collectio> /tmp
```

prepare input_list.txt with absolute path of RAW files
push input_list.txt to device
```bash
adb push <input_list> /tmp
```

push qnn models as per QNN version
```bash
adb push <QNN model> /tmp
```

copy RAW files from device to container
```bash
docker cp  /tmp/<QNN model>:<Container_id>:/tmp
docker cp  /tmp/<RAW Files collectio>:<Container_id>:/tmp
docker cp  /tmp/<input_list>:<Container_id>:/tmp
```

go to containr shell
```bash
docker exec -it <CONTAINER_NAME> /bin/bash
```

#### Example: Inside container
```bash
qnn-net-run --model=/tmp/<QNN model> --backend=/usr/lib/libQnnCpu.so --input_list=/tmp/<input_list>
```
```bash
qnn-net-run --model=/tmp/<QNN model> --backend=/usr/lib/libQnnHtp.so --input_list=/tmp/<input_list>
```
```bash
qnn-net-run --model=/tmp/<QNN model> --backend=/usr/lib/libQnnGpu.so --input_list=/tmp/<input_list>
```
