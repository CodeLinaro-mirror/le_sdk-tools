# IM SDK Host

## Table of Contents

* [Prerequisites](#Prerequisites)
  * [Ubuntu Version](#Ubuntu_Version)
  * [Ubuntu Packages](#Ubuntu_Packages)
  * [How to increase Max user watches and max user instances on host system](#Max_user_watches)
* [Helper Scripts And Configuration](#Helper_Scripts_And_Configuration)
  * [How to fill out Configuration JSON File](#How_to_fill_out_Configuration_JSON_File)
  * [Helper Scripts](#Helper_Scripts)
* [Local Sync And Uninstall Scripts](#Local_Sync_And_Uninstall_Scripts)
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
* [Getting QIMSDK Artifacts from Host QIMSDK Environment](#Getting_QIMSDK_Artifacts_from_Host_QIMSDK_Environment)
* [Compiling gst-plugins-qti-oss Against tflite-dev.tar.gz](#Compiling_gst-plugins-qti-oss_Against_tflite-dev.tar.gz)
* [Adding One More Poky Layer In The QIMSDK](#Adding_One_More_Poky_Layer_In_The_QIMSDK)

<div id="Prerequisites">

## Prerequisites

<div id="Ubuntu_Version">

### Ubuntu Version

Ubuntu 18.04 is mandatory requirement

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

<div id="Helper_Scripts_And_Configuration">

## Helper Scripts And Configuration

<div id="How_to_fill_out_Configuration_JSON_File">

### How to fill out Configuration JSON File

The json file must contain certain data :

* 1. ***MANDATORY*** - **eSDK_shell_file** - Complete absolute path to the eSDK shell file ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 2. ***MANDATORY*** - **Base_Dir_Location** - Path to the directory where the project is initialized
* 3. ***OPTIONAL*** - **Tflite_prebuilt_file** - Complete Absolute path to the tflite prebuilt dev tar.gz file ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 4. ***OPTIONAL*** - **Acceleration_engines** - An array of Acceleration engines to be used in QIMSDK environment. If not needed, leave as is in the example config json. ***Every Acceleration engine from the array must contain:***
  * 4.1. ***OPTIONAL*** - **Acceleration_engine** - Acceleration engine to be used. If not needed, leave this field and the "Acceleration_engine_path" field with "-" value
  * 4.2. ***OPTIONAL*** - **Acceleration_engine_path** - path to unzipped acceleration engine archive directory with unzipped files for the AI engine specified in the "Acceleration_engine" field ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 5. ***OPTIONAL*** - **rvSDK_prebuilt_path** - This enables dfs GStreamer plugin using prebuilt RVsdk - Please provide path to unzipped RVsdk prebuilt zip. (if not necessary, just leave the value for this field empty)
* 6. ***OPTIONAL*** - **Deploy_URL** - This enables sending ipk packages built on the host to remote target or local filesystem (if sending them to a remote target is not necessary, just leave the value for this field empty) ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 7. ***OPTIONAL*** - **Deploy_dev_URL** - This enables sending dev packages built on the host to remote target or local filesystem (if sending them to a remote target is not necessary, just leave the value for this field empty) ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 8. ***OPTIONAL*** - **Deploy_QIMSDK_Artifacts_URL** - This enables sending ipk packages built in qimsdk environment to local filesystem folder. QIMSDK artifacts will be sent to the directory specified in this json field. (if QIMSDK artifacts are not needed on host machine, just leave the value for this field empty) ***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***
* 9. ***OPTIONAL*** - **Deploy_QIMSDK_Artifacts_tag** - Appends value in this field to artifacts archive name, e.g. if value is "1.0.0" result would be packages_1.0.0.zip (if QIMSDK artifacts do not needed suffix, just leave the value for this field empty)
* 10. ***MANDATORY*** - **Gst_package_group** - Gst package group (packagegroup-qti-gst-basic or packagegroup-qti-gst)
* 11. ***OPTIONAL*** - **Gst_plugins_qti_oss_dependencies** - List of the dependency packages that will be compiled and installed to the target device.
* 12. ***MANDATORY*** - **Device_install_prefix** - Prefix to be prepended to the package installation path on target device - Installing packages in / directory is forbidden. Do not leave field empty, or set / value !!! (e.g. choosing /data/sdk would install gst libs in /data/sdk/usr/lib/gstreamer-1.0)

The json files must be created in the ```<snapdragon-iot-qimsdk>/sdk-tools/targets/``` directory. ```<snapdragon-iot-qimsdk>/sdk-tools/targets/LE.PRODUCTS.2.1.json``` can be used as an example.

***Once you have created the configuration file in ```<snapdragon-iot-qimsdk>/sdk-tools/targets/```, the image can be built***

The functions in ```<snapdragon-iot-qimsdk>/sdk-tools/scripts/host/env_setup.sh``` provide the necessary build, run, start, stop and remove commands. All of them receive the path to the configuration json file as their first and only argument, as shown in the examples bellow:

<div id="Helper_Scripts">

### Helper Scripts

***In order for the functions inside host_env_setup.sh to work on the host, the script must be sourced***

```bash
source <snapdragon-iot-qimsdk>/sdk-tools/scripts/host/host_env_setup.sh
```
- ```qimsdk-setup ./targets/<config.json>``` - This function builds IM SDK in host machine
- ```qimsdk-host-env-setup ./targets/<config.json>``` - This function setups environment variables
- ```qimsdk-remove ./targets/<config.json>``` - This function removes IM SDK from host machine
- ```qimsdk-host-env-remove``` - This function removes environment variables

```bash
source ${QIMSDK_BASE_DIR}/sdk-tools/scripts/image/env_setup.sh
```

- ```qimsdk-layers-build``` - Must be invoked to compile modified layers in the container
- ```qimsdk-layers-package``` - Must be invoked after invoking qimsdk-layers-build to package compiled recipes in the container
- ```qimsdk-device-select```  - Must be invoked to select device when multiple devices are connected
- ```qimsdk-device-prepare``` - Must be invoked to prepare device for package sync
- ```qimsdk-device-sync-rel``` -Must be invoked to sync release packages with the device
- ```qimsdk-device-sync-dbg``` - Must be invoked to sync debug packages with the device
- ```qimsdk-device-packages-remove``` - Must be invoked to remove installed packages from the device
- ```qimsdk-remote-sync-rel``` - Must be invoked to sync release packages with the remote target
- ```qimsdk-remote-sync-dbg``` - Must be invoked to sync debug packages with the remote target
- ```qimsdk-remote-sync-dev``` - Must be invoked to sync dev packages with the remote target
- ```qimsdk-remote-sync-staticdev``` - Must be invoked to sync staticdev packages with the remote target
- ```qimsdk-remote-packages-remove``` - Must be invoked to remove packages, installed by the remote target script

***Please note that script file extension must be renamed to bat when remote OS is windows***

<div id="Local_Sync_And_Uninstall_Scripts">

## Local Sync And Uninstall Scripts

If ipk files needs to be deployed to device connected to another pc, then ipk files can be copied to that pc with *qimsdk-remote-sync-rel* or *qimsdk-remote-sync-dbg* scripts. Depending whether Linux or Windows is used on the pc (where device is connected) can be used corresponding scripts to update ipk's to the device. Those scripts also needs to be copied to the pc (where device is connected). Installed packages can be uninstalled later using the corresponding uninstall script provided below.

***Please note that these scripts are deleting all successfully installed ipk files from the folder on pc (where device is connected)***

***Please note that device needs to be prepared (disable verify, root, remount, file system remount as rw) for update before invoking these scripts***

***Please note that adb needs to be available in the path variable for windows and linux***

<div id="Linux">

### Linux

Script location: \<snapdragon-iot-qimsdk\>/sdk-tools/scripts/local/linux.sh
Sync cmd: qimsdk-local-sync - Sync packages with the device from specified folder
Uninstall cmd: qimsdk-local-packages-remove - Uninstall packages previously installed on the device

```bash
source <snapdragon-iot-qimsdk>/sdk-tools/scripts/local/linux.sh
qimsdk-local-sync <folder to sync>
qimsdk-local-packages-remove <folder with ipks>
```

<div id="Windows">

### Windows

Example for adding adb to powershell path

```powershell
$Env:PATH += ";<path to adb>"
```

Script location: \<snapdragon-iot-qimsdk\>/sdk-tools/scripts/local/win.ps1
Sync cmd: qimsdk-local-sync - Sync packages with the device from specified folder
Uninstall cmd: qimsdk-local-packages-remove - Uninstall packages previously installed on the device

```powershell
.\<snapdragon-iot-qimsdk>\sdk-tools\scripts\local\win.ps1
qimsdk-local-sync <folder to sync>
qimsdk-local-packages-remove <folder with ipks>
```

<div id="Development_Workflow">

## Development Workflow

<div id="Initial_One_Time_Setup">

### Initial One Time Setup

#### Password Protected SSH Key

***Please note that this step needs to be invoked only once after console is started***

If use of password protected ssh key is needed, ssh agent needs to be used:

```bash
ssh-agent -s > ~/work/.ssh_agent.info
. ~/work/.ssh_agent.info
ssh-add ~/.ssh/<private-ssh-key-name>
```

#### Fetch Code For eSDK Recipe Not Included In QIMSDK

***Please note that this step needs to be invoked only once after console is started***

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

```bash
qimsdk-device-prepare
adb disable-verity
adb reboot
```

#### Prepare Device Connected To Local PC

***Please note that this step needs to be invoked only once after device, connected to local PC, is started***

***Please note that this step needs to be invoked only once after console is started***

```bash
qimsdk-device-prepare
```

<div id="Continuous_Development_After_Initial_Setup">

### Continuous Development After Initial Setup

#### Source Code Location

```bash
ls -la ${QIMSDK_ESDK_BASE_DIR}/src/<path to src code>
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
* For information on how to select the target URL, refer to [How to fill out Configuration JSON File](#How_to_fill_out_Configuration_JSON_File)

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

<div id="Getting_QIMSDK_Artifacts_from_Host_QIMSDK_Environment">

## Getting QIMSDK Artifacts from Host QIMSDK Environment

**Once layers have been built, these commands can be used to generate artifact archives in user specified directories in host file system:**

### To get all packages as artifacts archive (packages.zip):

```bash
qimsdk-host-sync-artifacts-all
```

### To get release packages as artifacts archive (packages_rel.zip):

```bash
qimsdk-host-sync-artifacts-rel
```

### To get development packages as artifacts archive (packages_dev.zip):

```bash
qimsdk-host-sync-artifacts-dev
```

<div id="Compiling_gst-plugins-qti-oss_Against_tflite-dev.tar.gz">

## Compiling gst-plugins-qti-oss Against tflite-dev.tar.gz

tflite-dev.tar.gz can be generated in a separate container or Bazel environment. Path to that file needs to be specified in the JSON configuration file with tag **Tflite_prebuilt_file** (***PATH MUST BE ABSOLUTE, DO NOT USE A RELATIVE PATH!***)

<div id="Adding_One_More_Poky_Layer_In_The_QIMSDK">

## Adding One More Poky Layer In The QIMSDK

New bash shell file must be added in the *<project root>/sdk-tools/scripts/image/layers*. This file automatically is sourced in the environment and all functions are available. <br />
Template content for that file is available bellow. <br />
Please note that variables **\${LAYER_NAME}**, **\${PACKAGE_GROUP}** and **\${PATH_TO_LAYER}** should be updated according corresponding layer. <br />
Functions **qimsdk-\${LAYER_NAME}-prepare**, **qimsdk-\${LAYER_NAME}-build**, **qimsdk-\${LAYER_NAME}-package** and **qimsdk-\${LAYER_NAME}-clean** are mandatory. They are invoked automatically when common prepare, build, package or clean functions are invoked. <br />
Example content is provided to utilize corresponding devtool functions. But if needed modifications should be implemented as needed. <br />
Please refer to existing gst-plugins-qti-oss layer in the *<project root>/sdk-tools/scripts/image/layers/gst-plugins-qti.sh <br />

```bash
#!/bin/bash

# Register layer
QIMSDK_ALL_LAYERS+=("${LAYER_NAME}")

# Prepare ${LAYER_NAME}
function qimsdk-${LAYER_NAME}-prepare() {
    qimsdk-bitbake-add-layers ${PATH_TO_LAYER}                              && \
    devtool modify ${PACKAGE_GROUP}
}

# Build ${LAYER_NAME}
function qimsdk-${LAYER_NAME}-build() {
    devtool build ${PACKAGE_GROUP}
}

# Package ${LAYER_NAME}
function qimsdk-${LAYER_NAME}-package() {
    devtool package ${PACKAGE_GROUP}
}

# Clean ${LAYER_NAME}
function qimsdk-${LAYER_NAME}-clean() {
    devtool reset ${PACKAGE_GROUP}
    rm -rf ${QIMSDK_ESDK_BASE_DIR}/workspace/sources/${PACKAGE_GROUP}
}
```
