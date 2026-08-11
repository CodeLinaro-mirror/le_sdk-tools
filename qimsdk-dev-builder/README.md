# QIMSDK Dev Builder

## Table of Contents

- [Overview](#overview)
- [Terminology](#terminology)
- [Deployment Scenarios](#deployment-scenarios)
- [Prerequisites](#prerequisites)
  - [Host Packages](#host-packages)
  - [Docker Setup](#docker-setup)
  - [ADB / SSH Device Access (optional)](#adb-ssh-device-access-optional)
- [Docker Images](#docker-images)
  - [Dbg Base Image (`qimsdk_dbg_image`)](#dbg-base-image-qimsdk_dbg_image)
  - [Builder Image (`qimsdk_dev_builder`)](#builder-image-qimsdk_dev_builder)
  - [App Deploy Image (`qimsdk_app_deploy`)](#app-deploy-image-qimsdk_app_deploy)
- [`targets/config.json` Reference](#targetsconfigjson-reference)
- [Host-Side Helper Scripts (`scripts-dbg/`)](#host-side-helper-scripts-scripts-dbg)
- [In-Container Helper Scripts (`scripts/`)](#in-container-helper-scripts-scripts)
- [Writing A New GStreamer Project](#writing-a-new-gstreamer-project)
- [Docker Host Clean Up](#docker-host-clean-up)
- [Important Notes](#important-notes)
- [Workflow](#workflow)
  - [Phase 0 — Identify The Project-To-Be-Built](#phase-0-identify-the-project-to-be-built)
  - [Phase 1 — Choose The Execution Host And Clone The Subproject](#phase-1-choose-the-execution-host-and-clone-the-subproject)
  - [Phase 2 — Install Prerequisites](#phase-2-install-prerequisites)
  - [Phase 3 — Configure The Target](#phase-3-configure-the-target)
  - [Phase 4 — Build The Builder Image](#phase-4-build-the-builder-image)
  - [Phase 5 — Run The Builder Container And Open A Shell](#phase-5-run-the-builder-container-and-open-a-shell)
  - [Phase 6 — Synchronize Code And Register The Build](#phase-6-synchronize-code-and-register-the-build)
  - [Phase 7 — Decide The Artifact Destination](#phase-7-decide-the-artifact-destination)
  - [Phase 8 — Deliver The Artifacts](#phase-8-deliver-the-artifacts)
  - [Function Reference By Phase](#function-reference-by-phase)

<div id="overview"></div>

## Overview

The purpose of `qimsdk-dev-builder` is to provide a disposable, aarch64 cross-compilation builder
container for bringing in a new project and compiling it as a CMake project configured against nothing but the plain upstream
`gst-plugins-base`/`-good`/`-bad` **headers** and the App Builder SDK.

The build is a fast, incremental **CMake** configure/compile/install cycle. Once artifacts are produced, the
project's host-side scripts can push them directly onto a target device's root filesystem or into
a deploy container, or package an app into an app deploy image.

This plugin-or-app **project-to-be-built is the entire reason the
builder container exists**: every image, script, config field and workflow phase documented below
exists solely to configure, compile and deliver that one project.

The core goal is therefore a **minimal** builder image: only a basic, baseline set of GStreamer
dependencies needed to configure and cross-compile against is installed - never a full GStreamer
distribution, and never anything specific to a particular project. Build the builder image, run
the builder container from it, and that container is the whole environment; if the
project-to-be-built needs dependencies beyond that basic baseline, they are **not** added to the
builder image - Additional dependencies need to be installed by hand inside the running builder container instead, every time (see [Important Notes](#important-notes)).

This document first covers the project's images, scripts and configuration fields topically; the
closing [Workflow](#workflow) chapter sequences them into a single end-to-end procedure - from
identifying what should be built through to delivered artifacts.

<div id="terminology"></div>

## Terminology

Every image, container and machine in this document is referred to by exactly one name, defined
below. The literal Docker names they map to are fixed by the scripts; never derive them any other
way. In those names, `<Additional_tag_image>` and `<Additional_tag_container>` are the values of the
config fields of the same name (see [`targets/config.json` Reference](#targetsconfigjson-reference)).

- **Subproject** - the `qimsdk-dev-builder` project itself: a standalone build environment,
  distinct from whatever is actually being compiled inside it.
- **Project-to-be-built** - the CMake-based GStreamer project - a **plugin**, an **app**, or
  both - that is the actual objective of a session: a new, independent
  project (see [Writing A New GStreamer
  Project](#writing-a-new-gstreamer-project)). Bringing up the builder container - every
  image, script and workflow phase in this document - exists only in service of building this one
  project; none of it is an end in itself.
- **Builder image** - the image the project-to-be-built is compiled in: the `qimsdk_dev_builder`
  target of `Dockerfile`. Tagged `qimsdk-<Additional_tag_image>`.
- **Builder container** - the running instance of the builder image, started by
  `builder-docker-run-container`. Named `qimsdk[-<Additional_tag_container>]_builder`.
- **Dbg base image** - the intermediate image `builder-docker-build-image` builds first from
  `Dockerfile.dbg` (target `qimsdk_dbg_image`, tagged `qimsdk-<Additional_tag_image>-dbgbase`),
  only so the builder image can fetch the local `qimsdk` checkout. Never run as a container.
- **Execution host** - the machine that runs the builder container: either a build PC or the
  embedded target device itself.
- **Target device** - the machine that ultimately receives the built artifacts. Equal to the
  execution host when the builder container runs directly on-device.
- **Deploy container** - a container **already running** on the target device, named by
  `Target_deploy_container_name`, that artifacts are pushed into by
  `builder-push-artifacts-docker[-dbg]`, as an alternative to writing onto the device's root
  filesystem directly.
- **qimsdk-debian deploy image** - the runtime image built by the separate qimsdk-debian project
  (its `qimsdk_deploy_arm64` target). Never built here; only ever used as the base of the app
  deploy image.
- **App deploy image** - the qimsdk-debian deploy image with the app binary added: the
  `qimsdk_app_deploy` target of `Dockerfile`. Tagged `qimsdk-deploy-<Additional_tag_image>`.
- **App service** - the container the app deploy image runs as on the target device, started by
  `docker compose` from a copy of `deploy-container.yml`. Named after the service in that copy.
  Distinct from a deploy container: nothing is pushed into it after it starts.
- **Release / debug variant** - the two artifact sets the builder container installs: stripped
  (`QIMSDK_INSTALL_DIR`, `/mnt/work/deploy`) and unstripped (`QIMSDK_INSTALL_DEBUG_DIR`,
  `/mnt/work/deploy_dbg`). The `-dbg` suffix of a function name - `builder-push-artifacts-device-dbg`,
  `builder-save-artifacts-dbg` - always means the debug variant.

<div id="deployment-scenarios"></div>

## Deployment Scenarios

The execution host chosen (see [Workflow](#workflow), Phase 1) and the artifact destination chosen
(Phase 7) combine into four possible scenarios. The `builder-push-artifacts-*` functions
(Phase 8) behave identically regardless of which is in effect - they are host-side functions that
resolve `Target_device_ID`/`Target_deploy_container_name` from the config each time. What changes
across the four scenarios below is only *where* "the host" is and what `Target_device_ID` is set
to.

**Build machine, pushing to the device's root filesystem.** `qimsdk-dev-builder` lives on an
Ubuntu 24 PC (x86 or ARM). `builder-docker-build-image` / `-run-container` run on the PC.
`Target_device_ID` is set to the device's adb serial or ssh target address.
`builder-push-artifacts-device[-dbg]` fetches the tarball from the builder container into a host staging
directory, then pushes it to the device over adb (serial) or ssh+rsync (IPv4) and extracts it onto
the device's `/`.

**Build machine, pushing to a deploy container on the device.** Same as above, but
`Target_deploy_container_name` is also set. `builder-push-artifacts-docker[-dbg]` pushes the
tarball to the device the same way, then runs `docker cp` on the device (via
`builder-device-command`) to land it inside that deploy container.

**Builder container running on the device itself, pushing to its own root filesystem.**
`qimsdk-dev-builder` and the builder container run directly on the embedded target device (QLI 2.0 or
Ubuntu Desktop/Server, arm64). `Target_device_ID` is set to `"localhost"`.
`builder-push-artifacts-device[-dbg]` detects this and skips adb/ssh entirely - it `cp -a`s the
staged `usr/` tree straight onto `/` (with `sudo` if not already root).

**Builder container running on the device itself, pushing to a deploy container on the device.** Same as
above, with `Target_deploy_container_name` set. `builder-push-artifacts-docker[-dbg]` runs
`docker cp` directly against the local docker daemon - no adb/ssh hop, since the deploy container
is already running on the same machine.

<div id="prerequisites"></div>

## Prerequisites

<div id="host-packages"></div>

### Host Packages

The execution host (the build PC, or the target device itself if the builder container runs
directly on it - see
[Deployment Scenarios](#deployment-scenarios)) needs:

```bash
sudo apt install -y jq rsync
```

- `jq` - every host-side script in `scripts-dbg/docker_env_setup.sh` parses `targets/config.json`
  with it.
- `rsync` - used both to stage the local `qimsdk` checkout into the dbg base image build context
  and to transfer saved artifacts.

<div id="docker-setup"></div>

### Docker Setup

A working Docker Engine installation (with BuildKit) is required on whichever machine actually
runs the builder container - the build PC, or the target device itself (see
[Deployment Scenarios](#deployment-scenarios)). The installation method depends on the platform:

| Platform | Role | Install |
|---|---|---|
| Ubuntu x86 PC | Build machine | Docker CE repository packages (below) |
| Ubuntu arm64 PC | Build machine | Docker CE repository packages (below); the repository command already resolves architecture via `dpkg --print-architecture` |
| Ubuntu embedded target device | Container runs on-device | Distribution packages: `docker.io docker-buildx` |
| QLI 2.0 embedded target device | Container runs on-device | Preinstalled; no action required |

**Ubuntu x86/arm64 PC** - install the upstream Docker CE packages if not already present:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Allow the current user to run docker without sudo
sudo groupadd -f docker
sudo usermod -aG docker $USER
newgrp docker
```

**Ubuntu embedded target device** - the lighter Ubuntu-repo packages are enough; no need to add
Docker's own APT repo:

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-buildx
```

**QLI 2.0 embedded target device** - Docker comes preinstalled; skip this section entirely.

Verify with:

```bash
docker run hello-world
```

<div id="adb-ssh-device-access-optional"></div>

### ADB / SSH Device Access (optional)

Required only when the execution host is a build PC distinct from the target device, to deliver
built artifacts to that device with the `builder-push-artifacts-*` functions. Not needed when the
container runs directly on the target device, where `Target_device_ID` is `"localhost"` and every
push happens locally. Skip this section entirely when building and inspecting artifacts locally is
sufficient.

**Over USB (adb):**

```bash
sudo apt update
sudo apt install -y adb fastboot android-sdk-platform-tools-common
sudo usermod -aG plugdev $USER
sudo udevadm control --reload-rules && sudo udevadm trigger
# unplug/replug the device, then:
adb start-server
adb devices
```

> The `android-sdk-platform-tools-common` package ships udev rules covering the VID/PID of most
> Android/Qualcomm devices and assigns their USB device nodes to the `plugdev` group - which is why
> adding the current user to `plugdev` is enough to get non-root access, without hand-authoring a
> per-device udev rule.

**Over the network (ssh):** ensure passwordless (key-based) SSH login works to the target device
and that its IPv4 address is reachable from the host; `Target_device_ID` set to that address is
what makes every host-side function in this project route over ssh/rsync instead of adb.

<div id="docker-images"></div>

## Docker Images

Building the environment (`builder-docker-build-image`, see
[Host-Side Helper Scripts](#host-side-helper-scripts-scripts-dbg)) produces two images, built in
sequence: the dbg base image, then the builder image. A third, the
[app deploy image](#app-deploy-image-qimsdk_app_deploy), is built separately, by hand, only when an
app is to run as an app service:

<div id="dbg-base-image-qimsdk_dbg_image"></div>

### Dbg Base Image (`qimsdk_dbg_image`)

Built from `Dockerfile.dbg` and tagged `qimsdk-<Additional_tag_image>-dbgbase`. Its only job is to
make the local `qimsdk` checkout look like it lives at its real GitHub URL, so the builder image
can fetch it with an ordinary `git fetch`. Nothing ever runs a container from it:

1. Bases on `debian:trixie-slim`.
2. Copies the local `qimsdk` checkout - staged beforehand into
   `tmp/qimsdk` by `builder-docker-build-initialize` - into
   `${QIMSDK_REPO_DOWNLOAD_DIR}/qimsdk`.
3. Adds a `git` `insteadOf` rule in `/etc/gitconfig` so that any
   `https://github.com/qualcomm/qimsdk.git` remote resolves to that local copy instead
   of the internet.

<div id="builder-image-qimsdk_dev_builder"></div>

### Builder Image (`qimsdk_dev_builder`)

Built from `Dockerfile` and tagged `qimsdk-<Additional_tag_image>`, then **rebased** at build time
(via `builder-docker-build-builder-dev-image`, which rewrites the `FROM` line with `sed`) onto the
dbg base image above - so its `git insteadOf` rule is already in effect by the time the builder
image fetches `qimsdk`. The dependencies installed here (step 1 below) are the **basic, baseline set** referred
to throughout this document - just enough to configure and cross-compile a plain GStreamer plugin
or app; anything a specific project-to-be-built needs beyond it is never added
here, only installed by hand later in the running builder container (see [Important
Notes](#important-notes)):

1. Adds the `arm64` dpkg architecture and installs the `crossbuild-essential-arm64` toolchain,
   plus `arm64` GStreamer/GLib/json-glib dev packages and the App Builder SDK (cpp) dependency
   (`libyaml-cpp-dev:arm64`).
2. Adds the Qualcomm IoT PPA as a `deb-src`-only source and `apt source`s `gst-plugins-base1.0`,
   `gst-plugins-good1.0` and `gst-plugins-bad1.0` - source only, never compiled, purely to satisfy
   `qimsdk`'s (specifically its nested `gstreamer/gst-plugin-base` component) CMake configure step
   later.
3. `git init`s each of the three fetched source trees so QTI's patches (applied next) can be
   tracked and diffed.
4. Fetches `gst-qti-oss-patches` (pinned to the fetched `gst-plugins-base` version) and
   `qimsdk` (pinned to the optional `QIMSDK_Source_git_tag` /
   `QIMSDK_ARG_GST_PLUGINS_TAG` build-arg, or `main` if unset) - the latter resolves to the local
   checkout via the `insteadOf` rule from the dbg base image.
5. Copies in `scripts/` (see [In-Container Helper Scripts](#in-container-helper-scripts-scripts))
   and sources `env_setup.sh` from `/root/.bashrc`.
6. Applies all QTI patches (`builder-apply-patches`) to the base/good/bad source trees.
7. Copies only the `.h` headers (not full builds) from base/good/bad into
   `/usr/include/gstreamer-1.0/`, then deletes the source trees entirely - the CMake build only
   ever needs these headers to configure against.
8. Runs `builder-incremental-build` to configure, compile and install `qimsdk` (via its
   `-DENABLE_GST_PLUGIN_BASE=ON` CMake option, which builds the nested `gstreamer/gst-plugin-base`
   component), then the App Builder SDK (cpp) library standalone from a stripped copy of
   `qimsdk/cpp` (skipping its bundled examples) - requiring `libyaml-cpp-dev:arm64`, installed
   above.

<div id="app-deploy-image-qimsdk_app_deploy"></div>

### App Deploy Image (`qimsdk_app_deploy`)

A second, independent target in `Dockerfile`, tagged `qimsdk-deploy-<Additional_tag_image>`: the
qimsdk-debian deploy image with the app built in the builder container layered on top, so the app
can run as an app service on the target device. It is never built by `builder-docker-build-image` or
CI, and building any other target skips it without touching the qimsdk-debian deploy image.

It does only one thing: copy every file in the `ARTIFACT_INSTALL/` directory of the build context
into `/usr/bin/` of the qimsdk-debian deploy image, with mode `0755`. Everything else - the runtime,
entrypoint, `qimsdk` user - comes unchanged from it.

| Build arg | Required | Description |
|---|---|---|
| `QIMSDK_ARG_DEPLOY_BASE_IMAGE` | **Mandatory** | The qimsdk-debian deploy image to base on (its `qimsdk_deploy_arm64` target), as a registry reference or local tag. Left unset, the build fails on the placeholder `qimsdk-deploy-base-image-not-set`. |
| `QIMSDK_ARG_ARTIFACT_INSTALL` | Optional | Directory in the build context holding the binaries. Defaults to `ARTIFACT_INSTALL`. |
| `QIMSDK_ARG_DEPLOY_PLATFORM` | Optional | Platform of the qimsdk-debian deploy image. Defaults to `linux/arm64`, so x86 hosts build it too without looking for an amd64 variant. |

Build it from the repo root, once the app is built and installed in the running builder container
(see [Phase 6](#phase-6-synchronize-code-and-register-the-build)):

```bash
# 1. Stage only the app binary - the stripped release copy - into ARTIFACT_INSTALL
rm -rf ARTIFACT_INSTALL && mkdir ARTIFACT_INSTALL
docker cp qimsdk[-<Additional_tag_container>]_builder:/mnt/work/deploy/usr/bin/<app-binary> ARTIFACT_INSTALL/

# 2. Get the qimsdk-debian deploy image (docker login <registry> first, if it is private)
docker pull <qimsdk-debian-deploy-image>

# 3. Build and tag the app deploy image
docker build --target qimsdk_app_deploy                                                    \
    --build-arg QIMSDK_ARG_DEPLOY_BASE_IMAGE=<qimsdk-debian-deploy-image>                  \
    -t qimsdk-deploy-<Additional_tag_image> .

# 4. Check every runtime library of the app resolves in it (no "not found" lines)
docker run --rm --entrypoint ldd qimsdk-deploy-<Additional_tag_image> /usr/bin/<app-binary>
```

Only executables belong in `ARTIFACT_INSTALL/`: a plugin `.so` copied there would land in
`/usr/bin/`, where GStreamer never loads it. To run the app deploy image as an app service, see
[Phase 8](#phase-8-deliver-the-artifacts), "Running the app as an app service".

<div id="targetsconfigjson-reference"></div>

## `targets/config.json` Reference

Every host-side function takes a `<path-to-config-json>` argument pointing at a file with this
shape (see `targets/config.json` for the placeholder template):

| Field | Required | Description |
|---|---|---|
| `Additional_tag_container` | Optional | Suffix of the builder container name: `qimsdk[-<tag>]_builder`. Empty gives `qimsdk_builder`. |
| `Additional_tag_image` | **Mandatory** | Suffix of the builder image name: `qimsdk-<tag>`. Also names the dbg base image (`qimsdk-<tag>-dbgbase`) and the app deploy image (`qimsdk-deploy-<tag>`). The key must be present: a missing key yields the image name `qimsdk-null`. |
| `Docker_image_path` | **Mandatory** | Local directory (or `user@host:/path` rsync target) artifacts are saved to. When local, it is bind-mounted straight into the builder container. |
| `Target_device_ID` | Optional | adb serial, IPv4 address, or `"localhost"` when the builder container itself runs on the target device. Empty/unset falls back to whatever single device adb can see. |
| `Target_deploy_container_name` | Optional | Name of the deploy container running on the target device; required only by the `builder-push-artifacts-docker[-dbg]` functions. Not used for an app service. |
| `QIMSDK_Source_Dir` | **Mandatory** | Path to the local `qimsdk` checkout (a `.git` directory or a `gstreamer/gst-plugin-base` subdirectory must be present). Supports `~`. |
| `QIMSDK_Source_git_tag` | Optional | Git tag/branch/commit of `qimsdk` to fetch into the builder image; defaults to `main`. |
| `MAX_build_cpu_threads` | Optional | Caps build parallelism; must be `1..$(nproc)`. Defaults to `nproc`. |

Copy the template per target/user rather than editing it in place, e.g. `targets/my_target.json`,
to avoid collisions if more than one person builds from the same checkout.

<div id="host-side-helper-scripts-scripts-dbg"></div>

## Host-Side Helper Scripts (`scripts-dbg/`)

Run on the execution host (the build machine, or the target device itself when the builder
container runs there) - never copied into the builder image, except for `common.sh`, which is also
copied into `Dockerfile` for the adb/ssh transport helpers it provides (unused today from inside the
builder container, since artifact pushing now happens entirely on the host). The `-dbg` in the
directory name is historical: these scripts drive the builder image and builder container.

In order for these functions to be available, the script must be sourced:

```bash
cd qimsdk-dev-builder
source scripts-dbg/docker_env_setup.sh
```

- **`common.sh`** - transport-agnostic device access, shared by scripts on both sides:
  - `builder-device-transport <device-id> <out-var>` - decides `adb` vs `ssh`: ssh for IPv4
    addresses or when adb is not installed or does not see the device, adb otherwise.
  - `builder-cmd <device-id> shell|push|pull ...` - transparent adb/ssh (rsync-over-ssh for
    push/pull) wrapper.
  - `builder-device-command <device-id> <cmd>` - runs a remote command and faithfully propagates
    its exit code (adb shell's own exit status is not reliable).
  - `builder-device-prepare <device-id>` - post-reboot device prep: `adb root`/`remount` (adb) or
    remount + `setenforce 0` + clock sync (ssh).
  - `builder-is-ipv4` / `builder-is-adb-serial` - input validators.
- **`docker_env_setup.sh`** - config parsing, image build/run, and artifact push:
  - `builder-get-container-and-image-name`, `builder-get-device-id`, `builder-get-deploy-container-name`,
    `builder-get-docker-image-path`, `builder-get-max-build-jobs`, `builder-get-qimsdk-tag` -
    read/validate the corresponding `targets/config.json` field.
  - `builder-docker-build-image <path-to-config-json>` - builds the dbg base image, then the
    builder image, described in [Docker Images](#docker-images).
  - `builder-docker-run-container <path-to-config-json>` - runs the builder container
    (`--net host`, named `qimsdk[-<Additional_tag_container>]_builder`), bind-mounts `Docker_image_path` into it at the
    identical path when it is a local directory (so artifact saves land on the host with no extra
    copy step), passes through `QIMSDK_DEVICE_ID`/`QIMSDK_DEPLOY_CONTAINER_NAME`/`WORK_ENVIRONMENT`,
    passes through `/dev/bus/usb` when present, and copies the host's `~/.ssh`, `~/.gitconfig` and
    `/etc/gitconfig` into the builder container.
  - `builder-push-artifacts-device[-dbg] <path-to-config-json>` - triggers the save step in the
    builder container, then pushes the release/debug variant tarball onto the target device's root filesystem (see
    [Deployment Scenarios](#deployment-scenarios) for exactly how, per environment).
  - `builder-push-artifacts-docker[-dbg] <path-to-config-json>` - same, but into the deploy
    container named by `Target_deploy_container_name`.
  - `builder-docker-images-cleanup` - removes dangling images and prunes the build cache on
    the host (see [Docker Host Clean Up](#docker-host-clean-up)).

<div id="in-container-helper-scripts-scripts"></div>

## In-Container Helper Scripts (`scripts/`)

Copied into the builder image and sourced from `/root/.bashrc` via `env_setup.sh`, so every
function below is available in any interactive or `docker exec` shell in the builder container.

- **`env_setup.sh`** - sources every other `*.sh` in `scripts/`, then executes any arguments
  passed to it as a command. This is what lets `docker exec ... bash -c 'source .../env_setup.sh
  <function> <args>'` run a single helper non-interactively (used by the host-side artifact-push
  functions above).
- **`setup.sh`**
  - `builder-setup-crosscompilation` - exports the full `aarch64-linux-gnu` cross toolchain
    (`CC`/`CXX`/`LD`/`AR`/... , hardened `CFLAGS`/`LDFLAGS`, `PKG_CONFIG_PATH`, and
    `CMAKE_BUILD_PARALLEL_LEVEL` from `QIMSDK_MAX_JOBS`).
  - `builder-apply-patch <patch-file>` - strips legal-notice header comments from a `.patch` file
    and applies it with `git am`.
  - `builder-apply-patches` / `-gst-plugins-base` / `-good` / `-bad` - applies every `*.patch` from
    `gst-qti-oss-patches` against the corresponding `apt source`d tree.
- **`build.sh`**
  - `builder-cmake-configure/-compile/-install <source> <target> [flags]` - individual CMake
    configure/build/install steps, logged to `${QIMSDK_LOGS_DIR}`.
  - `builder-cmake-build <source> <install-path> [flags]` - configure + compile + install wrapper.
    This is the function which is used to build the source of the project-to-be-built
  - `builder-cmake-build-qimsdk` - builds `qimsdk` with `-DENABLE_GST_PLUGIN_BASE=ON`, then the
    App Builder SDK (cpp). **This is the function to extend** with additional
    `-DENABLE_GST_PLUGIN_<name>=ON` flags (or additional `builder-cmake-build` calls) as new
    plugins are added - see [Writing A New GStreamer Project](#writing-a-new-gstreamer-project).
  - `builder-cmake-clean-qimsdk` - removes the CMake build directory.
  - `builder-incremental-build` - calls `builder-cmake-build-qimsdk`; this is what both
    the builder image build and manual rebuilds in the builder container call.
- **`dev_sync.sh`**
  - `builder-save-artifacts-variant <release|debug>` - tars up `QIMSDK_INSTALL_DIR` (release)
    or `QIMSDK_INSTALL_DEBUG_DIR` (debug) and rsyncs the tar to `QIMSDK_DOCKER_IMAGE_PATH`. Only
    ever invoked from the host, via `docker exec`, by `builder-fetch-saved-artifacts` - it is
    never called directly from inside the builder container.
  - `builder-save-artifacts` / `-save-artifacts-dbg` - release/debug variant wrappers.

<div id="writing-a-new-gstreamer-project"></div>

## Writing A New GStreamer Project

This is the primary reason the project exists: the builder container is a self-contained,
disposable environment for developing **any** CMake-based GStreamer project - a **plugin** against the plain
upstream `gst-plugins-base`/`-good`/`-bad` headers, a C GStreamer **app** or an **app** against the App Builder SDK
(`qti::Pipeline`, `qti::Element`), or both - `qimsdk` is only the one project it ships pre-wired to
build, not the sole target it supports. Whatever this project turns out to be, it is the sole
reason to bring up the builder container in the first place - the whole point of every phase in
[Workflow](#workflow) is getting this one project built and its artifacts delivered.

The builder image only ever ships the basic, baseline dependency set described in [Docker
Images](#docker-images). If the project needs anything beyond plain GStreamer headers and the App
Builder SDK, install it by hand inside the running builder container first - see [Important
Notes](#important-notes).

1. Add the new project's source and a top-level `CMakeLists.txt` under a new directory
   `${QIMSDK_SRC_DIR}/<new-project>` (i.e. `/mnt/work/src/<new-project>`) inside the builder container -
   either as a new subdirectory of the existing `qimsdk` checkout at `${QIMSDK_REPO_DIR}`, or as a
   completely independent project directory. Either way, the `CMakeLists.txt` only needs to find
   GStreamer via `pkg-config`/`find_package` - the headers it needs are already installed system-wide
   under `/usr/include/gstreamer-1.0/` (plus, for an app, the App Builder SDK headers - see
   above).
2. Once that source directory and its `CMakeLists.txt` backbone exist under
   `${QIMSDK_SRC_DIR}/<new-project>`, build it directly with the existing CMake helpers in
   `scripts/build.sh`, without touching anything else:

   ```bash
   builder-cmake-build ${QIMSDK_SRC_DIR}/<new-project> /usr <-Dcustom-build-flags>
   ```

   `<-Dcustom-build-flags>` stands for any project-specific `-D<OPTION>=<VALUE>` CMake flags the
   new project's `CMakeLists.txt` defines (e.g. feature toggles); it's optional - omit it entirely
   if the project needs none. `builder-cmake-build` configures, compiles and installs in one call,
   cross-compiling for `aarch64` with the same hardened `CFLAGS`/`LDFLAGS` used throughout this
   project, and logs each step to `${QIMSDK_LOGS_DIR}`.
3. For the project to build automatically every time `builder-incremental-build` runs (e.g. so it
   is included whenever the builder image itself is rebuilt), add a call for it inside
   `builder-cmake-build-qimsdk` in `/mnt/work/scripts/build.sh`:

   ```bash
   function builder-cmake-build-qimsdk() {
       builder-cmake-build ${QIMSDK_SRC_DIR}/qimsdk /usr -DENABLE_GST_PLUGIN_BASE=ON            && \
       builder-cmake-build ${QIMSDK_SRC_DIR}/<new-project> /usr <-Dcustom-build-flags>          && \
           print-green "${FUNCNAME} completed successfully!"
   }
   ```

   If the project is instead an extra plugin *within* `qimsdk`'s own CMake project,
   add its `-DENABLE_GST_PLUGIN_<name>=ON` option to `qimsdk`'s top-level
   `CMakeLists.txt` (default `OFF`) and pass `=ON` for it on the existing
   `builder-cmake-build ${QIMSDK_SRC_DIR}/qimsdk /usr ...` line instead of adding a
   separate call.
4. From this point on, `builder-incremental-build` rebuilds everything - the new project included -
   and build/save/push proceeds unchanged (see [Workflow](#workflow), Phase 6 onward).

<div id="docker-host-clean-up"></div>

## Docker Host Clean Up

Repeated image builds accumulate dangling intermediate images and BuildKit cache on the host. Once
a given build's cache is no longer needed (e.g. after confirming a build), reclaim the space with:

```bash
builder-docker-images-cleanup
```

This removes any dangling (`<none>`) images and prunes the BuildKit build cache.

<div id="important-notes"></div>

## Important Notes

- **`Docker_image_path` and the bind mount.** When `Docker_image_path` is a local directory (no
  `:` in the value), `builder-docker-run-container` bind-mounts it into the builder container at
  the identical path and overrides `QIMSDK_DOCKER_IMAGE_PATH` to match, so
  `builder-save-artifacts-variant`'s output is immediately visible on the host - no
  `docker cp` needed. When it is a remote rsync target (`user@host:/path`), no bind mount is
  possible; the save step's own `rsync` handles getting the tarball to that remote path instead,
  and `builder-fetch-saved-artifacts` would need a local path to read from - remote
  `Docker_image_path` values are for the release/manual `rsync` workflow, not for the
  `builder-push-artifacts-*` functions.
- **`Target_device_ID: "localhost"`** is the signal used throughout `scripts-dbg/` to mean "the
  builder container already runs on the target device" - it switches every push function from
  adb/ssh to a local `cp -a` / `docker cp`, and is also exported into the builder container as
  `WORK_ENVIRONMENT=target_device` (vs `build_machine`) for reference, though nothing inside the
  builder container currently consumes it. It is **not** accepted by `builder-cmd` /
  `builder-device-command`, which need a real adb serial or IPv4 address.
- **SSH/git identity propagation.** `builder-docker-run-container` copies the host's
  `~/.ssh/*` (except `known_hosts`), `~/.gitconfig` and `/etc/gitconfig` into the builder container
  on every run, so git operations and ssh/rsync transport work out of the box using the host user's
  own credentials.
- **Headers only, not full builds.** `gst-plugins-base`/`-good`/`-bad` are only ever `apt
  source`d for their headers, then deleted - this project never builds those packages themselves,
  and never builds anything beyond what is explicitly configured via CMake, whether by
  `qimsdk` or by a project added under [Writing A New GStreamer
  Project](#writing-a-new-gstreamer-project).
- **Minimal builder image - install extra dependencies as needed.** The builder image deliberately
  ships only a basic, baseline toolchain/headers set - plain GStreamer headers plus the App
  Builder SDK dependency (see [Docker Images](#docker-images)) - needed to configure and
  cross-compile a plugin or an app, never a full GStreamer distribution and never anything
  specific to a particular project-to-be-built. This baseline is always the same, regardless of
  what is actually being built. If the project-to-be-built needs anything beyond it, that is
  **always** installed by hand, never added to the builder image: the running builder container has
  both `apt` and network access, so install it the normal way, e.g.
  `docker exec qimsdk[-<Additional_tag_container>]_builder apt-get install -y <package>` (or
  interactively via `docker exec -it qimsdk[-<Additional_tag_container>]_builder bash`).
  This only persists in that builder container, not in the builder image - if the builder container
  is later removed and a fresh one started (`builder-docker-run-container` again), reinstall
  anything added this way.

<div id="workflow"></div>

## Workflow

Each phase below states its objective, the decision (if any) gating it, and the commands to run.
Full explanatory detail for each phase lives in the chapters above; this chapter sequences them
into a single procedure - from identifying what should be built through to delivered artifacts.

| Phase | Objective |
|---|---|
| 0 | Identify the project-to-be-built |
| 1 | Choose the execution host and clone the subproject |
| 2 | Install prerequisites |
| 3 | Configure the target |
| 4 | Build the builder image |
| 5 | Run the builder container and open a shell |
| 6 | Synchronize code and register the build |
| 7 | Decide the artifact destination |
| 8 | Deliver the artifacts |

<div id="phase-0-identify-the-project-to-be-built"></div>

### Phase 0 — Identify The Project-To-Be-Built

Before any setup step, establish what the session's build target actually is - see
[Terminology](#terminology): the entire container exists only to build this one project.
Establish where the source of the project to be built lies - path in local storage or a git repo.

- **A new plugin or app project** - a project not yet part of `qimsdk`, built the same way,
  against the same upstream GStreamer headers and, for a CPP app, the App Builder SDK (see
  [Writing A New GStreamer Project](#writing-a-new-gstreamer-project)).

This decision has no bearing on Phases 1-5 (environment setup is identical either way); it
determines how Phase 6 is carried out.

<div id="phase-1-choose-the-execution-host-and-clone-the-subproject"></div>

### Phase 1 — Choose The Execution Host And Clone The Subproject

Decision: where should the builder container run?

- **On a build PC (x86 or arm64)** - the builder container runs on a machine separate from the target
  device; a physically distinct device, or a deploy container running on it, receives the
  artifacts over adb/ssh (see [Deployment Scenarios](#deployment-scenarios)). Clone the subproject
  onto that PC:

  ```bash
  git clone <qimsdk-dev-builder-repo-url> qimsdk-dev-builder
  cd qimsdk-dev-builder
  ```

- **On the target device itself** - the builder container runs directly on the embedded target (QLI 2.0
  or Ubuntu, arm64); artifacts are delivered locally, with `Target_device_ID` set to
  `"localhost"` (see [Deployment Scenarios](#deployment-scenarios)). Clone the subproject directly
  onto the device, using the same command as above, executed on the device instead of a PC.

This decision fixes which machine every subsequent phase runs on, and whether Phase 2's ADB/SSH
prerequisite applies.

<div id="phase-2-install-prerequisites"></div>

### Phase 2 — Install Prerequisites

Install `jq`, `rsync`, Docker Engine and, if the execution host is a build PC distinct from the
target device, ADB/SSH access - see [Prerequisites](#prerequisites) for the exact,
platform-dependent commands.

<div id="phase-3-configure-the-target"></div>

### Phase 3 — Configure The Target

Copy the config template per target/user rather than editing it in place:

```bash
cp targets/config.json targets/my_target.json
# ... edit targets/my_target.json ...
```

Fill in the fields relevant to Phase 1's decision and Phase 7's (not yet made) decision - see
[`targets/config.json` Reference](#targetsconfigjson-reference) for the full field-by-field
specification.

<div id="phase-4-build-the-builder-image"></div>

### Phase 4 — Build The Builder Image

```bash
source scripts-dbg/docker_env_setup.sh
builder-docker-build-image targets/my_target.json
```

Builds, in sequence, the dbg base image and the builder image described under
[Docker Images](#docker-images).

**Manual equivalent.** Skips `builder-docker-build-image` and builds the builder image directly
from `Dockerfile`, without the dbg base image / rebase step described under
[Docker Images](#docker-images). Tag it with the same name the config gives, or
`builder-docker-run-container` will not find it:

```bash
docker build --target qimsdk_dev_builder . -t qimsdk-<Additional_tag_image>                        \
    --build-arg QIMSDK_ARG_MAX_JOBS=$(nproc)                                                       \
    --build-arg QIMSDK_ARG_GST_PLUGINS_TAG=
```

> **Building this way does NOT build custom `qimsdk`/`gst-plugin-base` code.** Skipping
> the dbg base image also skips its `git insteadOf` redirect, so `qimsdk` is always
> fetched from the real `github.com/qualcomm/qimsdk` (pinned to
> `QIMSDK_ARG_GST_PLUGINS_TAG`, or `main` if left empty) - never from the local
> `QIMSDK_Source_Dir` checkout configured in `targets/config.json`, committed or not. Use
> `builder-docker-build-image` instead whenever a local `qimsdk` checkout needs to be
> picked up.

<div id="phase-5-run-the-builder-container-and-open-a-shell"></div>

### Phase 5 — Run The Builder Container And Open A Shell

```bash
builder-docker-run-container targets/my_target.json
docker exec -it qimsdk[-<Additional_tag_container>]_builder bash
```

See [Host-Side Helper Scripts](#host-side-helper-scripts-scripts-dbg) for exactly what
`builder-docker-run-container` sets up inside the builder container.

<div id="phase-6-synchronize-code-and-register-the-build"></div>

### Phase 6 — Synchronize Code And Register The Build

Inside the builder container shell opened in Phase 5:

- **Project-to-be-built = a new plugin or app project** - add its source and register it,
  following [Writing A New GStreamer
  Project](#writing-a-new-gstreamer-project).

```bash
# If inside the builder container shell, and project-to-be-built is a git repo:
cd ${QIMSDK_SRC_DIR} && git clone <url-of-project-to-be-built>

# If project-to-be-built is a directory on the build machine
docker cp <path-to-project-to-be-built> qimsdk[-<Additional_tag_container>]_builder:/mnt/work/src/
```

<div id="phase-7-decide-the-artifact-destination"></div>

### Phase 7 — Decide The Artifact Destination

Decision: once artifacts build cleanly, where do they go?

- **The target device's root filesystem** - no further config field required beyond
  `Target_device_ID` (Phase 3).
- **A deploy container already running on the target device** - additionally requires
  `Target_deploy_container_name` (Phase 3).
- **An app service, run from a new app deploy image** - no further config field required; needs
  the qimsdk-debian deploy image to base on (see
  [App Deploy Image](#app-deploy-image-qimsdk_app_deploy)). Applies to apps only: a plugin has no
  executable to run.

If the execution host (Phase 1) is a PC distinct from the target device and ADB/SSH access was
not yet configured in Phase 2, configure it now - see
[ADB / SSH Device Access](#adb-ssh-device-access-optional).

If the target device was just rebooted or freshly flashed, prepare it before pushing:

```bash
builder-device-prepare <device-id>
```

This remounts the root filesystem read-write, disables SELinux enforcement, and syncs the device
clock - over adb (`root`/`remount`) or ssh (`sudo mount -o remount,rw`), depending on transport.

<div id="phase-8-deliver-the-artifacts"></div>

### Phase 8 — Deliver The Artifacts

Back on the execution host (outside the builder container):

```bash
builder-push-artifacts-device targets/my_target.json       # -> device root filesystem, release
builder-push-artifacts-device-dbg targets/my_target.json   # -> device root filesystem, debug
builder-push-artifacts-docker targets/my_target.json       # -> deploy container, release
builder-push-artifacts-docker-dbg targets/my_target.json   # -> deploy container, debug
```

Each function triggers the save step in the builder container, fetches the resulting tarball into a host
staging directory, and then delivers it as described in
[Deployment Scenarios](#deployment-scenarios), depending on `Target_device_ID`.

**Running the app as an app service.** Instead of pushing artifacts into a deploy container,
build the [app deploy image](#app-deploy-image-qimsdk_app_deploy), then run it on the target
device as an app service, with Docker Compose from the `deploy-container.yml` template:

```bash
cp deploy-container.yml targets/my_target.yml
# replace every <...> placeholder in targets/my_target.yml (see the comments at its top)
```

The device needs the CDI spec, env file and samples directory the qimsdk-debian README describes in
"How to run the qimsdk device deploy container" (`/etc/cdi/qimsdk.json`,
`/etc/docker/env/qimsdk.env`, `${HOME}/Downloads/qimsdk_samples`). Then, with
`<device-id>` set to the same `Target_device_ID` (adb serial or IPv4):

```bash
docker save qimsdk-deploy-<Additional_tag_image> -o qimsdk-deploy-<Additional_tag_image>.tar
builder-device-command <device-id> "mkdir -p /tmp/qti/deploy"
builder-cmd <device-id> push qimsdk-deploy-<Additional_tag_image>.tar targets/my_target.yml /tmp/qti/deploy/
builder-device-command <device-id> "docker load -i /tmp/qti/deploy/qimsdk-deploy-<Additional_tag_image>.tar"
builder-device-command <device-id> "docker compose -f /tmp/qti/deploy/my_target.yml up -d"
builder-device-command <device-id> "rm -f /tmp/qti/deploy/qimsdk-deploy-<Additional_tag_image>.tar"
```

`builder-cmd`/`builder-device-command` need a non-empty device ID, and do not handle `localhost`:
when the builder container runs on the device itself, skip `save`/`push`/`load` and run
`docker compose -f targets/my_target.yml up -d` locally. The app deploy image tarball is roughly the size of
the qimsdk-debian deploy image (1.5 GB or more), so make sure `/tmp` on the device can hold it, or
pick another directory.

<div id="function-reference-by-phase"></div>

### Function Reference By Phase

| Phase | Function | File |
|---|---|---|
| 4 | `builder-docker-build-image` | `scripts-dbg/docker_env_setup.sh` |
| 4 (internal) | `builder-docker-build-initialize` / `builder-docker-build-builder-dev-image` | `scripts-dbg/docker_env_setup.sh` |
| 5 | `builder-docker-run-container` | `scripts-dbg/docker_env_setup.sh` |
| 6 | `builder-incremental-build` | `scripts/build.sh` |
| 6 | `builder-cmake-build` | `scripts/build.sh` |
| 6 | `builder-cmake-configure` / `-compile` / `-install` | `scripts/build.sh` |
| 6 | `builder-setup-crosscompilation` | `scripts/setup.sh` |
| 6 | `builder-apply-patches` (and `-gst-plugins-base`/`-good`/`-bad`) | `scripts/setup.sh` |
| 7 | `builder-device-prepare` | `scripts-dbg/common.sh` |
| 8 | `builder-push-artifacts-device[-dbg]` | `scripts-dbg/docker_env_setup.sh` |
| 8 | `builder-push-artifacts-docker[-dbg]` | `scripts-dbg/docker_env_setup.sh` |
| 8 (internal) | `builder-fetch-saved-artifacts` | `scripts-dbg/docker_env_setup.sh` |
| 8 (internal) | `builder-save-artifacts` / `-save-artifacts-dbg` | `scripts/dev_sync.sh` |
| - | `builder-docker-images-cleanup` | `scripts-dbg/docker_env_setup.sh` |
