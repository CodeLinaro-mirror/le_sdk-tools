# About The TensorFlow Lite Debian Docker Image

## Table of Contents

* [TFLite Docker Images](#Docker_images)
    * [tflite_build](#tflite_build)
    * [tflite_deploy_arm64](#tflite_deploy)
* [Workflow](#Workflow)
    * [How to build](#How_to_build)
    * [Running the tflite deploy container](#Running_the_container)
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

The TFLite container requires access to GPU devices and DSP accelerators. CDI (Container Device Interface) JSON files for specific platforms contain all necessary device mountings and environment variables. Additionally, environment variable files needed depending on your platform configuration.

**Setup steps:**

1. Copy the appropriate CDI & ENV file for your hardware platform to the device:
```bash
adb push cdi/<hardware>-<platform>-tflite.json /etc/cdi/tflite.json
```
   Example: `adb push cdi/qcs6490_qli_00_tflite.json /etc/cdi/tflite.json`

```bash
adb push env/<hardware>-<platform>-tflite.env /etc/docker/env/tflite.env
```
   Note: Create the `/etc/docker/env/` directory on the device if it does not exist.

3. Run the TFLite container with CDI device support:

   ```bash
   docker run -it -d --net host --env-file /etc/docker/env/tflite.env --device qualcomm.com/device=tflite -h tflite --name tflite <desired-image-name>
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
- Model, media, and labels directory mounts (`/etc/models`, `/etc/media`, `/etc/labels`)
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
