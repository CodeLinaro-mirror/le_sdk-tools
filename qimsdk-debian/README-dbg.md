# QIM SDK Debian

## Table of Contents

* [Prerequisites](#Prerequisites)
  * [Ubuntu Version](#Ubuntu_Version)
  * [Ubuntu Packages](#Ubuntu_Packages)
  * [How to increase Max user watches and max user instances on host system](#Max_user_watches)
  * [Host System Swap Image allocation and creation](#Swap_Image_Creation)
  * [Docker Must Be Configured On The Host System (one time)](#Docker_Host_System)
  * [Add internal docker registry mirror. (optional)](#Add_internal_docker_registry_mirror)
  * [Proxy. (optional)](#Proxy)
  * [Query and examine the Host System cgroup memory limits](#Cgroup_Memory_Limits)
  * [Adjust the Host system VM settings (optional)](#Adjust_Host_VM_Settings)
* [Docker Images](#Docker_Images)
  * [QIMSDK Debug Image](#QIMSDK_Debug_Image)
  * [QIMSDK Build Image](#QIMSDK_Build_Image)
  * [QIMSDK Deploy Image](#QIMSDK_Deploy_Image)
* [Debug Variant - Host Side Helper Scripts And Configuration](#Host_Side_Helper_Scripts)
  * [How to fill out Configuration JSON Files](#How_to_fill_out_Configuration_JSON_Files)
  * [Docker Host Side Helper Scripts](#Docker_Host_Side_Helper_Scripts)
  * [Docker Debug Container Side Helper Scripts](#Docker_Debug_Container_Side_Helper_Scripts)
  * [Troubleshoot Docker Image OOM Build Errors](#Host_System_OOM_Debugging)
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
  * [Adding custom user configurations to deploy container](#Adding_custom_user_configurations)
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
* [Documentation References](#Documentation_References)

<div id="Prerequisites">

## Prerequisites

<div id="Ubuntu_Version">

### Ubuntu Version

Ubuntu 22.04 or 24.04 is required for host system OS

<div id="Ubuntu_Packages">

### Ubuntu Packages

Prerequisite packages must be installed on the host (one time)

Prerequisite packages for arm architecture build systems:

```bash
sudo apt install -y jq tofrodos
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq
```

Prerequisite packages for x86 architecture build systems:

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

This is done to prevent "System limit for number of file watchers reached" error during development. Default system limits are too low.
**Add these two lines to */etc/sysctl.conf* and reboot the PC:**

```bash
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=542288
```

<div id="Swap_Image_Creation">

### Host System Swap Image allocation and creation

In order to build the Docker image files your host system is expected to have at least 64 GB of RAM and a swap image of at least half the available RAM plus some small meaningful reserve.

For example, if you have 64 GB of RAM, the recommended swap image file size is at least 32 GB.

If you set a reserve of 8 GB, the total RAM + swap + reserved memory size amounts to 104 GB in this case.

#### Check whether you might have swap space enabled as follows:

```bash
sudo swapon --show
```

#### If the swap is missing or being too small, do create a new swap file as follows:

```bash
MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{printf "%.0f\n", $2/1024/1024}')
let MEM_SWAP="$MEM_AVAIL / 2 + 8"
sudo swapoff /swap.img
sudo fallocate -l "${MEM_SWAP}G" /swap.img
sudo chmod 600 /swap.img
sudo mkswap /swap.img
sudo swapon /swap.img
edit /etc/default/grub
	GRUB_CMDLINE_LINUX_DEFAULT="text cgroup_enable=memory swapaccount=1"
sudo update-grub
edit /etc/fstab and add the following line at the end of the file
	/swap.img	none	swap	sw	0	0
```

Save and close all of the previously opened system files above, then reboot the system.

Now check the size of the newly created and mounted swap image matches the above settings.

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

#### Add User to Docker Group in order to have access to docker daemon (to build images, see containers etc.)

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

If any sort of network download or otherwise functionality on the host machine requires proxy, same proxy config can be added to the docker daemon in the following way:

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

This configuration ensures that both the Docker daemon and build processes use the same proxy settings as the host system.

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

***All containers will need to be restarted after moving docker directory since docker service was stopped***

```bash
# Command to see all container names; <container_name> will be under the 'NAMES' coloumn
docker ps -a
# To start any of the listed containers
docker start <container_name>
```

<div id="Cgroup_Memory_Limits">

### Query and examine the Host System cgroup memory limits

#### Check there are not any active cgroup Linux host cpu and memory utilization restrictions in place.

```bash
sudo systemctl list-unit-files | grep -Ei docker
sudo systemctl status docker.service
cat /sys/fs/cgroup/system.slice/docker.service/
cat /sys/fs/cgroup/system.slice/docker.service/memory.max
cat /sys/fs/cgroup/system.slice/docker.service/memory.swap.max
```

Check the above docker.service cgroup memory configuration file entries have 'max' set as the value being read back.

<div id="Adjust_Host_VM_Settings">

### Adjust the Host system VM settings (optional)

#### If your Host system is equipped with 64GB RAM or less, tweak your system VM page swap and dentry and inode cache reclaim behavior as follows:

```bash
edit the /etc/sysctl.conf file
    vm.swappiness=10
    vm.vfs_cache_pressure=400
    vm.min_free_kbytes=262144
```
#### Argumentation:

1. **vm.swappiness tuning**

    - Higher values tend to command more aggressive application memory page swapping, while lower values favour keeping application pages in memory for as long as possible.

    - The default vm.swappiness parameter value is 60 on recent Ubuntu/Debian OS flavours, which might not fit our Docker build environment well, especially on systems low on available RAM, hence the recommendation for a more relaxed setting of 10.

2. **vm.vfs_cache_pressure tuning**

    - Intermittent high VFS pressure as a result of the creation of many small temporarily used files and folders during package installation might cause the host system OS to start premature swapping of the memory pages, associated with these cached dentries and inodes to disk even though the amount of available RAM might still be sufficient for holding these in memory.

    - The default value of the vfs_cache_pressure tunable tends to be 100 on recent Linux-kernel based operating systems with the kernel's dentry and inode cache reclaim rate being fair compared to the pagecache and swapcache reclaim rate.

    - Decreasing the value instructs the kernel to prefer retaining the dentry and inode caches for long, while increasing the value tells the kernel to reclaim the dentry and inode caches sooner than later.

    - Setting the vm.vfs_cache_pressure value to 400 might relax the dentry and inode cache managemnt by freeing the cached pages early and ensuring the system might not run out of memory faster during periods of high CPU multithreaded utilization and excessive memory load.

3. **vm.min_free_kbytes tuning**

    - In heavy multi-stage Docker build environments with lots of buildx threads spawned, the Host OS might have its available RAM memory exhausted quite fast.

    - In order to allow for the OS to manage its own processes and have breathing room for housekeeping and more stable memory management, it is essesntial to instruct the OS to reserve a number of virtual memory free pages for each lowmem zone in the system.

    - The amount of this mandatory VM free memory watermark is typically set by the vm.min_free_kbytes tunable.

    - A value too low might make the system more prone to deadlocks under high CPU and memory utilization loads, while a value too high might cause premature and unwanted OOM service killings taking place.

    - Therefore, in order to achieve a better free memory balancing under excessive system load, the proposed value adjustment of 262144 KB setting has been made.

<div id="Docker_Images">

## Docker Images

Two QIMSDK docker images are built. One for development machine. One for device target.
- They are based on debian trixie images
- The first image - [QIMSDK Build Image](#QIMSDK_Build_Image) is used to build the IMSDK components and fetch and build any buildtime dependencies and to generate the final IMSDK packages.
- The second image - [QIMSDK Deploy Image](#QIMSDK_Deploy_Image) contains the final IMSDK package for the target device. It contains only the required runtime libraries and binaries needed for IMSDK use-cases.
- A third [QIMSDK Debug Image](#QIMSDK_Debug_Image) is only used when working in an environment which requires continuous development. This is done in order to enable the ability to select what code is compiled, instead of just compiling the tips of the mainline branches of the according projects

<div id="QIMSDK_Debug_Image">

### QIMSDK Debug Image (based on host architecture)
1. Start from Debian trixie Image
2. Alter git configuration in QIMSDK Build Image to use camera-service code locally provided by user in config json instead of github
3. Alter git configuration in QIMSDK Build Image to use gst meta layers locally provided by user in config json instead of codelinaro
4. Alter git configuration in QIMSDK Build Image to use gst source code locally provided by user in config json instead of github
5. Copy helper scripts to build image
6. Set dev environment variables for build image

<div id="QIMSDK_Build_Image">

### QIMSDK Build Image (based on host architecture)
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

<div id="QIMSDK_Deploy_Image">

### QIMSDK Deploy Image (based on target arm64 architecture)
1. Start from base debian:trixie image
2. Install runtime dependency Open Source packages to deploy image
3. Add QCOM PPA and install QCOM dependencies
4. Add qimsdk user
5. Copy built binaries from QIMSDK Build Image
6. Copy deb packages to device image
7. Install deb packages to deploy image and remove the directory after install
8. Add environment variables

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
 3. ***MANDATORY*** - **Docker_image_path** - Absolute path to remote ssh or local destination to sync docker images or artifacts.
 4. ***MANDATORY*** -  **Target_device_ID** - adb device ID of the target device qimsdk is to be installed on. Any faux value can still be provided and compilation will carry on.
 5. ***OPTIONAL*** -  **QAIRT_SDK_version** - Version of the Qualcomm AI Runtime SDK to be used in the container. If field is left open - QAIRT functionalities will be disabled.
 6. ***MANDATORY*** - **camera_service_Source_Dir** - PATH to camera-service sources directory, which contains open-source repo needed to enable camera functionality.
 7. ***MANDATORY*** - **IM_SDK_Source_Dir** - PATH to IM SDK sources directory, which contains all gst plugins. ***Note: Path provided must point to gst-plugins-imsdk directory! Code checked out on local branch main will be built. Ensure desired code is checked out on main branch before proceeding with debug variant QIMSDK build!***
 8. ***OPTIONAL*** - **camera_service_git_tag** - Specifies the commit ID or tag for the camera-service project. ***Note: If not provided, the latest (TIP) version will be used!***
 9. ***OPTIONAL*** - **IM_SDK_Source_git_tag** - Specifies the commit ID or tag for the IM SDK sources directory. ***Note: If not provided, the latest (TIP) version will be used!***
 10. ***OPTIONAL*** - **MAP_sources_to_dev_container** - If IM_SDK_Source_Dir, LE_Services_Source_Dir is wanted to be mapped to the build container, then this attribute should be filled as "TRUE" or "ENABLE" or "ENABLED" ***Note: Default is FALSE***

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

 - qimsdk-cmake-build-gst-plugins-imsdk - Incremental build all gst-plugins-imsdk
 - qimsdk-help-build - Display all cmake functions to build/clean any gst plugin
 - qimsdk-incremental-build - Incremental build of all gst plugins
 - qimsdk-dbg-save-artifacts - Save release variant artifacts to specified Docker_image_path in configuration json file. They can then be loaded using the load functions in the environment
 - qimsdk-dbg-save-artifacts-dbg - Save debug variant artifacts to specified Docker_image_path in configuration json file. They can then be loaded using the load functions in the environment
 - qimsdk-dbg-push-artifacts - Push release variant artifacts to device with specified id in configuration json file
 - qimsdk-dbg-push-artifacts-dbg - Push debug variant artifacts  to device with specified id in configuration json file

<div id="Host_System_OOM_Debugging">

### Troubleshoot Docker Image OOM Build errors

#### Troubleshooting OOM and VFS high memory pressure Host System conditions:

1. Collect and analyze docker.service journalctl logs

```bash
journalctl --user --unit=docker.service
```

2. Analyze the Host System syslog and scan for any OOM and VM page fault log traces:

```bash
sudo cat /var/log/syslog | grep -E "oom-killer|oom_kill_process|OOM killer|lowmem_reserve|Out of memory:|oom-kill:constraint|systemd-oomd.service|active_anon|hugepages_free|pages in swap cache|pages RAM"
```

3. Monitor the RAM and swap space allocation and utilization using your favourite tool during the Docker build file process, for example:

```bash
sudo apt install smem
...
while true;                                                             \
do                                                                      \
    echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---" >> swap_usage_log.txt;  \
    sudo smem -t -k -p -s swap >> swap_usage_log.txt;                   \
    sleep 10;                                                           \
done
...
Ctrl+C
...
cat swap_usage_log.txt | grep -E "^[ ]{2,}[0-9]{2,}[0-9MG \.]{1,}$(M|G)"
```

4. Attempt to reduce the maximum number of Docker builde threads during image compilation, if deemed necessary

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

***NOTE: Ensure proper CDI json, which contains all of the needed platform mountings for the specific platform, is copied to /etc/cdi in device storage, before running the qimsdk container. CDI json for the specific hardware and platform is located in qimsdk-debian/cdi/\<hardware\>-\<platform\>-qimsdk.json. Because of the basic design principles of Docker, an .env file is also needed for the environment variables inside device container as well. .env file is located in qimsdk-debian/env/\<hardware\>-\<platform\>-qimsdk.env. It needs to be copied to /etc/docker/env in device storage.***

For example, if working on qcs6490 hardware target with QLI 1.X platform, the correct CDI json would be qimsdk-debian/cdi/qcs6490-qli-1x-qimsdk.json. The correct .env file would be qimsdk-debian/env/qcs6490-qli-1x-qimsdk.env

```bash
### push corresponding CDI json to the device
adb shell mkdir -p /etc/cdi/
adb push qimsdk-debian/cdi/qcs6490-qli-1x-qimsdk.json /etc/cdi/qimsdk.json
adb shell mkdir -p /etc/docker/env/
adb push qimsdk-debian/env/qcs6490-qli-1x-qimsdk.env /etc/docker/env/qimsdk.env
```

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

***NOTE: Ensure proper CDI json, which contains all of the needed platform mountings for the specific platform, is copied to /etc/cdi in device storage, before running the qimsdk container. CDI json for the specific hardware and platform is located in qimsdk-debian/cdi/\<hardware\>-\<platform\>-qimsdk.json. Because of the basic design principles of Docker, an .env file is also needed for the environment variables inside device container as well. .env file is located in qimsdk-debian/env/\<hardware\>-\<platform\>-qimsdk.env. It needs to be copied to /etc/docker/env in device storage.***

For example, if working on qcs6490 hardware target with QLI 1.X platform, the correct CDI json would be qimsdk-debian/cdi/qcs6490-qli-1x-qimsdk.json. The correct .env file would be qimsdk-debian/env/qcs6490-qli-1x-qimsdk.env

```bash
### push corresponding CDI json to the device
adb shell mkdir -p /etc/cdi/
adb push qimsdk-debian/cdi/qcs6490-qli-1x-qimsdk.json /etc/cdi/qimsdk.json
adb shell mkdir -p /etc/docker/env/
adb push qimsdk-debian/env/qcs6490-qli-1x-qimsdk.env /etc/docker/env/qimsdk.env
```

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

***NOTE: Ensure proper CDI json, which contains all of the needed platform mountings for the specific platform, is copied to /etc/cdi in device storage, before running the qimsdk container. CDI json for the specific hardware and platform is located in qimsdk-debian/cdi/\<hardware\>-\<platform\>-qimsdk.json. Because of the basic design principles of Docker, an .env file is also needed for the environment variables inside device container as well. .env file is located in qimsdk-debian/env/\<hardware\>-\<platform\>-qimsdk.env. It needs to be copied to /etc/docker/env in device storage.***

For example, if working on qcs6490 hardware target with QLI 1.X platform, the correct CDI json would be qimsdk-debian/cdi/qcs6490-qli-1x-qimsdk.json. The correct .env file would be qimsdk-debian/env/qcs6490-qli-1x-qimsdk.env

```bash
### push corresponding CDI json to the device
adb shell mkdir -p /etc/cdi/
adb push qimsdk-debian/cdi/qcs6490-qli-1x-qimsdk.json /etc/cdi/qimsdk.json
adb shell mkdir -p /etc/docker/env/
adb push qimsdk-debian/env/qcs6490-qli-1x-qimsdk.env /etc/docker/env/qimsdk.env
```

```bash
# Run container
qimsdk-docker-device-run-container <path-to-config-json>
```

5. From here any qimsdk-docker-device... functions can be used freely on remote PC.

#### Python scripts to load image, run container and build artifacts from Windows
*Note: Docker_image_path in json file should be path from host machine*

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

<div id="Docker_Container_Renaming">

## Docker Container Renaming

<div id="Rename_Docker_Device_Container">

### Rename Docker Device Container

Device Container can be renamed by using the "Additional_tag_container" in *config.json*

*Note: Keep in mind that "qimsdk" prefix will be automatically prepend to that name.*

<div id="Manual_Commands_Instead_Of_Scripts">

## Release Variant - Manual Commands Instead Of Scripts

In the Release variant, the QIMSDK Debian build process follows a streamlined approach:

1. The qimsdk-debian build image directly compiles GStreamer plugins from their GitHub repositories
2. The compiled GStreamer plugins and their dependencies are then propagated to the deploy image
3. The deploy image is installed on the target device
4. The qimsdk-debian deploy container runs on the device with all required components

This approach eliminates the need for intermediate debug images and does not require custom code modifications, making it suitable for production deployments where standard upstream code is preferred.

<div id="Docker_Build">

### Docker Build

  <div name="docker_build">Dockerfile arguments have default values, but they can be customized using **--build-arg** flag in docker build command.</div>
  <ul>

  ```bash
  # Build qimsdk-debian deploy docker image
  DOCKER_BUILDKIT=1 docker build                                                                   \
      --progress=plain --target qimsdk_deploy_arm64 <path/to/Dockerfile/directory> -t <generated-image-name>
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

***NOTE: Ensure proper CDI json, which contains all of the needed platform mountings for the specific platform, is copied to /etc/cdi in device storage, before running the qimsdk container. CDI json for the specific hardware and platform is located in qimsdk-debian/cdi/\<hardware\>-\<platform\>-qimsdk.json. Because of the basic design principles of Docker, an .env file is also needed for the environment variables inside device container as well. .env file is located in qimsdk-debian/env/\<hardware\>-\<platform\>-qimsdk.env. It needs to be copied to /etc/docker/env in device storage.***

For example, if working on qcs6490 hardware target with QLI 1.X platform, the correct CDI json would be qimsdk-debian/cdi/qcs6490-qli-1x-qimsdk.json. The correct .env file would be qimsdk-debian/env/qcs6490-qli-1x-qimsdk.env

```bash
### push corresponding CDI json to the device
adb shell mkdir -p /etc/cdi/
adb push qimsdk-debian/cdi/qcs6490-qli-1x-qimsdk.json /etc/cdi/qimsdk.json
adb shell mkdir -p /etc/docker/env/
adb push qimsdk-debian/env/qcs6490-qli-1x-qimsdk.env /etc/docker/env/qimsdk.env
```

<h3 style="color:red">
  <b>Create a shell file with the following content:</b>
</h3>

```bash
### adb shell
docker run -it -d --net host --env-file /etc/docker/env/qimsdk.env                                 \
    --device qualcomm.com/device=qimsdk -h qimsdk                                                  \
    --name <desired-container-name> <generated-image-name>
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

<div id="Documentation_References">

## Documentation References

### Useful pointers for further information:

1. https://docs.docker.com/build/buildkit/configure/
2. https://docs.docker.com/engine/daemon/troubleshoot/#kernel-cgroup-swap-limit-capabilities
3. https://www.kernel.org/doc/html/v6.6/admin-guide/sysctl/vm.html
