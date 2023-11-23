#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Register layer
QIMSDK_ALL_LAYERS+=("gst-plugins-qti")

# Add meta-qti-gst layer
function qimsdk-gst-plugins-qti-add-layers() {
    qimsdk-bitbake-add-layers ${QIMSDK_BASE_DIR}/poky/meta-qti-gst
}

# Prepare all recipes in layer
function qimsdk-gst-plugins-qti-prepare-layer() {
    devtool modify packagegroup-qti-gst
}

# Clean all recipes in layer
function qimsdk-gst-plugins-qti-clean-layers() {
    devtool reset packagegroup-qti-gst
    rm -rf ${QIMSDK_ESDK_BASE_DIR}/workspace/sources/packagegroup-qti-gst
}

# Prepare gst-plugins-qti
function qimsdk-gst-plugins-qti-prepare() {

    # Identify the package management configuration
    [ -d "${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb" ] && PKG_WRITE_TASK="do_package_write_deb" || PKG_WRITE_TASK="do_package_write_ipk"

    # Remove gstreamer and meta-qti-gst from BBMASK
    sed -i "s/meta\/recipes-multimedia\/gstreamer\///g;s/meta-qti-gst\///g;s/meta-qti-ubuntu\/recipes-toolchain\/ubuntu\/gstreamer1.0\*//g" \
        ${QIMSDK_ESDK_BASE_DIR}/conf/local.conf

    # Set WORKSPACE variable or add it to bblayers.conf if not exist
    grep -wq WORKSPACE ${QIMSDK_ESDK_BASE_DIR}/conf/bblayers.conf && \
        sed -i "s+WORKSPACE\s*=\s*\"..TOPDIR./.*\"+WORKSPACE = \"\$\{TOPDIR\}/src\"+g" \
            ${QIMSDK_ESDK_BASE_DIR}/conf/bblayers.conf || echo 'WORKSPACE = "${TOPDIR}/src"' >> ${QIMSDK_ESDK_BASE_DIR}/conf/bblayers.conf

    # Remove meta-qti-gst and meta-qti-gst-prop from bblayers.conf
    sed -i "s/\${SDKBASEMETAPATH}\/layers\/poky\/meta-qti-gst-prop//g;s/\${SDKBASEMETAPATH}\/layers\/poky\/meta-qti-gst//g" \
        ${QIMSDK_ESDK_BASE_DIR}/conf/bblayers.conf

    # Use kernel headers dir from local sysroot
    sed -i "s/\${STAGING_KERNEL_BUILDDIR}/\${STAGING_INCDIR}\/linux-msm/g" \
        ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/*.bb*

    # Remove not needed dependency to kernel workdir
    sed -i "s/do_configure\[depends\] += \"virtual\/kernel:do_shared_workdir\"//g" \
        ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/*.bb*

    # Remove packagegroup class
    sed -i "s/inherit packagegroup//g" \
        ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/packagegroups/packagegroup-qti-gst.bb

    # Transpose packagegroup specific RDEPENDS packages as do_package task dependencies
    sed -i "s/RDEPENDS.packagegroup-qti-gst /do_package[depends]/g" \
        ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/packagegroups/packagegroup-qti-gst.bb

    # Append do_package_write_ipk or do_package_write_deb task to packages
    grep -q ${PKG_WRITE_TASK} ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/packagegroups/packagegroup-qti-gst.bb || \
        sed -i "s/\([^-]\)\(gst[.a-zA-Z0-9-]*\)/\1\2:${PKG_WRITE_TASK}/g" \
            ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/packagegroups/packagegroup-qti-gst.bb

    # Remove packagegroup-qti-gst.bbappend
    rm -rf ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/packagegroups/packagegroup-qti-gst.bbappend

    # Add gst qti oss dependencies
    echo do_compile[depends] = \" \\ >> ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/packagegroups/packagegroup-qti-gst.bbappend

    for package in ${QIMSDK_ESDK_GST_PLUGINS_QTI_OSS_DEPENDENCIES[@]}; do
        echo '      '${package}:${PKG_WRITE_TASK} \\ >> ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/packagegroups/packagegroup-qti-gst.bbappend
    done
    echo '    '\" >> ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/packagegroups/packagegroup-qti-gst.bbappend

    [ -z "${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}" ]                                               || \
        {
            sed -i "s|ExecStart=/usr/bin/gstd|ExecStart=${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/bin/gstd|g" \
                ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/gstd/gstd.service
            sed -i "s|GST_ML_MODULES_DIR=\"\${GST_PLUGINS_QTI_OSS_INSTALL_LIBDIR}/gstreamer-1.0/ml/modules\"|GST_ML_MODULES_DIR=\"${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}\${GST_PLUGINS_QTI_OSS_INSTALL_LIBDIR}/gstreamer-1.0/ml/modules\"|g" \
                ${QIMSDK_BASE_DIR}/repo/src/vendor/qcom/opensource/gst-plugins-qti-oss/gst-plugin-base/gst/ml/CMakeLists.txt
            sed -i "s|/usr/bin/gst-client-1.0|${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/bin/gst-client-1.0|g" \
                ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/gstd_%.bbappend

            echo "export PATH=\$PATH:${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/bin" > ${QIMSDK_BASE_DIR}/qim-sdk.sh
            echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/lib" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
            echo "export GST_PLUGIN_PATH=\$GST_PLUGIN_PATH:${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/lib/gstreamer-1.0" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh

            [ "${PKG_WRITE_TASK}" == "do_package_write_ipk" ]                                   && \
                {
                    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/lib" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
                    echo "export GST_PLUGIN_SCANNER=${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/libexec/gstreamer-1.0/gst-plugin-scanner" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
                }                                                                               || \
                    {
                        echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
                        echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/lib/aarch64-linux-gnu" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
                        echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/lib/aarch64-linux-gnu" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
                        echo "export GST_PLUGIN_PATH=\$GST_PLUGIN_PATH:${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/lib/aarch64-linux-gnu/gstreamer-1.0" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
                        echo "export GST_PLUGIN_SCANNER=${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/lib/aarch64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
                    }
            echo "rm -rf ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/lib/systemd/ && \\" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
            echo "mkdir -p ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/lib/systemd/ && \\" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh
            echo "ln -s /etc/systemd/system ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/lib/systemd/" >> ${QIMSDK_BASE_DIR}/qim-sdk.sh

            echo "${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}" >> ${QIMSDK_BASE_DIR}/qim-sdk-install-prefix.txt
        }

    # apt-get install gst_plugins_qti_oss_dependencies
    [ "${PKG_WRITE_TASK}" == "do_package_write_deb" ]                                           && \
        {
            echo 'do_compile[depends] = "ubuntu-base:do_ubuntu_install"' > ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/packagegroups/packagegroup-qti-gst.bbappend
            sed -i "s/\${UBUN_FULLSTACK_PERF_PACKAGES}/${QIMSDK_ESDK_GST_PLUGINS_QTI_OSS_DEPENDENCIES}/g;s/\${UBUN_FULLSTACK_DEBUG_PACKAGES}/${QIMSDK_ESDK_GST_PLUGINS_QTI_OSS_DEPENDENCIES}/g" \
                ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ubuntu/recipes-core/ubuntu-base/ubuntu-base_20.04.bb
            sed -i "s/rm \${TMP_WKDIR}\/lib\/udev\/rules.d\/60-persistent-v4l.rules/rm -f \${TMP_WKDIR}\/lib\/udev\/rules.d\/60-persistent-v4l.rules/g;s/rm \${TMP_WKDIR}\/lib\/udev\/v4l_id/rm -f \${TMP_WKDIR}\/lib\/udev\/v4l_id/g;s/60-persistent-storage.rules/60-persistent-storage-dm.rules/g" \
                ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ubuntu/recipes-core/ubuntu-base/ubuntu-base_20.04.bb
            grep -wq RM_WORK_EXCLUDE ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ubuntu/recipes-core/ubuntu-base/ubuntu-base_20.04.bb || \
                echo 'RM_WORK_EXCLUDE += "${PN}"' >> ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ubuntu/recipes-core/ubuntu-base/ubuntu-base_20.04.bb
            sed -i '/ssh_import_id/d;/\thumanity_theme_install/d;/ do_tzdata_install/d' \
                ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ubuntu/recipes-core/ubuntu-base/ubuntu-base_20.04.bb
            sed -i 's/do_package_write_ipk/do_package_write_deb/g' \
                ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/*.bb*
            grep -q "PV" ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ubuntu/recipes-toolchain/ubuntu/glibc-ubuntu.bb || \
                {
                   for RECIPE in $(ls ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ubuntu/recipes-toolchain/ubuntu/); do

                        # Do not add PV to ubuntu-toolchain recipe
                        [ "${RECIPE}" == "ubuntu-toolchain.bb" ] && continue

                        PV=$(sed -n "s/^.*_\([.0-9]\+\).*$/\1/p" ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ubuntu/recipes-toolchain/ubuntu/${RECIPE} | head -1)

                        # Increment libgstreamer1.0-0 minor version to have it installed last
                        [ "${RECIPE}" == "gstreamer1.0-ubuntu.bb" ] && {

                            FIRST_DIGIT=$(echo ${PV} | sed 's/\./ /g' | awk '{print $1}')
                            SECOND_DIGIT=$(echo ${PV} | sed 's/\./ /g' | awk '{print $2}')
                            THIRD_DIGIT=$(($(echo ${PV} | sed 's/\./ /g' | awk '{print $3}') + 2 | bc))

                            PV=${FIRST_DIGIT}.${SECOND_DIGIT}.${THIRD_DIGIT}
                        }

                        echo -e '\n'PV = '"'${PV}'"' >> ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ubuntu/recipes-toolchain/ubuntu/${RECIPE}
                    done
                }
        }

    # Remove tensorflow-lite from DISTRO_FEATURES
    sed -i "s/tensorflow-lite//g" \
        ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-distro/conf/distro/include/qti-distro-fullstack.inc

    # Check if tf lite prebuilt is available
    [ "${QIMSDK_ESDK_TFLITE_FILENAME}" != "no-tflite-dev-archive-available" ]                   && \
        {
            # Enable the compilation of mltflite plugin
            echo -e '\nDISTRO_FEATURES += "tensorflow-lite"' >> ${QIMSDK_ESDK_BASE_DIR}/conf/local.conf
            # Setup tf lite prebuilt, if available
            mv -f ${QIMSDK_ESDK_BASE_DIR}/downloads/${QIMSDK_ESDK_TFLITE_FILENAME} ${QIMSDK_ESDK_BASE_DIR}/downloads/tflite-dev.tar.gz;
            sed -i "s/DEPENDS += \"tensorflow-lite\"/DEPENDS += \"tensorflow-lite-prebuilt\"\\ndo_configure[depends] += \"tensorflow-lite-prebuilt:${PKG_WRITE_TASK}\"/g" \
                ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/*.bb*
        }                                                                                       || \
        {
            sed -i '/tensorflow-lite/d' ${QIMSDK_ESDK_BASE_DIR}/conf/local.conf
        }

    local QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES=(${QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES})
    local QIMSDK_ESDK_ACCELERATION_ENGINE_COUNT=${#QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES[@]}

    for ((i=0 ; i<${QIMSDK_ESDK_ACCELERATION_ENGINE_COUNT} ; i++)); do
        local QIMSDK_ESDK_ACCELERATION_ENGINE=${QIMSDK_ESDK_ACCELERATION_ENGINE_NAMES[i]}
        local ENGINE_INDEX=$(( $i + 1 ))
        [ "${i}" -eq 0 ] && [ ! -f "${QIMSDK_ESDK_BASE_DIR}/downloads/no-acceleration-engine-1-dir-available" ] && \
            {
                echo -e "\nDISTRO_FEATURES += \"qti-"${QIMSDK_ESDK_ACCELERATION_ENGINE}"\"" >> ${QIMSDK_ESDK_BASE_DIR}/conf/local.conf
                mkdir -p ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ml-prop/recipes/${QIMSDK_ESDK_ACCELERATION_ENGINE}-sdk
                [ -f "${QIMSDK_ESDK_BASE_DIR}/downloads/${QIMSDK_ESDK_ACCELERATION_ENGINE}/ReleaseNotes.txt" ] && \
                    echo PV = \"$(grep -m 1 "${QIMSDK_ESDK_ACCELERATION_ENGINE^^} [0-9].*" ${QIMSDK_ESDK_BASE_DIR}/downloads/${QIMSDK_ESDK_ACCELERATION_ENGINE}/ReleaseNotes.txt | awk '{print $2}')\" \
                    >> ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ml-prop/recipes/${QIMSDK_ESDK_ACCELERATION_ENGINE}-sdk/${QIMSDK_ESDK_ACCELERATION_ENGINE}.bbappend

                # Add do_configure dependency on Acceleration engine sdk, needed inside qimsdk environment, if not added already
                grep -q "${QIMSDK_ESDK_ACCELERATION_ENGINE}:${PKG_WRITE_TASK}" ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/gstreamer1.0-plugins-qti-oss-ml${QIMSDK_ESDK_ACCELERATION_ENGINE}.bb || \
                    {
                        sed -i "/${QIMSDK_ESDK_ACCELERATION_ENGINE}:do_package_write_/d" \
                            ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/gstreamer1.0-plugins-qti-oss-ml${QIMSDK_ESDK_ACCELERATION_ENGINE}.bb
                        sed -i "s/DEPENDS += \"${QIMSDK_ESDK_ACCELERATION_ENGINE}\"/DEPENDS += \"${QIMSDK_ESDK_ACCELERATION_ENGINE}\"\\ndo_configure[depends] += \"${QIMSDK_ESDK_ACCELERATION_ENGINE}:${PKG_WRITE_TASK}\"/g" \
                            ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/gstreamer1.0-plugins-qti-oss-ml${QIMSDK_ESDK_ACCELERATION_ENGINE}.bb
                    }
            }
        [ "${i}" -eq 1 ] && [ ! -f "${QIMSDK_ESDK_BASE_DIR}/downloads/no-acceleration-engine-2-dir-available" ] && \
            {
                echo -e "\nDISTRO_FEATURES += \"qti-"${QIMSDK_ESDK_ACCELERATION_ENGINE}"\"" >> ${QIMSDK_ESDK_BASE_DIR}/conf/local.conf
                mkdir -p ${QIMSDK_ESDK_BASE_DIR}/layers/poky/meta-qti-ml-prop/recipes/${QIMSDK_ESDK_ACCELERATION_ENGINE}-sdk
                # Add do_configure dependency on Acceleration engine sdk, needed inside qimsdk environment, if not added already
                grep -q "${QIMSDK_ESDK_ACCELERATION_ENGINE}:${PKG_WRITE_TASK}" ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/gstreamer1.0-plugins-qti-oss-ml${QIMSDK_ESDK_ACCELERATION_ENGINE}.bb || \
                    {
                        sed -i "/${QIMSDK_ESDK_ACCELERATION_ENGINE}:do_package_write_/d" ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/gstreamer1.0-plugins-qti-oss-ml${QIMSDK_ESDK_ACCELERATION_ENGINE}.bb
                        sed -i "s/DEPENDS += \"${QIMSDK_ESDK_ACCELERATION_ENGINE}\"/DEPENDS += \"${QIMSDK_ESDK_ACCELERATION_ENGINE}\"\\ndo_configure[depends] += \"${QIMSDK_ESDK_ACCELERATION_ENGINE}:${PKG_WRITE_TASK}\"/g" ${QIMSDK_BASE_DIR}/poky/meta-qti-gst/recipes/gstreamer/gstreamer1.0-plugins-qti-oss-ml${QIMSDK_ESDK_ACCELERATION_ENGINE}.bb
                    }
            }
    done

    qimsdk-gst-plugins-qti-add-layers                                                           && \
        qimsdk-gst-plugins-qti-prepare-layer
}

# Prepare gst-plugins-qti device install prefix
function qimsdk-gst-plugins-qti-device-install-prefix() {

    # Amend hardcoded install paths in prebuilt apt-get downloaded packages
    local PPKGS="libgstreamer1.0-0 x11-common timgm6mb-soundfont"

    for PPKG in $PPKGS; do
        mkdir -p ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp
        PPKG_NAME=$(basename -- ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/${PPKG}*.deb)
        [ -f "${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/${PPKG_NAME}" ] && \
            {
                dpkg-deb -R ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/${PPKG_NAME} \
                    ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp
                grep -q "${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}" ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp/DEBIAN/postinst || \
                    sed -i "s|/usr/lib|${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/lib|g;s|/usr/share|${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/share|g;s|#!bin/sh|#!/bin/sh|g" \
                        ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp/DEBIAN/postinst \
                        ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp/DEBIAN/preinst
                dpkg-deb -b ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp \
                    ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/${PPKG_NAME}
                rm -rf ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp
            }
    done

    #Amend update-alternatives path in aarch64 gst-plugins-qti packages
    local GPKGS="qti-gstreamer1.0-plugins-good-v4l2 qti-gstreamer1.0-plugins-good-pulse qti-gstreamer1.0-plugins-base-audio"

    for GPKG in $GPKGS; do
        mkdir -p ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/tmp
        GPKG_NAME=$(basename -- ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/${GPKG}*.deb)
        [ -f "${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/${GPKG_NAME}" ] && \
            {
                dpkg-deb -R ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/${GPKG_NAME} \
                    ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/tmp
                grep -q "${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}" ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/tmp/DEBIAN/postinst || \
                    sed -i "s| /usr/lib| ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/lib|g;s|//opt|${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/opt|g" \
                        ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/tmp/DEBIAN/postinst \
                        ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/tmp/DEBIAN/prerm
                [ "${GPKG}" == "qti-gstreamer1.0-plugins-good-v4l2" ]                                   && \
                    {
                        cd ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/tmp/usr/lib/gstreamer-1.0/
                        ln -sf ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/opt/qti/usr/lib/gstreamer-1.0/libgstvideo4linux2.so.gstreamer1.0-plugins-good libgstvideo4linux2.so
                        cd -
                    }
                [ "${GPKG}" == "qti-gstreamer1.0-plugins-good-pulse" ]                                  && \
                    {
                        cd ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/tmp/usr/lib/gstreamer-1.0/
                        ln -sf ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/opt/qti/usr/lib/gstreamer-1.0/libgstpulseaudio.so.gstreamer1.0-plugins-good libgstpulseaudio.so
                        cd -
                    }
                dpkg-deb -b ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/tmp \
                    ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/${GPKG_NAME}
                rm -rf ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/aarch64/tmp
            }
    done

    #Amend update-alternatives path in qcs6490_odk gst-plugins-qti packages
    local QPKGS="qti-gstreamer1.0-plugins-bad-waylandsink"

    for QPKG in $QPKGS; do
        mkdir -p ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/tmp
        QPKG_NAME=$(basename -- ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/${QPKG}*.deb)
        [ -f "${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/${QPKG_NAME}" ] && \
            {
                dpkg-deb -R ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/${QPKG_NAME} \
                    ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/tmp
                grep -q "${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}" ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/tmp/DEBIAN/postinst || \
                    sed -i "s| /usr/lib| ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/usr/lib|g;s|//opt|${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/opt|g;s|--install|--force --install|g" \
                        ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/tmp/DEBIAN/postinst \
                        ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/tmp/DEBIAN/prerm
                cd ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/tmp/usr/lib/gstreamer-1.0/
                ln -sf ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/opt/qti/usr/lib/gstreamer-1.0/libgstwaylandsink.so.gstreamer1.0-plugins-bad libgstwaylandsink.so
                cd -
                dpkg-deb -b ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/tmp \
                    ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/${QPKG_NAME}
                rm -rf ${QIMSDK_ESDK_BASE_DIR}/tmp/deploy/deb/qcs6490_odk/tmp
            }
    done
}

# Modify not starting SystemD services
function qimsdk-gst-plugins-qti-modify-systemd-services() {

    # Substitute "OnCalendar" systemd option with "OnUnitActiveSec" on services in prebuilt apt-get downloaded packages
    local SPKGS="logrotate"

    for SPKG in $SPKGS; do
        mkdir -p ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp
        SPKG_NAME=$(basename -- ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/${SPKG}*.deb)
        [ -f "${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/${SPKG_NAME}" ] && \
            {
                dpkg-deb -R ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/${SPKG_NAME} \
                    ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp
                grep -q "OnUnitActiveSec" ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp/lib/systemd/system/*.timer || \
                    sed -i "s|OnCalendar=daily|OnUnitActiveSec=1d|g" \
                        ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp/lib/systemd/system/*.timer
                dpkg-deb -b ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp \
                    ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/${SPKG_NAME}
                rm -rf ${QIMSDK_ESDK_BASE_DIR}/tmp/work/aarch64-oe-linux/ubuntu-base/20.04-r0/ubuntu_base_tmp/var/cache/apt/archives/tmp
            }
    done
}

# Clean gst-plugins-qti
function qimsdk-gst-plugins-qti-clean() {
    qimsdk-gst-plugins-qti-clean-layers
}

# Build gst-plugins-qti
function qimsdk-gst-plugins-qti-build() {
    devtool build packagegroup-qti-gst                                                          && \
            {
                [ "${PKG_WRITE_TASK}" == "do_package_write_deb" ]                               && \
                    qimsdk-gst-plugins-qti-modify-systemd-services                              && \
                        [ -n "${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}" ]                           && \
                            qimsdk-gst-plugins-qti-device-install-prefix                        || \
                            true
            }
}

# Package gst-plugins-qti
function qimsdk-gst-plugins-qti-package() {
    # Build task of that recipe generates all ipk or deb files for dependent packages
    devtool package packagegroup-qti-gst
}

# Inspect plugins
function qimsdk-gst-plugins-qti-inspect() {
    # Detecting installed gst plugins
    echo "Detecting installed gst plugins ..."
    qimsdk-device-command "ls /usr/lib/gstreamer-1.0/libgst* > /data/plugin-list.txt" || return -1
    adb pull /data/plugin-list.txt ${QIMSDK_WORK_DIR}/ 2>&1 > /dev/null || return -2
    qimsdk-device-command "rm -f /data/plugin-list.txt"
    plugins=($(cat ${QIMSDK_WORK_DIR}/plugin-list.txt))
    rm -f ${QIMSDK_WORK_DIR}/plugin-list.txt

    # Inspecting installed gst plugins
    echo "Inspecting installed gst plugins ..."
    qimsdk-device-command "rm -f /data/gst-inspect-error-log.txt"
    for PLUGIN in ${plugins[@]}; do
        qimsdk-device-command "gst-inspect-1.0 ${PLUGIN} 1>/dev/null 2>>/data/gst-inspect-error-log.txt "
    done

    # Check output
    adb pull /data/gst-inspect-error-log.txt ${QIMSDK_WORK_DIR}/ 2>&1 > /dev/null
    [ -f "${QIMSDK_WORK_DIR}/gst-inspect-error-log.txt" ]                                       && \
    [ `wc -c ${QIMSDK_WORK_DIR}/gst-inspect-error-log.txt | cut -d ' ' -f 1` -eq 0 ]            && \
        print-green "All gst plugins are inspected successfully !!!"                            || \
        {
            print-red "Gst inspection failed:";
            cat ${QIMSDK_WORK_DIR}/gst-inspect-error-log.txt
        }
    rm -f ${QIMSDK_WORK_DIR}/gst-inspect-error-log.txt
}
