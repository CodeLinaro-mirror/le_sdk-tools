# IM SDK Docker

## Table of Contents

* [Prerequisites](#Prerequisites)
  * [Ubuntu Version](#Ubuntu_Version)
  * [Ubuntu Packages](#Ubuntu_Packages)
  * [How to increase Max user watches and max user instances on host system](#Max_user_watches_and_max_user_instances_must_be_increased_on_the_host_system)
  * [Add internal docker registry mirror. (optional)](#Add_internal_docker_registry_mirror)
  * [Docker Must Be Configured On The Host System (one time)](#Docker_Must_Be_Configured_On_The_Host_System_(one_time))
* [About the QIMSDK Docker Image](#About_the_QIMSDK_Docker_Image)
  * [Stage 0 - Base Image](#Stage_0_-_Base_Image)
  * [Stage 1 - QIMSDK Image](#Stage_1_-_QIMSDK_Image)
* [Host Side Helper Scripts And Configuration](#Host_Side_Helper_Scripts_And_Configuration)
  * [How to fill out Configuration JSON File](#Every_Docker_Container_Is_Configured_With_The_Help_Of_A_Configuration_JSON_File)
  * [Host Side Helper Scripts](#Host_Side_Helper_Scripts)
* [Local Sync Scripts](#Local_Sync_Scripts)
  * [Linux](#Linux)
  * [Windows](#Windows)
* [Development Workflow](#Development_Workflow)
  * [Initial One Time Setup](#Initial_One_Time_Setup)
  * [Continuous Development After Initial Setup](#Continuous_Development_After_Initial_Setup)
  * [Extracting gstreamer headers and dev packages](#Extracting_gstreamer_headers_and_dev_packages)
* [Examples For Development](#Examples_For_Development)
  * [Modifications In OMX Gst Plugin (remote src)](#Modifications_In_OMX_Gst_Plugin_(remote_src))
  * [Modifications In QMMF Gst Plugin (local src)](#Modifications_In_QMMF_Gst_Plugin_(local_src))
  * [Modifications in QMMF SDK](#Modifications_in_QMMF_SDK)
  * [Modifications in Weston](#Modifications_in_Weston)
* [Compiling gst-plugins-qti-oss Against tflite-dev.tar.gz](#Compiling_gst-plugins-qti-oss_Against_tflite-dev.tar.gz)

<div id="Prerequisites">

## Prerequisites

<div id="Ubuntu_Version">

### Ubuntu Version

Ubuntu 18.04 or Ubuntu 20.04 is required

<div id="Ubuntu_Packages">

### Ubuntu Packages

jq must be installed on the host (one time)

```bash
sudo apt install -y jq
```

<div id="Max_user_watches_and_max_user_instances_must_be_increased_on_the_host_system">

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

<div id="Docker_Must_Be_Configured_On_The_Host_System_(one_time)">

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

If trying to run qimsdk-docker-build-image results in ```No space left on device```, this can be fixed by moving docker directory to ```/local/mnt```

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

<div id="About_the_QIMSDK_Docker_Image">

## About the QIMSDK Docker Image

The docker image is built using the Dockerfile found at the top of this repository.

<div id="Stage_0_-_Base_Image">

### Stage 0 - Base Image

Two images are generated in stage 0. The base image for ubuntu 18 and base image for ubuntu 20.

A. Ubuntu 18 Base Image

1. Set ubuntu 18 alternatives priority for python

B. Ubuntu 20 Base Image

1. Set ubuntu 20 alternatives priority for python

<div id="Stage_1_-_QIMSDK_Image">

### Stage 1 - QIMSDK Image

Depending on the selected Image OS, the QIMSDK Docker Image is based either on the Ubuntu 18 base image, or the Ubuntu 20 base image.

A. QIMSDK Image

1. Install needed ubuntu packets
2. Install additional dependencies
3. Set python alternatives, max user watches, etc. inside QIMSDK Docker
4. Propagate user and group from host machine
5. Set base and esdk directories
6. Add all other optional environment variables to be used inside the container
7. Setup eSDK as HOST user
8. Propagate needed scripts, urls, patches to the container
9. Sync the code, compile modified layers and package compiled recipes

<div id="Host_Side_Helper_Scripts_And_Configuration">

## Host Side Helper Scripts And Configuration

<div id="Every_Docker_Container_Is_Configured_With_The_Help_Of_A_Configuration_JSON_File">

### Every Docker Container Is Configured With The Help Of A Configuration JSON File

The json file must contain certain data :

* 1. ***MANDATORY*** - **Image_OS** - Available options are "ubuntu18" and "ubuntu20" - The linux distribution that will run inside the docker container
* 2. ***OPTIONAL*** - **Additional_tag** - Additional tag to be appended to the name of the container - allows for personalization of the names of the docker containers according to their purpose (to not set an additional tag just leave the value for this field empty)
* 3. ***MANDATORY*** - **eSDK_path** - Path to the directory in the work environment that contains the eSDK .sh and json file generated after eSDK compilation (refer to steps above) ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 4. ***MANDATORY*** - **eSDK_shell_file** - name of the shell file inside eSDK directory
* 5. ***OPTIONAL*** - **Tflite_path** - Path to the directory where the prebuild tflite dev archive is located ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 6. ***OPTIONAL*** - **Tflite_prebuilt_file** - name of the prebuilt archive
* 7. ***OPTIONAL*** - **Acceleration_engines** - An array of Acceleration engines to be used in QIMSDK environment. If not needed, leave as is in the example config json. ***Every Acceleration engine from the array must contain:***
  * 7.1. ***OPTIONAL*** - **Acceleration_engine** - Acceleration engine to be used. If not needed, leave this field and the "Acceleration_engine_path" field with "-" value
  * 7.2. ***OPTIONAL*** - **Acceleration_engine_path** - path to unzipped acceleration engine archive directory with unzipped files for the AI engine specified in the "Acceleration_engine" field ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 8. ***OPTIONAL*** - **Host_dir_mounted_in_container** - A work environment directory to be exported inside the docker container (if mounting a directory is not necessary, just leave the value for this field empty)
* 9. ***OPTIONAL*** - **Deploy_URL** - This enables sending ipk packages built inside docker container to remote target or local filesystem folder specified in **Host_dir_mounted_in_container**, which is mounted to `~/work` inside container. Scripts are available to send ipk packages to the remote path specified in this field (if sending them to a remote target is not necessary, just leave the value for this field empty) ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 10. ***OPTIONAL*** - **Deploy_dev_URL** - This enables sending dev packages built inside docker container to remote target or local filesystem folder specified in **Host_dir_mounted_in_container**, which is mounted to `~/work` inside container. Scripts are available to send dev packages to the remote path specified in this field (if sending them to a remote target is not necessary, just leave the value for this field empty) ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 11. ***OPTIONAL*** - **Deploy_QIMSDK_Artifacts_URL** - This enables sending ipk packages built inside docker container to local filesystem folder. QIMSDK artifacts will be sent to the directory specified in this json field. (if QIMSDK artifacts are not needed on host machine, just leave the value for this field empty) ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 12. ***OPTIONAL*** - **Deploy_QIMSDK_Artifacts_URL_rel** - This enables sending release ipk packages built inside docker container to local filesystem folder. QIMSDK artifacts will be sent to the directory specified in this json field. (if QIMSDK artifacts are not needed on host machine, just leave the value for this field empty) ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 13. ***OPTIONAL*** - **Deploy_QIMSDK_Artifacts_URL_dev** - This enables sending development ipk packages built inside docker container to local filesystem folder. QIMSDK artifacts will be sent to the directory specified in this json field. (if QIMSDK artifacts are not needed on host machine, just leave the value for this field empty) ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 14. ***OPTIONAL*** - **Gst_plugins_qti_oss_dependencies** - List of the dependency packages that will be compiled and installed to the target device.

The json files must be created in the ```<snapdragon-iot-qimsdk>/sdk-tools/targets/``` directory. ```<snapdragon-iot-qimsdk>/sdk-tools/targets/LE.UM.6.4.2.json``` can be used as an example.

***Once you have created the configuration file in ```<snapdragon-iot-qimsdk>/sdk-tools/targets/```, the image can be built***

The functions in ```<snapdragon-iot-qimsdk>/sdk-tools/scripts/host/env_setup.sh``` provide the necessary build, run, start, stop and remove commands. All of them receive the path to the configuration json file as their first and only argument, as shown in the examples bellow:

<div id="Host_Side_Helper_Scripts">

### Host Side Helper Scripts

***In order for the functions inside env_setup.sh to work on the host, the script must be sourced***

```bash
source <snapdragon-iot-qimsdk>/sdk-tools/scripts/host/env_setup.sh
```

The developer generally needs to build the image and run the container.

- ```qimsdk-docker-build-image ./targets/<config.json>``` - This function propagates the user and the group and builds the docker image, using the data from the configuration json file. During docker image build, it prepares, builds, and packages esdk gstreamer code.
- ```qimsdk-docker-run-container ./targets/<config.json>``` - This function runs a container, where:
  - If an additional tag is provided in the json, it appends it to the name of the container
  - If a directory to mount is provided in the json, it mounts it in the container
  - If docker run is successful, it checks if the `~/.ssh/` directory exists and propagates it through to the container. It does the same with the `~/.gitconfig` and `/etc/gitconfig` files. If it cannot find them, it simply continues on, it does not return an error. IMPORTANT! Please do not share container image with anyone and do not upload it to a container registry to avoid exposing all private ssh keys with it.
- ```qimsdk-docker-rm-container ./targets/<config.json>``` - This function removes the container with the tag and additional tag provided by the json.
- ```qimsdk-docker-start-container ./targets/<config.json>``` - This function starts the container with the tag and additional tag provided by the json.
- ```qimsdk-docker-stop-container ./targets/<config.json>``` - This function stops the container with the tag and additional tag provided by the json.
- ```qimsdk-docker-build-and-sync-artifacts-all ./targets/<config.json>``` - This is a wrapper function to build docker image and extract QIMSDK Artifacts to user specified directory in host machine. Directory to sync artifacts to is selected via the "Deploy_QIMSDK_Artifacts_URL" field in the configuration json.
- ```qimsdk-docker-build-and-sync-artifacts-rel ./targets/<config.json>``` - This is a wrapper function to build docker image and extract QIMSDK Release Artifacts to user specified directory in host machine. Directory to sync artifacts to is selected via the "Deploy_QIMSDK_Artifacts_URL_rel" field in the configuration json.
- ```qimsdk-docker-build-and-sync-artifacts-dev ./targets/<config.json>``` - This is a wrapper function to build docker image and extract QIMSDK Development Artifacts to user specified directory in host machine. Directory to sync artifacts to is selected via the "Deploy_QIMSDK_Artifacts_URL_dev" field in the configuration json.

Next step is to attach to the container and work with helper scripts inside the container. Container name is printed in the end of *qimsdk-docker-run-container* function after following print *Please attach to docker container with name:*

- The "Docker" extension for Visual Studio Code provides the functionality to attach Visual Studio Code to docker containers
  - Click the "Docker" icon on the Primary Side bar to open the "Docker" extension
  - Right-click on the desired container to show all available commands (Start, Stop, Remove, Attach Shell, Attach Visual Studio Code, etc.)
- Or you can attach to the container command line using
  - ```docker attach <container name>```

<div id="Helper_Scripts_Inside_The_Container">

## Helper Scripts Inside The Container

```bash
source ${QIMSDK_BASE_DIR}/scripts/env_setup.sh
```

The functions inside env_setup.sh are propagated through to .bashrc, so they are immediately available inside the container

- ```qimsdk-layers-build``` - Must be invoked to compile modified layers in the container
- ```qimsdk-layers-package``` - Must be invoked after invoking qimsdk-layers-build to package compiled recipes in the container
- ```qimsdk-device-prepare``` - Must be invoked to prepare device for package sync
- ```qimsdk-device-sync-rel``` -Must be invoked to sync release packages with the device
- ```qimsdk-device-sync-dbg``` - Must be invoked to sync debug packages with the device
- ```qimsdk-device-packages-remove``` - Must be invoked to remove installed packages from the device
- ```qimsdk-remote-sync-rel``` - Must be invoked to sync release packages with the remote target
- ```qimsdk-remote-sync-dbg``` - Must be invoked to sync debug packages with the remote target
- ```qimsdk-remote-sync-dev``` - Must be invoked to sync dev packages with the remote target
- ```qimsdk-remote-sync-staticdev``` - Must be invoked to sync staticdev packages with the remote target
- ```qimsdk-remote-packages-remove``` - Must be invoked to remove packages, installed by the remote target script
- ```qimsdk-target-sync-artifacts-all``` - Must be invoked to generate QIMSDK artifacts archive and sync it to */mnt/qimsdk/work/artifacts* directory inside container
- ```qimsdk-target-sync-artifacts-rel``` - Must be invoked to generate QIMSDK release artifacts archive and sync it to */mnt/qimsdk/work/artifacts* directory inside container
- ```qimsdk-target-sync-artifacts-dev``` - Must be invoked to generate QIMSDK development artifacts archive and sync it to */mnt/qimsdk/work/artifacts* directory inside container

***Please note that package remove script file must be invoked on the host computer***

***Please note that script file extension must be renamed to bat when remote OS is windows***

<div id="Local_Sync_Scripts">

## Local Sync Scripts

If ipk files needs to be deployed to device connected to another pc, then ipk files can be copied to that pc with *qimsdk-remote-sync-rel* or *qimsdk-remote-sync-dbg* scripts. Depending whether Linux or Windows is used on the pc (where device is connected) can be used corresponding scripts to update ipk's to the device. Those scripts also needs to be copied to the pc (where device is connected).

***Please note that these scripts are deleting all successfully installed ipk files from the folder on pc (where device is connected)***

***Please note that device needs to be prepared (disable verify, root, remount, file system remount as rw) for update before invoking these scripts***

***Please note that adb needs to be available in the path variable for windows and linux***

<div id="Linux">

### Linux

Script location: \<snapdragon-iot-qimsdk\>/sdk-tools/scripts/local/linux.sh
Sync cmd: qimsdk-local-sync - Sync packages with the device from specified folder

```bash
source <snapdragon-iot-qimsdk>/sdk-tools/scripts/local/linux.sh
qimsdk-local-sync <folder to sync>
```

<div id="Windows">

### Windows

Example for adding adb to powershell path

```powershell
$Env:PATH += ";<path to adb>"
```

Script location: \<snapdragon-iot-qimsdk\>/sdk-tools/scripts/local/win.ps1
Sync cmd: qimsdk-local-sync - Sync packages with the device from specified folder

```powershell
.\<snapdragon-iot-qimsdk>\sdk-tools\scripts\local\win.ps1
qimsdk-local-sync <folder to sync>
```

<div id="Development_Workflow">

## Development Workflow

<div id="Initial_One_Time_Setup">

### Initial One Time Setup

#### Password Protected SSH Key

***Please note that this step needs to be invoked only once after container is started***

If use of password protected ssh key is needed, ssh agent needs to be used:

```bash
ssh-agent -s > ~/work/.ssh_agent.info
. ~/work/.ssh_agent.info
ssh-add ~/.ssh/<private-ssh-key-name>
```

#### Fetch Code For eSDK Recipe Not Included In QIMSDK

***Please note that this step needs to be invoked only once after container is started***

***Please note that for some recipes it is much faster to do the modifications inside yocto and generate new esdk***

- In case recipe fetches the code from internet, no need to clone src code.
- In case recipe fetches the code from local drive, code needs to be cloned in ```${QIMSDK_ESDK_BASE_DIR}/src/<path to src code>```
- In case recipe depends on other recipes, their src code also needs to be fetched in ```${QIMSDK_ESDK_BASE_DIR}/src/<path to src code>```

#### Modify eSDK Recipe Not Included In QIMSDK

***Please note that this step needs to be invoked only once after container is started***

Before making any modification to the source code devtool needs to know that code will be modified

```bash
devtool modify <recipe>
```

#### Prepare Device Connected To Local PC After Image Or Metabuild Flash

***Please note that this step MUST be invoked only once after device, connected to local PC, is flashed with new images or metabuild***

***Please note that adb is single instance. All adb servers in other containers or host OS MUST be killed***

```bash
qimsdk-device-prepare
adb disable-verity
adb reboot
```

#### Prepare Device Connected To Local PC

***Please note that this step needs to be invoked only once after device, connected to local PC, is started***

***Please note that this step needs to be invoked only once after container is started***

***Please note that adb is single instance. All adb servers in other containers or host OS MUST be killed***

```bash
qimsdk-device-prepare
```

<div id="Continuous_Development_After_Initial_Setup">

### Continuous Development After Initial Setup

#### Source Code Location For Recipes With Local Fetch

```bash
ls -la ${QIMSDK_ESDK_BASE_DIR}/src/<path to src code>
```

#### Source Code Location For Recipes With Remote Fetch

```bash
ls -la ${QIMSDK_ESDK_BASE_DIR}/workspace/sources/<recipe name>
```

#### Do Your Modifications And Src Code Development

```bash
<editor> <filename>
```

#### Compiling QIMSDK recipe

To build all QIMSDK layers after each src code change of recipes to be built inside sdk.

***Please note that this function invokes build functions of all layers. So this is equivalent of "build all" for entire code inside sdk***

```bash
qimsdk-layers-build
```

In case only single layer needs to be build, corresponding function needs to be invoked. For example

```bash
qimsdk-gst-plugins-qti-build
```

#### Packaging QIMSDK recipe

To package all QIMSDK layers after each recipe build inside sdk.

***Please note that this function invokes package functions of all layers. So this is equivalent of "package all" for entire code inside sdk***

```bash
qimsdk-layers-package
```

In case only single layer needs to be packaged, corresponding function needs to be invoked. For example

```bash
qimsdk-gst-plugins-qti-package
```

#### Compiling Prepared eSDK Recipe Not Included In QIMSDK

Devtool compiles recipe with

```bash
devtool build <recipe>
```

#### Packaging Compiled eSDK Recipe Not Included In QIMSDK

Devtool creates recipe packages with

```bash
devtool package <recipe>
```

#### Syncing Packages To The Device

Device update with release variant

```bash
qimsdk-device-sync-rel
```

Or debug variant

```bash
qimsdk-device-sync-dbg
```

#### Syncing Packages To Remote PC

Remote PC update with release variant

```bash
qimsdk-remote-sync-rel
```

Or debug variant

```bash
qimsdk-remote-sync-dbg
```

#### Resetting Compiled Recipe

In case something is messed up with already prepared recipe, it can be reset. Please note that path to workspace folder must be deleted after invoking reset command. Exact path is logged on the screen in the last few lines of reset command output

```bash
devtool reset <recipe>
rm -rf <path to workspace folder>
```

#### Update All Packages Recipes To the Device Or Remote PC

In case something is messed up with packages to be updated, sync log can be reset. So all packages will be installed on the device or updated to the remote URL ot the nex sync command. Please note that there are separate sync log clear functions for local device *qimsdk-device-sync-log-clear* and for remote URL *qimsdk-remote-sync-log-clear*

Clear log and update device connected to local PC

```bash
qimsdk-device-sync-log-clear
qimsdk-device-sync-rel
```

Or, if the device is not attached to host PC

```bash
qimsdk-remote-sync-log-clear
qimsdk-remote-sync-rel
```

#### Remove All Packages from the Device Or Remote PC

In case device needs to be restored to previous state before any manipulation from qimsdk, all installed packages can be removed.

Remove packages from device connected to local PC

```bash
qimsdk-device-packages-remove
```

Or, if the device is not attached to host PC

```bash
qimsdk-remote-packages-remove
```

***Please note that package remove script file must be invoked on the host computer***

***Please note that script file extension must be renamed to bat when remote OS is windows***

<div id="Extracting_gstreamer_headers_and_dev_packages">

### Extracting gstreamer headers and dev packages

When trying to compile using gstreamer headers:

* Use the ***qimsdk-remote-sync-dev*** function to sync all dev packages containing the needed gstreamer headers to your remote target.
* For information on how to select the target URL, refer to [How to fill out Configuration JSON File](#Every_Docker_Container_Is_Configured_With_The_Help_Of_A_Configuration_JSON_File)

<div id="Examples_For_Development">

## Examples For Development

<div id="Modifications_In_OMX_Gst_Plugin_(remote_src)">

### Modifications In OMX Gst Plugin (remote src)

- Scenario is:
  - No ssh key password protection
  - Locally connected device
  - Device with disabled verity
  - Modifications in OMX gst plugin
  - Sync release package

#### Initial Setup

Prepare the environment

```bash
# Prepare OMX gst plugin
devtool modify gstreamer1.0-omx
# Prepare Device For Update
qimsdk-device-prepare
```

#### Continuous Development

Modify src code in

```bash
ls -la ${QIMSDK_ESDK_BASE_DIR}/workspace/sources/gstreamer1.0-omx
```

Build, package code and update the device with release variant

```bash
# Build, package code and update the device with release variant
devtool build gstreamer1.0-omx && devtool package gstreamer1.0-omx && qimsdk-device-sync-rel
```

<div id="Modifications_In_QMMF_Gst_Plugin_(local_src)">

### Modifications In QMMF Gst Plugin (local src)

- Scenario is:
  - No ssh key password protection
  - Locally connected device
  - Freshly flashed device with metabuild
  - Modifications in QMMF gst plugin
  - Sync release package

#### Initial Setup (for qmmf plugin)

Prepare the environment

```bash
# Prepare Device For Update After Meta Flashing
qimsdk-device-prepare
adb disable-verity
adb reboot
# Prepare Device For Update
qimsdk-device-prepare
```

#### Continuous Development (for qmmf plugin)

Modify src code in

```bash
ls -la ${QIMSDK_ESDK_BASE_DIR}/src/vendor/qcom/opensource/gst-plugins-qti-oss
```

Build, package code and update the device with release variant

```bash
# Build, package code and update the device with release variant
qimsdk-layers-build && qimsdk-layers-package && qimsdk-device-sync-rel
```

<div id="Modifications_in_QMMF_SDK">

### Modifications in QMMF SDK

QMMF SDK is one of the recipes where it is much faster to build it in Yocto and generate new esdk. The reason is that it depends on way too many recipes and for each one src code needs to be manually cloned. One of the dependencies is kernel. After it's compilation basically entire tree is rebuild.

<div id="Modifications_in_Weston">

### Modifications in Weston

- Scenario is:
  - Password protection ssh key
  - Remotely connected device to Windows
  - Modifications in weston dependency of gst plugins
  - Sync debug package

#### Initial Setup (for qmmf sdk)

Prepare the environment

```bash
# Start SSH Agent to Handle Password Protected SSH Key
ssh-agent -s > ~/work/.ssh_agent.info
. ~/work/.ssh_agent.info
ssh-add ~/.ssh/<private-ssh-key-name>
# Clone weston
git clone "<Sync_URL_Prefix>"/wayland/weston \
    ${QIMSDK_ESDK_BASE_DIR}/src/display/weston  \
    --branch=LE.UM.6.4.2 --single-branch
# Prepare weston
devtool modify weston
```

#### Continuous Development (for qmmf sdk)

Modify src code in

```bash
ls -la ${QIMSDK_ESDK_BASE_DIR}/src/display/weston
ls -la ${QIMSDK_ESDK_BASE_DIR}/src/vendor/qcom/opensource/qmmf-sdk
```

Build, package code and update the remote with debug variant

```bash
# Build, package code and update the device with debug variant
devtool build weston && devtool package weston                          && \
qimsdk-layers-build && qimsdk-layers-package && qimsdk-remote-sync-dbg
```

Update device ipk from remote Windows

```powershell
.\<snapdragon-iot-qimsdk>\sdk-tools\scripts\local\win.ps1
qimsdk-local-sync <folder to sync>
```

<div id="Compiling_gst-plugins-qti-oss_Against_tflite-dev.tar.gz">

## Compiling gst-plugins-qti-oss Against tflite-dev.tar.gz

tflite-dev.tar.gz can be generated in a separate container or Bazel environment. Path and name to that file needs to be specified in the JSON configuration file with tags **Tflite_path** (***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***) and **Tflite_prebuilt_file**
