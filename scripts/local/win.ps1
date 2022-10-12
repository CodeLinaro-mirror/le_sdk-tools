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

        Invoke-Expression "adb shell rm -f /tmp/${PACKAGE_NAME}"
        Remove-Item "${FILE}"
    }

    Write-Host "Device sync ready !!!"
}

# Print help
Write-Host "qimsdk-local-sync"
Write-Host "    must be invoked to sync packages with the device from specified folder"
