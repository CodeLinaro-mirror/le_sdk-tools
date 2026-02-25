# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

#!/bin/bash

# Export variables to be populated inside container
QIMSDK_EXPORTS=(
    "XDG_RUNTIME_DIR=/run/user/1000"
    "WAYLAND_DISPLAY=wayland-0"
    "GST_DEBUG_NO_COLOR=1"
    "GST_DEBUG=2"
    "GST_PLUGIN_SCANNER=\"/usr/lib/aarch64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner\""
)

# Device nodes to be mapped inside container
QIMSDK_DEVICE_NODES=(
    "/dev/dri/card0"
    "/dev/dri/renderD128"
    "/dev/kgsl-3d0"
    "/dev/video32"
    "/dev/video33"
    "/dev/dma_heap/system"
    "/dev/dma_heap/qcom,system"
    "/dev/fastrpc-cdsp"
)

# Paths to be mounted inside container. It will be filled with QIMSDK_DIRECTORIES,
# QIMSDK_SAMPLE_APPS, QIMSDK_OVERLAY_KERNELS and QIMSDK_SHARED_LIBS.
QIMSDK_PATHS_TO_MOUNT=()

# Directories to be mapped directly
QIMSDK_DIRECTORIES=(
    "/run/user/1000"
    "/tmp/socket/cam_server"
    "/tmp/property-vault.socket"
    "/etc/labels"
    "/etc/media"
    "/etc/models"
    "/etc/configs"
    "/usr/lib/aarch64-linux-gnu/gstreamer-1.0/meta"
    "/usr/lib/aarch64-linux-gnu/gstreamer-1.0/ml"
    "/usr/lib/aarch64-linux-gnu/gstreamer-1.0/mlmetaparser"
    "/usr/lib/aarch64-linux-gnu/pulseaudio"
)

# Gstreamer and python sample apps
QIMSDK_SAMPLE_APPS=()

# Search all the apps with /usr/bin/gst-*
for file in /usr/bin/gst-*; do
    [ -x "${file}" ] && QIMSDK_SAMPLE_APPS+=("${file}")
done

# Overlay kernel files
QIMSDK_OVERLAY_KERNELS=()

# Search .cl files with /usr/lib/aarch64-linux-gnu/overlay*
for file in /usr/lib/aarch64-linux-gnu/overlay*; do
    QIMSDK_OVERLAY_KERNELS+=("${file}")
done

# Names of gst plugins and their dependencies
QIMSDK_SHARED_LIBS_BASENAMES=(
    "dri_gbm.so"
    "msm_gbm.so"
    "libdmabufheap.so"
    "libadreno_utils.so"
    "libatomic.so"
    "libgbm.so"
    "libgsl.so"
    "libadsprpc.so"
    "libcdsprpc.so"
    "libenv_time.so"
    "libevaluation_proto.so"
    "libfarmhash.so"
    "libCB.so"
    "libimage_metrics.so"
    "libjpeg_internal.so"
    "libllvm-glnext.so"
    "libllvm-qcom.so"
    "libllvm-qgl.so"
    "libpropertyvault.so"
    "libgallium*.so"
    "libCalculator_skel.so"
    "libPlatformValidatorShared.so"
    "libhta_hexagon_runtime_snpe.so"
    "libEGL.so"
    "libEGL_adreno.so"
    "libGLESv1_CM.so"
    "libGLESv1_CM_adreno.so"
    "libGLESv2.so"
    "libGLESv2_adreno.so"
    "libvulkan_adreno.so"
    "libOpenCL.so"
    "libOpenCL_adreno.so"
    "libIB2C.so"
    "libVideoCtrl.so"
    "libeglSubDriverWayland.so"
    "libq3dtools_adreno.so"
    "libq3dtools_esx.so"
    "libfastcvadsp.so"
    "libfastcvdsp_stub.so"
    "libfastcvopt.so"
    "libfastcvdsp_skel.so"
    "libgstreamer-1.0.so"
    "libgstcoreelements.so"
    "libgstpulseaudio.so"
    "libgstvideo4linux2.so"
    "libgstwaylandsink.so"
    "libgstappsutils.so"
    "libgstbase-1.0.so"
    "libgstvideo-1.0.so"
    "libgstwayland-1.0.so"
    "libpulse-simple.so"
    "libpulse.so"
    "liboverlay_lib.so"
    "libwayland-client.so"
    "libwayland-egl.so"
    "libcamera_metadata.so"
    "libqmmf_camera_metadata.so"
    "libqmmf_propertyvault.so"
    "libqmmf_proto.so"
    "libqmmf_recorder_client.so"
    "libqmmf_utils.so"
    "libtensorflowlite_c.so"
    "libtf_logging.so"
    "default_fmt_alignment.xml"
    "libgstqti*"
    "libqti*"
    "libQnn*"
    "libQNN*"
    "libqnn*"
    "libSnpe*"
    "libSNPE*"
    "libsnpe*"
)

# Determine target platform, e.g. qcm6490, qcs9100, etc.
soc_name=$(cat /sys/devices/soc0/machine)
declare -A soc_to_target_map=(
    ["QCS6490"]="qcm6490"
    ["QCM6490"]="qcm6490"
    ["SC7280"]="qcm6490"
    ["QCS5430"]="qcm6490"
    ["QCS9100"]="qcs9100"
    ["QCS9075"]="qcs9100"
    ["SA8775P"]="qcs9100"
    ["QCS8300"]="qcs8300"
    ["QCS8275"]="qcs8300"
    ["SA7255P"]="qcs8300"
)
target_platform="${soc_to_target_map[${soc_name}]}"
echo -e "\nTarget platform is ${target_platform}.\n"

