# About The QAIRT-Debian Docker Image

## Table of Contents

* [QAIRT Docker Images](#Docker_images)
    * [qairt_builder](#qairt_builder)
    * [python_builder](#python_builder)
    * [qairt_deploy_arm64](#qairt_deploy)
* [Workflow](#Workflow)
    * [How to build](#How_to_build)
    * [Running the qairt deploy container](#Running_the_container)
        * [Setting up the platform](#Platform_model_file_and_folder_setup)
        * [How to run the qairt deploy container](#Run_the_qairt_deploy_container)
    * [How to use the qairt-debian container](#Using_the_container)

<div id="Docker_images">

## QAIRT Docker Images

Two QAIRT Docker & One Python Builder images are provided:

- Build Image (qairt_builder):
  - Based on Debian Trixie
  - Matches the host architecture

- Python Builder image (python_builder)

- Deploy Image (qairt_deploy_arm64):
  - Based on Debian Trixie
  - Specifically for ARM64 architecture
  - Contains only the necessary runtime components for target devices
This separation allows for efficient development on the host system while ensuring proper deployment to ARM64-based target devices.

<div id="qairt_builder">

### qairt_builder (based on host architecture)

    1. Start from Debian Trixie
    2. Add ARM64 architecture support to the Debian base image.
    3. Install required build and cross-compilation dependencies.
    4. Clone the fastrpc repository.
    5. Configure build for native or cross-compilation (arm64).
    6. Build and install fastrpc library.
    7. Download QAIRT SDK package.
    8. Extract SDK and copy required header files.
    9. Copy QNN & SNPE libs.
    10. Copy DSP (Hexagon) libraries for supported architectures.

<div id="python_builder">

### python_builder (based on arm64 architecture)
    1. Setup the python:3.12-slim from the docker hub.
    2. Python 3.12 libs and bins are copied from here to deploy container.


<div id="qairt_deploy">

### qairt_deploy_arm64 (based on arm64 architecture)

    1. Set up ARM64 Debian runtime base.
    2. Install system dependencies and Adreno GPU drivers.
    3. Configure Python environment and install packages.
    4. Copy runtime libraries and Python code.
    5. Create non-root user with required permissions.
    6. Set ownership, limits, and working directory.
    7. Switch to non-root user for execution.

<div id="Workflow">

## Workflow

<div id="How_to_build">

### How to build

Building qairt_deploy_arm64: minimal set of runtime binaries needed to execute use-cases are available in this image.

```bash
docker build --build-arg QAIRT_ARG_SDK_VERSION=<version, e.g. 2.39.0.250925> --target qairt_deploy_arm64 -t <desired-image-name> .
```
In the docker build command above, provide the version of QAIRT SDK that you want to install, e.g. *--build-arg QAIRT_ARG_SDK_VERSION=2.39.0.250925*. If this argument is not provided, docker build will fail.

<div id="Running_the_container">

### Running the qairt deploy container

In order to run the qairt container with GStreamer functionalities inside, please make use of the qairt arm64 deploy image built earlier and specify the 'host' network mode.

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

> **Note:** CDI files are located in and named: `qairt-container/cdi/\<hardware\>-\<platform\>-qairt.json`;

The CDI file needed for a specific hardware platform needs to be copied to the /etc/cdi/ directory on the target device storage.

Please create this directory first, if it does not exist as follows:

```bash
sudo mkdir -p /etc/cdi
sudo chmod 755 /etc/cdi
```

> **Note:** the ENV files are located in and named: `qairt-container/env/\<hardware\>-\<platform\>-qairt.env`;

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
export QAIRT_USER_CONTENTS_ROOT=/root

# For Ubuntu platforms — content stored under the ubuntu home directory
export QAIRT_USER_CONTENTS_ROOT=/home/ubuntu

# For any platform — content stored under /etc, independent of the OS type
export QAIRT_USER_CONTENTS_ROOT=/etc
```

Then create the required directories:

```bash
mkdir -p ${QAIRT_USER_CONTENTS_ROOT}/media
mkdir -p ${QAIRT_USER_CONTENTS_ROOT}/models
mkdir -p ${QAIRT_USER_CONTENTS_ROOT}/labels
mkdir -p ${QAIRT_USER_CONTENTS_ROOT}/configs
```

Apply the correct permissions to each directory and its contents.
> **Note:** Use `sudo` when the `QAIRT_USER_CONTENTS_ROOT` value is set to `/etc` for any non-root platform user:

```bash
# media
find ${QAIRT_USER_CONTENTS_ROOT}/media/ -type d -exec chmod 755 {} \;
find ${QAIRT_USER_CONTENTS_ROOT}/media/ -type f -exec chmod 644 {} \;

# models
find ${QAIRT_USER_CONTENTS_ROOT}/models/ -type d -exec chmod 755 {} \;
find ${QAIRT_USER_CONTENTS_ROOT}/models/ -type f -exec chmod 644 {} \;

# labels
find ${QAIRT_USER_CONTENTS_ROOT}/labels/ -type d -exec chmod 755 {} \;
find ${QAIRT_USER_CONTENTS_ROOT}/labels/ -type f -exec chmod 644 {} \;

# configs
find ${QAIRT_USER_CONTENTS_ROOT}/configs/ -type d -exec chmod 755 {} \;
find ${QAIRT_USER_CONTENTS_ROOT}/configs/ -type f -exec chmod 644 {} \;
```

**Before running the qairt arm64 deploy container, please upload your models and model-specific data into these newly created platform model data folders.**

<div id="Run_the_qairt_deploy_container">

### Commands to run the qairt device deploy container:

> **Note:** If your platform and OS combo do not support adb connectivity, please use the onboard Ethernet/WLAN network to access the device over ssh and adapt the execution of the commands listed below accordingly.

Set the root path for the user content by exporting one of the following environment variables in a platform terminal, depending on your platform and preference:

```bash
# For QLI platforms — content stored under the root home directory
export QAIRT_USER_CONTENTS_ROOT=/root

# For Ubuntu platforms — content stored under the ubuntu home directory
export QAIRT_USER_CONTENTS_ROOT=/home/ubuntu

# For any platform — content stored under /etc, independent of the OS type
export QAIRT_USER_CONTENTS_ROOT=/etc
```

Push the CDI and ENV files and run the container.

```bash
adb push qairt-container/cdi/<hardware>-<platform>-qairt.json /etc/cdi/qairt.json
adb push qairt-container/env/<hardware>-<platform>-qairt.env /etc/docker/env/qairt.env
```

>**Note:** When the `QAIRT_USER_CONTENTS_ROOT` environment variable value is `/root` or `/home/ubuntu`** (the model content shall be mounted into the `/home/qairt/` folder inside the container):

Push the deploy Docker image to the device and load it

```bash
export QAIRT_DEVICE_TEST_PATH="<target_device_path>"
export QAIRT_DOCKER_IMAGE="<path_to_docker_image_file>"
adb shell mkdir -p "${QAIRT_DEVICE_TEST_PATH}"
adb push "${QAIRT_DOCKER_IMAGE}" "${QAIRT_DEVICE_TEST_PATH}/${QAIRT_DOCKER_IMAGE}"
adb shell docker load -i "${QAIRT_DEVICE_TEST_PATH}/${QAIRT_DOCKER_IMAGE}"
```

Now run the deploy Docker container

```bash
adb shell docker run -it -d --net host \
  --env-file /etc/docker/env/qairt.env \
  --device qualcomm.com/device=qairt \
  -v ${QAIRT_USER_CONTENTS_ROOT}/media:/home/qairt/media \
  -v ${QAIRT_USER_CONTENTS_ROOT}/models:/home/qairt/models \
  -v ${QAIRT_USER_CONTENTS_ROOT}/labels:/home/qairt/labels \
  -v ${QAIRT_USER_CONTENTS_ROOT}/configs:/home/qairt/configs \
  -h qairt --name qairt <desired-image-name>
```

> **Note:** When the `QAIRT_USER_CONTENTS_ROOT` environment variable value is `/etc`** (the model content shall be mounted into the `/etc/` folder inside the container):

```bash
adb shell docker run -it -d --net host \
  --env-file /etc/docker/env/qairt.env \
  --device qualcomm.com/device=qairt \
  -v ${QAIRT_USER_CONTENTS_ROOT}/media:/etc/media \
  -v ${QAIRT_USER_CONTENTS_ROOT}/models:/etc/models \
  -v ${QAIRT_USER_CONTENTS_ROOT}/labels:/etc/labels \
  -v ${QAIRT_USER_CONTENTS_ROOT}/configs:/etc/configs \
  -h qairt --name qairt <desired-image-name>
```

<div id="Using_the_container">

### How to use the qairt-debian container

To execute a bash shell in container, run the following command:

```bash
docker exec -ti qairt bash
```
