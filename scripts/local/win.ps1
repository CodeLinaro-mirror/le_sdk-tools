# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

$global:QIMSDK_ESDK_DEVICE_INSTALL_PREFIX = ""

# Propagate the correct install path to opkg config
function global:qimsdk-local-set-opkg-prefix {
    Invoke-Expression "adb shell `"cat /etc/opkg/opkg.conf | grep \"dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}\"`""
    if($LastExitCode -ne 0) {
        Invoke-Expression "adb shell `"sed -i '/qimsdk_install_path/d' /etc/opkg/opkg.conf`""
        Invoke-Expression "adb shell `"echo \"dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}\" >> /etc/opkg/opkg.conf`""
    }
}

# Sync packages with the device from specified folder
#   $FOLDER - (mandatory) path to the packages to be synced
function global:qimsdk-local-sync {
    param(
        [Parameter (Mandatory = $true)] [String]$FOLDER
    )

    # Resolve relative/wildcard/absolute path
    $FOLDER = Resolve-Path -Path "$FOLDER"

    $null >> ${FOLDER}\uninstall.sh

    $FORMAT_IPK="ipk"
    $FORMAT_DEB="deb"

    if (Test-Path -Path "${FOLDER}\*" -Include qim-sdk-install-prefix.txt) {
        # Set global var
        $QIMSDK_ESDK_DEVICE_INSTALL_PREFIX = ( gc ${FOLDER}\qim-sdk-install-prefix.txt )

        #Push sdk script to device
        Invoke-Expression "adb push ${FOLDER}\qim-sdk.sh /etc/profile.d/"

        if (Test-Path -Path "${FOLDER}\*" -Include *.ipk) {
            qimsdk-local-set-opkg-prefix
        }
    }

    pushd ${FOLDER}
    foreach($PACKAGE_NAME in Get-ChildItem ${FOLDER}) {
        $PACKAGE_FORMAT= (Get-ChildItem ${PACKAGE_NAME}).Extension
        $PACKAGE_FORMAT="$PACKAGE_FORMAT".split(".")[1]

        if ($PACKAGE_FORMAT -eq $FORMAT_DEB) {
            Invoke-Expression "adb push ${PACKAGE_NAME} /tmp/"
            if ($LastExitCode -ne 0) {
                popd # ${FOLDER}
                throw "Push package to device failed !!!";
            }

            $DEVICE_INSTALL_PREFIX = "${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}"
            if ($QIMSDK_ESDK_DEVICE_INSTALL_PREFIX -eq "") {
                $DEVICE_INSTALL_PREFIX = "/"
            }

            Invoke-Expression "adb shell `"dpkg --instdir=${DEVICE_INSTALL_PREFIX} --install --force-all /tmp/${PACKAGE_NAME}`""
            if ($LastExitCode -ne 0) {
                Invoke-Expression "adb shell `"rm -f /tmp/${PACKAGE_NAME}`""
                popd # ${FOLDER}
                throw "Install package to device failed !!!";
            }
        }

        if ($PACKAGE_FORMAT -eq $FORMAT_IPK) {
            Invoke-Expression "adb push ${PACKAGE_NAME} /tmp/"
            if ($LastExitCode -ne 0) {
                popd # ${FOLDER}
                throw "Push package to device failed !!!";
            }

            if ($QIMSDK_ESDK_DEVICE_INSTALL_PREFIX -eq "") {
                Invoke-Expression "adb shell `"opkg --force-depends --force-reinstall --force-overwrite install /tmp/${PACKAGE_NAME}`""
                if ($LastExitCode -ne 0) {
                    Invoke-Expression "adb shell `"rm -f /tmp/${PACKAGE_NAME}`""
                    popd # ${FOLDER}
                    throw "Install package to device failed !!!";
                }
            } else {
                Invoke-Expression "adb shell `"opkg install -d qimsdk_install_path --force-depends --force-reinstall --force-overwrite install /tmp/${PACKAGE_NAME}`""
                if ($LastExitCode -ne 0) {
                    Invoke-Expression "adb shell `"rm -f /tmp/${PACKAGE_NAME}`""
                    popd # ${FOLDER}
                    throw "Install package to device failed !!!";
                }
            }
        }

        if ("$PACKAGE_NAME" -ne "uninstall.sh") {
            $PACKAGE_NAME_NO_VERSION="$PACKAGE_NAME".split("_")[0]

            if ($PACKAGE_FORMAT -eq $FORMAT_DEB) {
                "dpkg --remove --force-all ${PACKAGE_NAME_NO_VERSION}" >> uninstall.sh
            }

            if ($PACKAGE_FORMAT -eq $FORMAT_IPK) {
                "opkg remove --force-depends ${PACKAGE_NAME_NO_VERSION}" >> uninstall.sh
            }

            Remove-Item ${PACKAGE_NAME}
        }

        Invoke-Expression "adb shell rm -f /tmp/${PACKAGE_NAME}"
    }

    popd # ${FOLDER}

    Write-Host "Device sync ready !!!"
}

# Uninstall packages previously installed on the device
#   $FOLDER - (mandatory) path to the folder the packages were synced from
function global:qimsdk-local-packages-remove {
    param(
        [Parameter (Mandatory = $true)] [String]$FOLDER
    )

    # Resolve relative/wildcard/absolute path
    $FOLDER = Resolve-Path -Path "$FOLDER"

    pushd ${FOLDER}

    Invoke-Expression "adb push uninstall.sh /tmp/"

    Invoke-Expression "adb shell `"source /tmp/uninstall.sh`""
    if ($LastExitCode -ne 0) {
        throw "Uninstall packages failed !!!";
    }

    Remove-Item uninstall.sh

    popd # ${FOLDER}

    Write-Host "Packages uninstalled !!!"
}

# Print help
Write-Host "qimsdk-local-sync"
Write-Host "    must be invoked to sync packages with the device from specified folder"
Write-Host "qimsdk-local-packages-remove"
Write-Host "    must be invoked to uninstall packages previously installed on the device"