# Libs with path names including target specific strings will be selected based
# on current target. e.g. hexagon v68 libs are meant for qcm6490, v73 for qcs9100,
# v75 for qcs8300, etc.
declare -A target_specific_strs=(
    ["v66"]="qrb5165"
    ["v69"]="qcs8550"
    ["v68"]="qcm6490"
    ["qcm6490"]="qcm6490"
    ["v73"]="qcs9100"
    ["qcs9100"]="qcs9100"
    ["v75"]="qcs8300"
    ["qcs8300"]="qcs8300"
    ["v79"]="unknown"
)

# Paths of shared libs to be mapped inside container.
QIMSDK_SHARED_LIBS=()

# Search SONAME of all the .so and add them to QIMSDK_SHARED_LIBS
echo "Installing binutils for readelf..."
sudo apt install -y binutils

shopt -s nocasematch
for lib in "${QIMSDK_SHARED_LIBS_BASENAMES[@]}"; do
    while IFS= read -r path; do
        matched_target=""

        # Skip the libs meant for other targets
        for key in "${!target_specific_strs[@]}"; do
            [[ "${path}" == *"${key}"* ]] &&                                                       \
            matched_target="${target_specific_strs[${key}]}" &&                                    \
            break
        done

        [[ -z "${matched_target}" || "${matched_target}" == "${target_platform}" ]] && {
            soname=$(readelf -d "${path}" 2>/dev/null | grep '(SONAME)' | sed -E 's/.*\[(.*)\]/\1/')

            if [ -n "${soname}" ]; then
                finalpath="$(dirname "${path}")/${soname}"
                [[ ! -f "${finalpath}" ]] && QIMSDK_SHARED_LIBS+=("${path}") && continue

                QIMSDK_SHARED_LIBS+=("${finalpath}")

                # Compare 'filename' of the lib and its SONAME. If they're different, mount both.
                # This is to avoid removal of libs like libEGL, libGLES, libhta_hexagon_runtime_snpe
                # which've SONAMEs libEGL_adreno, libGLES_adreno, libhta_hexagon_runtime, and so on.
                filename_of_soname=$(echo ${soname} | sed 's/\.so.*//')
                filename_of_lib=$(basename ${path} | sed 's/\.so.*//')
                [[ "${filename_of_soname}" != "${filename_of_lib}" ]] &&                           \
                QIMSDK_SHARED_LIBS+=("${path}")
            else
                QIMSDK_SHARED_LIBS+=("${path}")
            fi
        }
    done < <(find "/usr/lib" -name "${lib}*")
done

# Remove duplicates from QIMSDK_SHARED_LIBS
QIMSDK_SHARED_LIBS=($(printf "%s\n" "${QIMSDK_SHARED_LIBS[@]}" | sort -u))

# Handle few exceptions
QIMSDK_SHARED_LIBS+=("/usr/lib/aarch64-linux-gnu/libcdsprpc.so")
QIMSDK_SHARED_LIBS+=("/usr/lib/aarch64-linux-gnu/libadsprpc.so")
QIMSDK_SHARED_LIBS+=("/usr/lib/aarch64-linux-gnu/libEGL_adreno.so.1.0.0")
QIMSDK_SHARED_LIBS+=("/usr/share/glvnd/egl_vendor.d/10_adreno.json")

# Fill QIMSDK_PATHS_TO_MOUNT with all the paths to be mapped.
QIMSDK_PATHS_TO_MOUNT=(
    "${QIMSDK_DIRECTORIES[@]}"
    "${QIMSDK_SAMPLE_APPS[@]}"
    "${QIMSDK_OVERLAY_KERNELS[@]}"
    "${QIMSDK_SHARED_LIBS[@]}"
)

# Create the CDI JSON file.
tmp_path=/tmp/docker-run-cdi-hw-acc.json

echo "Installing jq for creating json file..."
sudo apt install -y jq

jq -n                                                                                              \
    --arg cdiVersion "0.6.0"                                                                       \
    --arg kind "qualcomm.com/device"                                                               \
    --argjson devices "[$(jq -n                                                                    \
        --arg name "cdi-hw-acc"                                                                    \
        --argjson containerEdits "$(jq -n                                                          \
            --argjson env "$(printf '%s\n' "${QIMSDK_EXPORTS[@]}" | jq -R . | jq -s .)"            \
            --argjson deviceNodes "$(printf '%s\n' "${QIMSDK_DEVICE_NODES[@]}" | jq                \
                                   -R '{path: ., fileMode: 438}' | jq -s .)"                       \
            --argjson mounts "$(printf '%s\n' "${QIMSDK_PATHS_TO_MOUNT[@]}" | jq                   \
                              -R '{hostPath: ., containerPath: ., options: ["bind"]}' | jq -s .)"  \
        '$ARGS.named')"                                                                            \
    '$ARGS.named')]"                                                                               \
'$ARGS.named' > "${tmp_path}" || {
    echo "Failed to generate Docker CDI json file !!!"
    sudo rm -rf "${tmp_path}"
    exit 1
}

# Copy the generated CDI json file to /etc/cdi.
path_to_docker_cdi_json=/etc/cdi/docker-run-cdi-hw-acc.json
sudo mkdir -p /etc/cdi && sudo mv ${tmp_path} ${path_to_docker_cdi_json} || {
    echo "Failed to install Docker CDI json file at /etc/cdi !!!"
    sudo rm -rf "${tmp_path}"
    exit 1
}

echo -e "\nSuccessfully generated Docker CDI json and installed at ${path_to_docker_cdi_json}."

# Create directories required to be mounted
sudo mkdir -p /etc/media /etc/configs /etc/labels /etc/models

# Restart docker service to read the updated json file
echo -e "\nRestarting docker service..."
systemctl daemon-reload
systemctl restart docker
