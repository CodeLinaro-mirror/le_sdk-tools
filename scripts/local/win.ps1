# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

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

            Invoke-Expression "adb shell `"dpkg --install --force-all /tmp/${PACKAGE_NAME}`""
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

            Invoke-Expression "adb shell `"opkg --force-depends --force-reinstall --force-overwrite install /tmp/${PACKAGE_NAME}`""
            if ($LastExitCode -ne 0) {
                Invoke-Expression "adb shell `"rm -f /tmp/${PACKAGE_NAME}`""
                popd # ${FOLDER}
                throw "Install package to device failed !!!";
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
