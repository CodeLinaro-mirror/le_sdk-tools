# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

$global:QIMSDK_ESDK_DEVICE_INSTALL_PREFIX = ""

# Propagate errors from adb shell
#   $1 - (mandatory) device command to be executed
function global:qimsdk-local-device-command {
    param (
        [Parameter (Mandatory = $true)] [string]${CMD}
    )
    adb shell "${CMD} && echo 0 > /data/rc.txt"
    $rc = $LastExitCode

    if ($rc -ne 0) {
        echo "Executing Command ${CMD} failed !!!";
        return 1;
    }

    ${TMP_DIR} = [System.IO.Path]::GetTempPath()

    adb pull /data/rc.txt ${TMP_DIR} 2>&1 | Out-null
    $rc = $LastExitCode

    adb shell "rm -f /data/rc.txt"
    if ($rc -ne 0) {
        echo "Command ${CMD} failed !!!";
        return 2;
    }

    $rc = cat ${TMP_DIR}/rc.txt
    if ("$rc" -ne "0") {
        echo "Command ${CMD} return code is not 0 !!!";
        return 3;
    }

}

# Propagate the correct install path to opkg config
function global:qimsdk-local-set-opkg-prefix {
    qimsdk-local-device-command "cat /etc/opkg/opkg.conf | grep `"dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}`"" 2>&1 | Out-null
    if ($LastExitCode -ne 0) {
        qimsdk-local-device-command "sed -i '/qimsdk_install_path/d' /etc/opkg/opkg.conf"
        qimsdk-local-device-command "echo `"dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}`" >> /etc/opkg/opkg.conf"
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

    $FORMAT_IPK="ipk"
    $FORMAT_DEB="deb"

    pushd ${FOLDER}

    # Set global var
    $QIMSDK_ESDK_DEVICE_INSTALL_PREFIX = ( gc qim-sdk-install-prefix.txt )

    if ($QIMSDK_ESDK_DEVICE_INSTALL_PREFIX -eq "") {
        throw "Prefix variable not set !!!";
    }

    # Push sdk script to device
    Invoke-Expression "adb push qim-sdk.sh /etc/profile.d/"
    qimsdk-local-device-command "mkdir -p ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc"
    qimsdk-local-device-command "source /etc/profile.d/qim-sdk.sh"

    if (Test-Path -Path "${FOLDER}\*" -Include *.ipk) {
        qimsdk-local-set-opkg-prefix
    }

    $LOCAL_LOG_FILE="local_md5.log"
    $REMOTE_LOG_FILE="remote_sync.log"
    $DEVICE_LOG_FILE="${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/device_sync.log"
    $DEVICE_PULLED_LOG_FILE="device_sync.log"

    # Pull device sync log file
    qimsdk-local-device-command "[ -f ${DEVICE_LOG_FILE} ] || touch ${DEVICE_LOG_FILE}"
    Invoke-Expression "adb pull ${DEVICE_LOG_FILE} ${FOLDER}"

    foreach($PACKAGE_NAME in Get-ChildItem ${FOLDER}) {
        $PACKAGE_FORMAT= (Get-ChildItem ${PACKAGE_NAME}).Extension
        $PACKAGE_FORMAT="$PACKAGE_FORMAT".split(".")[1]
        $PACKAGE_NAME = (Get-Item ${PACKAGE_NAME} ).Name

        if ($PACKAGE_NAME -eq "qim-sdk-install-prefix.txt") {continue;}
        if ($PACKAGE_NAME -eq "qim-sdk.sh") {continue;}
        if ($PACKAGE_NAME -eq "local_md5.log") {continue;}
        if ($PACKAGE_NAME -eq "device_sync.log") {continue;}
        if ($PACKAGE_NAME -eq "remote_sync.log") {continue;}

        # Get Checksum for current package
        $CHECKSUM= (Select-String -SimpleMatch -Pattern "/${PACKAGE_NAME}" -Path "${LOCAL_LOG_FILE}")
        $CHECKSUM= "$CHECKSUM".split(":")[2]
        $CHECKSUM= "$CHECKSUM".split(" ")[0]

        # Check pulled device log to see if package already present
        $PKG_ALREADY_ON_DEVICE = (Select-String -Quiet -SimpleMatch -Pattern "$CHECKSUM" -Path "$DEVICE_PULLED_LOG_FILE")
            if ($PKG_ALREADY_ON_DEVICE -eq $false) {
                if ($PACKAGE_FORMAT -eq $FORMAT_DEB) {
                    Invoke-Expression "adb push ${PACKAGE_NAME} /tmp/"
                    if ($LastExitCode -ne 0) {
                        popd # ${FOLDER}
                        throw "Push package to device failed !!!";
                    }

                    qimsdk-local-device-command "dpkg --instdir=${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX} --install --force-all /tmp/${PACKAGE_NAME}"
                    if ($LastExitCode -ne 0) {
                        qimsdk-local-device-command "rm -f /tmp/${PACKAGE_NAME}"
                        Invoke-Expression "adb push $DEVICE_PULLED_LOG_FILE ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/"
                        popd # ${FOLDER}
                        throw "Install package to device failed !!!";
                    }
                    Remove-Item ${PACKAGE_NAME}
                    qimsdk-local-device-command "rm -f /tmp/${PACKAGE_NAME}"
                }

                if ($PACKAGE_FORMAT -eq $FORMAT_IPK) {
                    Invoke-Expression "adb push ${PACKAGE_NAME} /tmp/"
                    if ($LastExitCode -ne 0) {
                        popd # ${FOLDER}
                        throw "Push package to device failed !!!";
                    }

                    qimsdk-local-device-command "opkg install -d qimsdk_install_path --force-depends --force-reinstall --force-overwrite /tmp/${PACKAGE_NAME}"
                    if ($LastExitCode -ne 0) {
                        qimsdk-local-device-command "rm -f /tmp/${PACKAGE_NAME}"
                        Invoke-Expression "adb push $DEVICE_PULLED_LOG_FILE ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/"
                        popd # ${FOLDER}
                        throw "Install package to device failed !!!";
                    }
                    Remove-Item ${PACKAGE_NAME}
                    qimsdk-local-device-command "rm -f /tmp/${PACKAGE_NAME}"
                }
                (Get-Content $DEVICE_PULLED_LOG_FILE | Select-String -SimpleMatch -pattern "/${PACKAGE_NAME}" -notmatch) | Set-Content $DEVICE_PULLED_LOG_FILE
                echo "${CHECKSUM} /${PACKAGE_NAME}" | Out-File $DEVICE_PULLED_LOG_FILE -Append
            }
    }

    Invoke-Expression "adb push $DEVICE_PULLED_LOG_FILE ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/"
    Remove-Item "${DEVICE_PULLED_LOG_FILE}"
    Remove-Item "${LOCAL_LOG_FILE}"
    Remove-Item "${REMOTE_LOG_FILE}"
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
    $QIMSDK_ESDK_DEVICE_INSTALL_PREFIX = ( gc qim-sdk-install-prefix.txt )
    popd # ${FOLDER}

    qimsdk-local-device-command "rm -rf ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}"
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
