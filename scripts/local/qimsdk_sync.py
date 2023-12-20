# Copyright (c) 2023-2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import argparse
import os
import pathlib
import tempfile
import subprocess

class Singleton(object):
    def __new__(cls):
        if not hasattr(cls, 'instance'):
            cls.instance = super(Singleton, cls).__new__(cls)
        return cls.instance

class Device(Singleton):
    def __init__(self) -> None:
        super().__init__()

        self.init_shell_destination = "/etc/profile.d/"
        self.init_shell_name = "qim-sdk.sh"

    def execute(self, cmd) -> int:
        return self.__inner_execute(cmd)

    def push(self, src, dst) -> int:
        push_cmd = f"adb push {src} {dst}"

        completed_process = subprocess.run(push_cmd.split())

        if completed_process.returncode != 0:
            failed_cmd = " ".join(completed_process.args)
            print(f"FAILED: {failed_cmd} command")
            return completed_process.returncode

        return 0

    def pull(self, src, dst) -> int:
        pull_cmd = f"adb pull {src} {dst}"

        completed_process = subprocess.run(pull_cmd.split())

        if completed_process.returncode != 0:
            failed_cmd = " ".join(completed_process.args)
            print(f"FAILED: {failed_cmd}")
            return completed_process.returncode

        return 0

    def set_install_prefix(self, install_prefix) -> int:
        self.install_prefix = install_prefix

        cmd = f"mkdir -p {self.install_prefix}/etc"

        completed_process = subprocess.run(["adb", "shell", cmd])

        if completed_process.returncode != 0:
            failed_cmd = " ".join(completed_process.args)
            print(f"FAILED: {failed_cmd}")
            return completed_process.returncode

        return 0

    def set_opkg_prefix(self) -> None:
        self.execute("sed -i '/qimsdk_install_path/d' /etc/opkg/opkg.conf")
        self.execute(f'echo "dest qimsdk_install_path {self.install_prefix}" >> /etc/opkg/opkg.conf')

    def __inner_execute(self, cmd) -> int:
        source_init_shell = f"source {self.init_shell_destination}/{self.init_shell_name}"

        device_cmd = f"{source_init_shell}; {cmd}; echo $? > /tmp/rc.txt"

        completed_process = subprocess.run(["adb", "shell", device_cmd])

        if completed_process.returncode != 0:
            print(f"Executing Command {device_cmd} failed !!!")
            return completed_process.returncode

        tmp_dir = tempfile.TemporaryDirectory()

        rc = self.pull("/tmp/rc.txt", tmp_dir.name)

        subprocess.run(["adb", "shell", "rm -f /tmp/rc.txt"])

        if rc != 0:
            tmp_dir.cleanup()
            print(f"Command {cmd} failed !!!")
            return rc

        with open(f"{tmp_dir.name}/rc.txt", "r") as rc_file:
            rc = rc_file.readline()

        if int(rc) != 0:
            print(f"Command ${cmd} return code is not 0 !!!")
            return rc

        return 0

    def deploy_init_shell(self, path_to_packages) -> int:

        init_shell_file = os.path.join(path_to_packages, self.init_shell_name)

        rc = self.push(init_shell_file, self.init_shell_destination)

        if rc != 0:
            print("FAILED: to push")
            return rc

        return 0

class Package:
    def __init__(self, file, path_to_packages) -> None:
        self.package = file
        self.path_to_packages = path_to_packages
        self.device = Device()

    def install(self) -> int:
        rc = self.device.execute(self.install_cmd)

        if rc != 0:
            print(f"FAILED: to install {self.package} to device")
            return rc

        full_path = os.path.join(self.path_to_packages, self.package)

        os.remove(full_path)

        return 0

    def sync(self) -> int:

        full_path = os.path.join(self.path_to_packages, self.package)

        rc = self.device.push(full_path, "/tmp/")

        if rc != 0:
            print(f"FAILED: to sync {full_path} to device")

        return rc

    def remove(self) -> int:
        rc = self.device.execute(self.remove_cmd)

        if rc != 0:
            print(f"FAILED: to remove {self.package} from device")

        return rc

class Ipk(Package):
    def __init__(self, file, path_to_packages) -> None:
        super().__init__(file, path_to_packages)

        self.device.set_opkg_prefix()

        self.install_cmd = f"opkg install -d qimsdk_install_path --force-reinstall --force-depends --force-overwrite /tmp/{self.package}"
        self.remove_cmd = f"opkg remove --force-depends {self.package}"

class Deb(Package):
    def __init__(self, file, path_to_packages) -> None:
        super().__init__(file, path_to_packages)

        self.install_cmd = f"dpkg --instdir={self.device.install_prefix} --install --force-all /tmp/{self.package}"
        self.remove_cmd = f"dpkg --remove --force-all {self.package}"

class Logs():
    def __init__(self, sync_log) -> None:
        with open(sync_log, "r") as sync_file:

            self.dictionary = dict()

            sync_info = [ line.strip().split() for line in sync_file.readlines() ]
            self.dictionary = { hash_: val for hash_, val in sync_info }

