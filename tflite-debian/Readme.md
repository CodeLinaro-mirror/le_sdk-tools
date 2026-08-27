# About The TensorFlow Lite Debian Docker Image

## Table of Contents

* [TFLite Docker Images](#Docker_images)
    * [tflite_build](#tflite_build)
    * [tflite_deploy_arm64](#tflite_deploy)
* [Workflow](#Workflow)
    * [How to build](#How_to_build)
    * [Running the tflite deploy container](#Running_the_container)
        * [Setting up the platform](#Platform_model_file_and_folder_setup)
        * [How to run the qairt deploy container](#Run_the_qairt_deploy_container)
    * [How to use the tflite-debian container](#Using_the_container)

<div id="Docker_images">

## TFLite Docker Images

Two TensorFlow Lite Docker images are provided:

- Build Image (tflite_build):
  - Based on Debian Trixie Slim
  - Cross-compilation environment for ARM64 targets
  - Contains all build tools and dependencies

- Deploy Image (tflite_deploy_arm64):
  - Based on Debian Trixie Slim
  - Specifically for ARM64 architecture
  - Contains only the necessary runtime components for target devices

This separation allows for efficient development and cross-compilation on the host system while ensuring minimal deployment footprint to ARM64-based target devices.

<div id="tflite_build">

### tflite_build (cross-compilation environment)

    1. Start from Debian Trixie Slim
    2. Add ARM64 architecture support for cross-compilation
    3. Install build dependencies:
       - Cross-compilation toolchain (crossbuild-essential-arm64)
       - CMake, Ninja, Git, and other build tools
       - ARM64 libraries: libprotobuf-dev, libyaml-dev, libbsd-dev
    4. Clone TensorFlow Lite (v2.16.2) from GitHub
    5. Clone meta-qcom-distro and apply TFLite patches
    6. Clone and build dependencies:
       - Flatbuffers (v23.5.26)
       - Abseil-cpp (compatible with TFLite 2.16)
    7. Build and install FastRPC library (v1.0.6) for DSP acceleration
    8. Download and extract QNN SDK (optional, via TFLITE_ARG_QNP_VERSION):
       - Copy QNN headers to /usr/include
       - Copy QNN libraries for CPU, GPU, HTP, and DSP backends
       - Copy Hexagon DSP libraries (v66, v68, v73, v75)
    9. Build TensorFlow Lite with:
       - XNNPACK acceleration
       - GPU delegate support
       - Benchmark and label_image tools
    10. Install compiled binaries to deploy directory

<div id="tflite_deploy">

### tflite_deploy_arm64 (ARM64 runtime image)

    1. Start from ARM64 Debian Trixie Slim
    2. Install runtime dependencies:
       - libyaml-0-2 (for FastRPC)
       - bash-completion, nano (utilities)
    3. Add Qualcomm PPA and install Adreno GPU drivers (qcom-adreno1)
    4. Create 'tflite' user with qcom group membership
    5. Add user to video and kmem groups for device access
    6. Copy compiled TensorFlow Lite binaries and libraries from build stage
    7. Set file ownership and increase file descriptor limits
    8. Switch to non-root 'tflite' user for execution

<div id="Workflow">

## Workflow

<div id="How_to_build">

### How to build

Building tflite_deploy_arm64: minimal set of runtime binaries needed to execute TensorFlow Lite use-cases are available in this image.

#### Build without QNN SDK (TensorFlow Lite only):
```bash
docker build --target tflite_deploy_arm64 -t <desired-image-name> .
```

#### Build with QNN SDK support (optional):
```bash
docker build --build-arg TFLITE_ARG_QNP_VERSION=<version, e.g. 2.39.0.250925> --target tflite_deploy_arm64 -t <desired-image-name> .
```

**Note:** The QNN SDK integration is optional. If `TFLITE_ARG_QNP_VERSION` is not provided, the container will build successfully with TensorFlow Lite functionality only (CPU, GPU, and XNNPACK acceleration). To enable QNN delegate support with DSP/HTP acceleration, provide the QNN SDK version.

<div id="Running_the_container">

### Running the tflite deploy container

The TFLite container requires access to GPU devices and DSP accelerators.

In order to run the qairt container, please make use of the tflite arm64 deploy image built earlier and specify the 'host' network mode.

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

> **Note:** CDI files are located in and named: `tflite-debian/cdi/\<hardware\>-\<platform\>-tflite.json`;

The CDI file needed for a specific hardware platform needs to be copied to the /etc/cdi/ directory on the target device storage.

Please create this directory first, if it does not exist as follows:

```bash
sudo mkdir -p /etc/cdi
sudo chmod 755 /etc/cdi
```

> **Note:** the ENV files are located in and named: `tflite-debian/env/\<hardware\>-\<platform\>-qairt.env`;

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
export TFLITE_USER_CONTENTS_ROOT=/root

# For Ubuntu platforms — content stored under the ubuntu home directory
export TFLITE_USER_CONTENTS_ROOT=/home/ubuntu

# For any platform — content stored under /etc, independent of the OS type
export TFLITE_USER_CONTENTS_ROOT=/etc
```

Then create the required directories:

```bash
mkdir -p ${TFLITE_USER_CONTENTS_ROOT}/media
mkdir -p ${TFLITE_USER_CONTENTS_ROOT}/models
mkdir -p ${TFLITE_USER_CONTENTS_ROOT}/labels
mkdir -p ${TFLITE_USER_CONTENTS_ROOT}/configs
```

Apply the correct permissions to each directory and its contents.
> **Note:** Use `sudo` when the `TFLITE_USER_CONTENTS_ROOT` value is set to `/etc` for any non-root platform user:

```bash
# media
find ${TFLITE_USER_CONTENTS_ROOT}/media/ -type d -exec chmod 755 {} \;
find ${TFLITE_USER_CONTENTS_ROOT}/media/ -type f -exec chmod 644 {} \;

# models
find ${TFLITE_USER_CONTENTS_ROOT}/models/ -type d -exec chmod 755 {} \;
find ${TFLITE_USER_CONTENTS_ROOT}/models/ -type f -exec chmod 644 {} \;

# labels
find ${TFLITE_USER_CONTENTS_ROOT}/labels/ -type d -exec chmod 755 {} \;
find ${TFLITE_USER_CONTENTS_ROOT}/labels/ -type f -exec chmod 644 {} \;

# configs
find ${TFLITE_USER_CONTENTS_ROOT}/configs/ -type d -exec chmod 755 {} \;
find ${TFLITE_USER_CONTENTS_ROOT}/configs/ -type f -exec chmod 644 {} \;
```

**Before running the tflite arm64 deploy container, please upload your models and model-specific data into these newly created platform model data folders.**

<div id="Run_the_qairt_deploy_container">

### Commands to run the tflite deploy container:

> **Note:** If your platform and OS combo do not support adb connectivity, please use the onboard Ethernet/WLAN network to access the device over ssh and adapt the execution of the commands listed below accordingly.

Set the root path for the user content by exporting one of the following environment variables in a platform terminal, depending on your platform and preference:

```bash
# For QLI platforms — content stored under the root home directory
export TFLITE_USER_CONTENTS_ROOT=/root

# For Ubuntu platforms — content stored under the ubuntu home directory
export TFLITE_USER_CONTENTS_ROOT=/home/ubuntu

# For any platform — content stored under /etc, independent of the OS type
export TFLITE_USER_CONTENTS_ROOT=/etc
```

Push the CDI and ENV files and run the container.

```bash
adb push tflite-debian/cdi/<hardware>-<platform>-tflite.json /etc/cdi/tflite.json
adb push tflite-debian/env/<hardware>-<platform>-tflite.env /etc/docker/env/tflite.env
```

>**Note:** When the `TFLITE_USER_CONTENTS_ROOT` environment variable value is `/root` or `/home/ubuntu`** (the model content shall be mounted into the `/home/tflite/` folder inside the container):

Push the deploy Docker image to the device and load it

```bash
export TFLITE_DEVICE_TEST_PATH="<target_device_path>"
export TFLITE_DOCKER_IMAGE="<path_to_docker_image_file>"
adb shell mkdir -p "${TFLITE_DEVICE_TEST_PATH}"
adb push "${TFLITE_DOCKER_IMAGE}" "${TFLITE_DEVICE_TEST_PATH}/${TFLITE_DOCKER_IMAGE}"
adb shell docker load -i "${TFLITE_DEVICE_TEST_PATH}/${TFLITE_DOCKER_IMAGE}"
```

Now run the deploy Docker container

```bash
adb shell docker run -it -d --net host \
  --env-file /etc/docker/env/tflite.env \
  --device qualcomm.com/device=tflite \
  -v ${TFLITE_USER_CONTENTS_ROOT}/media:/home/tflite/media \
  -v ${TFLITE_USER_CONTENTS_ROOT}/models:/home/tflite/models \
  -v ${TFLITE_USER_CONTENTS_ROOT}/labels:/home/tflite/labels \
  -v ${TFLITE_USER_CONTENTS_ROOT}/configs:/home/tflite/configs \
  -h tflite --name tflite <desired-image-name>
```

> **Note:** When the `TFLITE_USER_CONTENTS_ROOT` environment variable value is `/etc`** (the model content shall be mounted into the `/etc/` folder inside the container):

```bash
adb shell docker run -it -d --net host \
  --env-file /etc/docker/env/tflite.env \
  --device qualcomm.com/device=tflite \
  -v ${TFLITE_USER_CONTENTS_ROOT}/media:/etc/media \
  -v ${TFLITE_USER_CONTENTS_ROOT}/models:/etc/models \
  -v ${TFLITE_USER_CONTENTS_ROOT}/labels:/etc/labels \
  -v ${TFLITE_USER_CONTENTS_ROOT}/configs:/etc/configs \
  -h tflite --name tflite <desired-image-name>
```

**What the CDI configuration provides:**
- GPU device access (`/dev/kgsl-3d0`)
- DMA heap access (`/dev/dma_heap/system`)
- FastRPC DSP access (`/dev/fastrpc-cdsp`)
- Environment variables for GPU acceleration:
  - `VK_DRIVER_FILES` - Vulkan driver configuration
  - `OCL_ICD_FILENAMES` - OpenCL driver path
  - `__EGL_VENDOR_LIBRARY_FILENAMES` - EGL vendor library
- Platform-specific DSP library mounts (e.g., `/usr/lib/dsp`)
- Device model information mount (`/run/device-model`)

<div id="Using_the_container">

### How to use the tflite-debian container

To execute a bash shell in the container:

```bash
docker exec -ti tflite bash
```

**Available tools in the container:**
- `benchmark_model` - TensorFlow Lite benchmark tool
- `label_image` - TensorFlow Lite image classification example
- TensorFlow Lite C/C++ libraries with GPU and XNNPACK delegates
- QNN delegate libraries (if built with QNN SDK support)

**Example usage:**
```bash
# Run benchmark on a TFLite model
docker exec -ti tflite benchmark_model --graph=/path/to/model.tflite

# Run label_image example
docker exec -ti tflite label_image --image=/path/to/image.jpg --model=/path/to/model.tflite
```
