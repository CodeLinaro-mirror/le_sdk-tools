# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

$global:QIMSDK_ESDK_DEVICE_INSTALL_PREFIX = ""

# Propagate errors from adb shell
#   $1 - (mandatory) device command to be executed
function global:qimsdk-local-device-command {
    param (
        [Parameter (Mandatory = $true)] [string]${CMD}
    )

    adb shell "${CMD} && echo 0 > /tmp/rc.txt"
    if ($LastExitCode -ne 0) {
        echo "Executing Command ${CMD} failed !!!";
        return 1;
    }

    ${TMP_DIR} = [System.IO.Path]::GetTempPath()

    adb pull /tmp/rc.txt ${TMP_DIR} 2>&1 | Out-null
    if ($LastExitCode -ne 0) {
        echo "${CMD} failed on device !!!";
        return 2;
    }

    adb shell "rm -f /tmp/rc.txt"
    if ($LastExitCode -ne 0) {
        echo "Command adb shell rm -f /tmp/rc.txt failed !!!";
        return 3;
    }
}

# Propagate the correct install path to opkg config
function global:qimsdk-local-set-opkg-prefix {
    $CMD = "dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}"
    qimsdk-local-device-command "grep '$CMD' /etc/opkg/opkg.conf" 2>&1 | Out-null
    if ($LastExitCode -ne 0) {
        qimsdk-local-device-command "sed -i '/qimsdk_install_path/d' /etc/opkg/opkg.conf"
        qimsdk-local-device-command "echo `"dest qimsdk_install_path ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}`" >> /etc/opkg/opkg.conf"
    }
}

# Check the installed packages on the target
#   $1 - (mandatory) path to the packages
function global:qimsdk-local-check-installed-packages {
    param(
        [Parameter (Mandatory = $true)] [String]$FOLDER
    )

    pushd ${FOLDER}

    $INITIALLY_INSTALLED_PKGS="initially_installed_pkgs.log"
    $SKIPPED_PKGS=""
    $PKGS= (Get-ChildItem ${FOLDER})
    qimsdk-local-device-command "opkg list-installed > ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/${INITIALLY_INSTALLED_PKGS} || dpkg --get-selections > ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/${INITIALLY_INSTALLED_PKGS}"
    Invoke-Expression "adb pull ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/${INITIALLY_INSTALLED_PKGS} $INITIALLY_INSTALLED_PKGS" 2>&1 | Out-null
    foreach($PACKAGE_NAME in Get-ChildItem ${FOLDER}) {
        $PACKAGE_NAME = (Get-Item ${PACKAGE_NAME} ).Name
        $PACKAGE_NAME_NO_VERSION="$PACKAGE_NAME".split("_")[0]
        if ($PACKAGE_NAME -eq "qim-sdk-install-prefix.txt") {continue;}
        if ($PACKAGE_NAME -eq "qim-sdk.sh") {continue;}
        if ($PACKAGE_NAME -eq "local_md5.log") {continue;}
        if ($PACKAGE_NAME -eq "device_sync.log") {continue;}
        if ($PACKAGE_NAME -eq "remote_sync.log") {continue;}
        if ($PACKAGE_NAME -eq "sdk-tools-git-logs.txt") {continue;}
        if ($PACKAGE_NAME -eq "uninstall.sh") {continue;}
        if ($PACKAGE_NAME -eq "initially_installed_pkgs.log") {continue;}
        $PKG_ALREADY_ON_DEVICE = (Select-String -Quiet -SimpleMatch -Pattern "$PACKAGE_NAME_NO_VERSION" -Path "$INITIALLY_INSTALLED_PKGS")
        if ($PKG_ALREADY_ON_DEVICE -eq $true) {
            Write-Host "$PACKAGE_NAME_NO_VERSION ($PACKAGE_NAME) is already installed on the target. Skipping..." -InformationAction Continue
            $SKIPPED_PKGS="$SKIPPED_PKGS $PACKAGE_NAME_NO_VERSION ($PACKAGE_NAME)"
        }
    }
    popd # ${FOLDER}
    if($SKIPPED_PKGS -ne ""){
        Write-Host "Overlapping Packages from Apps AU are : $SKIPPED_PKGS" -f red -b black -InformationAction Continue
        $confirm = Read-Host -Prompt "Are you sure you want to continue installtion for remaining packages (Y/N)"
        if ($confirm -eq 'y') {
            return 0;
        } else {
            return 1;
        }
    }
    return 0;
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
        popd # ${FOLDER}
        throw "Prefix variable not set !!!";
    }

    # Push sdk script to device
    Invoke-Expression "adb push qim-sdk.sh /etc/profile.d/"
    qimsdk-local-device-command "mkdir -p ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc"
    qimsdk-local-device-command "source /etc/profile.d/qim-sdk.sh"

    $check = qimsdk-local-check-installed-packages "$FOLDER"
    if ($check -ne 0) {
        popd # ${FOLDER}
        return;
    }

    if (Test-Path -Path "${FOLDER}\*" -Include *.ipk) {
        qimsdk-local-set-opkg-prefix
    }

    $REMOTE_LOG_FILE="remote_sync.log"
    $DEVICE_LOG_FILE="${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/device_sync.log"
    $DEVICE_PULLED_LOG_FILE="device_sync.log"
    $UNINSTALL_FILE="uninstall.sh"
    $INITIALLY_INSTALLED_PKGS="initially_installed_pkgs.log"

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
        if ($PACKAGE_NAME -eq "sdk-tools-git-logs.txt") {continue;}
        if ($PACKAGE_NAME -eq "uninstall.sh") {continue;}
        if ($PACKAGE_NAME -eq "initially_installed_pkgs.log") {continue;}

        $PKG_ALREADY_ON_DEVICE = (Select-String -Quiet -SimpleMatch -Pattern "$PACKAGE_NAME_NO_VERSION" -Path "$INITIALLY_INSTALLED_PKGS")
        if ($PKG_ALREADY_ON_DEVICE -eq $true) {continue;}

        if ($PACKAGE_FORMAT -eq $FORMAT_DEB) {
            Invoke-Expression "adb push ${PACKAGE_NAME} /tmp/${PACKAGE_NAME}"
            if ($LastExitCode -ne 0) {
                popd # ${FOLDER}
                throw "Push package to device failed !!!";
            }

            qimsdk-local-device-command "dpkg --instdir=${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX} --install --force-all /tmp/${PACKAGE_NAME}"
            if ($LastExitCode -ne 0) {
                qimsdk-local-device-command "rm -f /tmp/${PACKAGE_NAME}"
                Invoke-Expression "adb push $DEVICE_PULLED_LOG_FILE ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/$DEVICE_PULLED_LOG_FILE"
                popd # ${FOLDER}
                throw "Install package to device failed !!!";
            }
            Remove-Item ${PACKAGE_NAME}
            qimsdk-local-device-command "rm -f /tmp/${PACKAGE_NAME}"

            qimsdk-local-device-command "echo `"dpkg --remove --force-all ${PACKAGE_NAME_NO_VERSION}`" >> ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/${UNINSTALL_FILE}"
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
                Invoke-Expression "adb push $DEVICE_PULLED_LOG_FILE ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/$DEVICE_PULLED_LOG_FILE"
                popd # ${FOLDER}
                throw "Install package to device failed !!!";
            }
            Remove-Item ${PACKAGE_NAME}
            qimsdk-local-device-command "rm -f /tmp/${PACKAGE_NAME}"

            qimsdk-local-device-command "echo `"opkg remove --force-depends ${PACKAGE_NAME_NO_VERSION}`" >> ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/${UNINSTALL_FILE}"
        }
        (Get-Content $DEVICE_PULLED_LOG_FILE | Select-String -SimpleMatch -pattern "/${PACKAGE_NAME}" -notmatch) | Set-Content $DEVICE_PULLED_LOG_FILE
        echo "${CHECKSUM} /${PACKAGE_NAME}" | Out-File $DEVICE_PULLED_LOG_FILE -Append
    }

    Invoke-Expression "adb push $DEVICE_PULLED_LOG_FILE ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/$DEVICE_PULLED_LOG_FILE"
    Remove-Item "${DEVICE_PULLED_LOG_FILE}"
    if (Test-Path -Path "${FOLDER}\*" -Include "${REMOTE_LOG_FILE}") {
        Remove-Item "${REMOTE_LOG_FILE}"
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
    $QIMSDK_ESDK_DEVICE_INSTALL_PREFIX = ( gc qim-sdk-install-prefix.txt )
    popd # ${FOLDER}

    $QIMSDK_ESDK_DEVICE_INSTALL_PREFIX = ( gc qim-sdk-install-prefix.txt )

    qimsdk-local-device-command "source ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/uninstall.sh"

    qimsdk-local-device-command "rm -rf ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/uninstall.sh"
    qimsdk-local-device-command "rm -rf ${QIMSDK_ESDK_DEVICE_INSTALL_PREFIX}/etc/device_sync.log"

    popd # ${FOLDER}

    Write-Host "Packages uninstalled !!!"
}

# Print help
Write-Host "qimsdk-local-sync"
Write-Host "    must be invoked to sync packages with the device from specified folder"
Write-Host "qimsdk-local-packages-remove"
Write-Host "    must be invoked to uninstall packages previously installed on the device"