class DeviceLogs(Logs):
    def __init__(self, device_sync_log) -> None:

        if not os.path.isfile(device_sync_log):
            device = Device()

            cmd = f"touch {device.install_prefix}/etc/device_sync.log"

            rc = device.execute(cmd)

            if rc != 0:
                print(f"FAILED: to execute {cmd} on device")
                return

            rc = device.pull(f"{device.install_prefix}/etc/device_sync.log", device_sync_log)

            if rc != 0:
                print(f"FAILED: to pull device_sync.log from device")
                return

        self.device_sync_log = device_sync_log

        super().__init__(device_sync_log)

    def add(self, key, package):
        self.dictionary[key] = package

    def pop(self, key):
        self.dictionary.pop(key)

    def update_device_log_file(self) -> int:

        with open(self.device_sync_log, "w") as device_sync_file:

            for key, value in self.dictionary.items():
                device_sync_file.write(f"{key} {value} \n")

        return 0

def install_packages(path_to_packages) -> int:
    install_prefix = get_install_prefix(path_to_packages)

    device = Device()

    rc = device.set_install_prefix(install_prefix)

    if rc != 0:
        print("FAILED: to set install_prefix on device")
        return rc

    rc = device.deploy_init_shell(path_to_packages)

    if rc != 0:
        print(f"FAILED: to deploy qim-sdk.sh")
        return rc

    if os.path.isfile(os.path.join(path_to_packages, "local_md5.log")):
        log_file = "local_md5.log"
    else:
        log_file = "remote_sync.log"

    logs = Logs(os.path.join(path_to_packages, log_file))
    device_logs = DeviceLogs(os.path.join(path_to_packages, "device_sync.log"))

    # find missing hashes on device logs
    device_missing_hashes = set(logs.dictionary) - set(device_logs.dictionary)

    # create inverse dictionary of corresponding files names
    device_missing_files = {
        pathlib.Path(package_file).name : package_hash
            for package_hash, package_file in logs.dictionary.items()
                if package_hash in device_missing_hashes
    }

    # create list of packages that needs installation
    files_to_install = [
        {
            'name' : package_file,
            'ext' : pathlib.Path(package_file).suffix
        }

        for package_file in os.listdir(path_to_packages)
            if package_file in device_missing_files
    ]

    # installer factory
    installers = { '.ipk' : Ipk, '.deb' : Deb }

    for package_file in files_to_install:
        name, ext = package_file['name'], package_file['ext']
        package = installers[ext](name, path_to_packages)

        rc = package.sync()
        rc = package.install()

        if rc == 0:
            package_hash = device_missing_files[name]
            device_logs.add(package_hash, logs.dictionary[package_hash])

    rc = device_logs.update_device_log_file()
    if rc != 0:
        print("FAILED: to update device logs !!!")

    return rc

def remove_packges(path_to_packages) -> int:
    install_prefix = get_install_prefix(path_to_packages)

    if not install_prefix:
        print("ERROR: install_prefix is empty")
        return -1

    device = Device()

    rc = device.set_install_prefix(install_prefix)

    if rc != 0:
        print("FAILED: to set install_prefix on device")
        return rc

    device_logs = DeviceLogs(os.path.join(path_to_packages, "device_sync.log"))

    # create inverse dictionary of corresponding files names
    device_files = {
        pathlib.Path(package_file).name : package_hash
            for package_hash, package_file in device_logs.dictionary.items()
    }

    # create list of packages that needs installation
    files_to_remove = [
        {
            'name' : package_file,
            'ext' : pathlib.Path(package_file).suffix
        }

        for package_file in device_files
    ]

    # remove factory
    packages = { '.ipk' : Ipk, '.deb' : Deb }

    for package_file in files_to_remove:
        name, ext = package_file['name'], package_file['ext']
        package = packages[ext](name.split("_")[0], path_to_packages)

        rc = package.remove()

        if rc == 0:
            package_hash = device_files[name]
            device_logs.pop(package_hash)

    rc = device_logs.update_device_log_file()

    if rc != 0:
        print("FAILED: to update device logs !!!")

    return rc

def get_install_prefix(path_to_packages) -> str:

    qim_sdk_install_prefix = os.path.join(path_to_packages, "qim-sdk-install-prefix.txt")

    with open(qim_sdk_install_prefix, "r") as install_prefix_file:
        install_prefix = install_prefix_file.read()

    return install_prefix.strip()

def parse_arguments() -> str:
    parser = argparse.ArgumentParser()
    parser.add_argument("path_to_packages", type=pathlib.Path, help="Path to qim packages")
    parser.add_argument("action", choices=['install', 'remove'], help="<install/remove>")

    return parser.parse_args()

def main():
    try:
        args = parse_arguments()

        function_map = {'install' : install_packages, 'remove' : remove_packges }

        do_packages = function_map[args.action]

        rc = do_packages(args.path_to_packages)
    except Exception as error:
        print(error)
        exit(-1)

    exit(rc)

if __name__ == '__main__':
    main()
