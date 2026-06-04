# About The QAIRT-Debian Docker Image

## Table of Contents

* [QAIRT Docker Images](#Docker_images)
    * [qairt_builder](#qairt_builder)
    * [python_builder](#python_builder)
    * [qairt_deploy_arm64](#qairt_deploy)
* [Workflow](#Workflow)
    * [How to build](#How_to_build)
    * [Running the qairt deploy container](#Running_the_container)
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

In order to run the qairt container with SNPE & QNN functionalities inside, it must be run from the qairt_deploy_arm64 image built earlier, container needs to be ran with 'host' network mode. GPU devices, and other needed user volumes need to be mounted. CDI json for the specific platform contains all of these needed platform mountings. Because of the basic design principles of Docker, an .env file is needed for the environment variables inside device container as well.

CDI files are located in: qairt-container/cdi/\<hardware\>-\<platform\>-qairt.json;
The CDI file needed for the specific hardware platform needs to be copied to /etc/cdi/ directory in device storage. (Create directory if it does not exist)

.env files are located in: qairt-container/env/\<hardware\>-\<platform\>-qairt.env;
The .env file needed for the specific hardware platform needs to be copied to /etc/docker/env/ directory in device storage. (Create directory if it does not exist)

Command to run the qairt device deploy container:

```bash
adb push qairt-container/cdi/<hardware>-<platform>-qairt.json /etc/cdi/qairt.json
adb push qairt-container/env/<hardware>-<platform>-qairt.env /etc/docker/env/qairt.env
docker run -it -d --net host --env-file /etc/docker/env/qairt.env --device qualcomm.com/device=qairt -h qairt --name qairt <desired-image-name>
```

<div id="Using_the_container">

### How to use the qairt-debian container

To execute a bash shell in container, run the following command:

```bash
docker exec -ti qairt bash
```
