# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Sync packages with the device from specified folder
#   $FOLDER - (mandatory) path to the packages to be synced
function global:qimsdk-local-sync {
    param(
        [Parameter (Mandatory = $true)] [String]$FOLDER
    )

    foreach($PACKAGE_NAME in Get-ChildItem ${FOLDER}) {
        $FILE=Join-Path -Path "${FOLDER}" -ChildPath "${PACKAGE_NAME}"

        Invoke-Expression "adb push ${FILE} /tmp/"
        if ($LastExitCode -ne 0) {
            throw "Push package to device failed !!!";
        }

        Invoke-Expression "adb shell opkg --force-depends --force-reinstall --force-overwrite install /tmp/${PACKAGE_NAME}"
        if ($LastExitCode -ne 0) {
            Invoke-Expression "adb shell rm -f /tmp/${PACKAGE_NAME}"
            throw "Install package to device failed !!!";
        }

        $PACKAGE_NAME_NO_VERSION="$PACKAGE_NAME".split("_")[0]
        Get-Content -Path "${FOLDER}\uninstall.sh" | Select-String -Pattern "opkg remove --force-depends ${PACKAGE_NAME_NO_VERSION}"

        if ($LastExitCode -ne 0) {
            "opkg remove --force-depends ${PACKAGE_NAME_NO_VERSION}" | Out-File "${FOLDER}\uninstall.sh"
            if ($LastExitCode -ne 0) {
                Invoke-Expression "adb shell rm -f /tmp/${PACKAGE_NAME}"
                throw "Install package to device failed !!!";
            }
        }

        Invoke-Expression "adb shell rm -f /tmp/${PACKAGE_NAME}"
        Remove-Item "${FILE}"
    }

    Write-Host "Device sync ready !!!"
}

# Uninstall packages previously installed on the device
#   $FOLDER - (mandatory) path to the packages to be synced
function global:qimsdk-local-packages-remove {
    param(
        [Parameter (Mandatory = $true)] [String]$FOLDER
    )

    Invoke-Expression "adb push ${FOLDER}\uninstall.sh /tmp/"

    Invoke-Expression "adb shell `"source /tmp/uninstall.sh`""
    if ($LastExitCode -ne 0) {
        throw "Uninstall packages failed !!!";
    }

    Write-Host "Packages uninstalled !!!"
}

# Print help
Write-Host "qimsdk-local-sync"
Write-Host "    must be invoked to sync packages with the device from specified folder"
Write-Host "qimsdk-local-packages-remove"
Write-Host "    must be invoked to uninstall packages previously installed on the device"
