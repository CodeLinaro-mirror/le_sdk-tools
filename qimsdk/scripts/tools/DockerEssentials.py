# Copyright (c) 2025 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import os
import argparse
import tempfile
import subprocess
import json
from functools import partial
from colorama import Fore

class DeviceCommandException(Exception):
    def __init__(self, msg: str):
        super().__init__(Fore.RED + msg)

def print_green(msg: str):
    print(Fore.GREEN + msg)
    print(Fore.RESET)

class Device():
    def __init__(self, device_id = "") -> None:
        self.device_id = device_id
        self.rc_file = "rc.txt"
        self.path_to_rc_file = os.path.join("/tmp/", self.rc_file)

    def execute(self, cmd) -> str:
        device_cmd = f"{cmd}; echo $? > {self.path_to_rc_file}"

        completed_process = subprocess.run(
            ["adb", "-s", self.device_id, "shell", device_cmd],
            capture_output=True
        )

        if (completed_process.returncode != 0):
            raise DeviceCommandException(f"Executing Command {device_cmd} failed: !!!")

        tmp_dir = tempfile.TemporaryDirectory()

        self.pull(self.path_to_rc_file, tmp_dir.name)

        remove_cmd = f"rm -f {self.path_to_rc_file}"

        subprocess.run(["adb", "-s", self.device_id, "shell", remove_cmd])

        path_to_rc_file_in_host = os.path.join(
            tmp_dir.name,
            self.rc_file
        )

        with open(f"{path_to_rc_file_in_host}", "r") as rc_file:
            rc = rc_file.readline()

        stdout = completed_process.stdout.decode("utf-8")

        if int(rc) != 0:
            stderr = "ERROR: " + completed_process.stderr.decode("utf-8")
            raise DeviceCommandException(f"Command {cmd} return code is not 0 !!!\n{stderr}\n{stdout}")

        return stdout

    def push(self, src, dst):
        push_cmd = f"adb -s {self.device_id} push {src} {dst}"

        completed_process = subprocess.run(push_cmd.split())

        if completed_process.returncode != 0:
            failed_cmd = " ".join(completed_process.args)
            raise DeviceCommandException(f"FAILED: {failed_cmd}")

    def pull(self, src, dst):
        pull_cmd = f"adb -s {self.device_id} pull {src} {dst}"

        completed_process = subprocess.run(pull_cmd.split())

        if completed_process.returncode != 0:
            failed_cmd = " ".join(completed_process.args)

            raise DeviceCommandException(f"FAILED: {failed_cmd}")


class Docker():
    def __init__(self, config_json: str):

        basename = os.path.basename(config_json)

        self.targets_dir = config_json.replace(basename, "")

        with open(config_json, "r") as json_fd:
            json_content = json.load(json_fd)

            container_tag = str(json_content['Additional_tag_container'])
            image_tag = str(json_content['Additional_tag_image'])

            self.container_name = "qimsdk"
            self.image_name = "qimsdk"

            if "" != container_tag:
                self.container_name += "-" + container_tag

            if "" != image_tag:
                self.image_name += "-" + image_tag

            self.docker_image_path = str(json_content['Docker_image_path'])
            self.device_id = str(json_content['Target_device_ID'])
            self.platforms = list(json_content['Supported_targets'])

        self.device = Device(self.device_id)

        self.machine = self.device.execute(
            "cat /sys/devices/soc0/machine"
        )

        self.machine = self.machine.strip()

    def device_load_image(self):
        file_name = self.image_name + ".tar"

        device_destination = "/data/docker_images/"

        self.device.execute(f"mkdir -p {device_destination}")

        self.device.push(
            f"{self.docker_image_path}/.",
            f"{device_destination}"
        )

        device_docker_image_tar = os.path.join(
            device_destination,
            file_name
        )

        self.device.execute(
            f"docker load -i {device_docker_image_tar}"
        )

        self.device.execute(
            f"rm {device_docker_image_tar}"
        )

        print_green("Device load image successful !!!")

    def device_run_container(self):

        tmp_dir = tempfile.TemporaryDirectory()

        self.target_platform = str()

        for platform in self.platforms:

            mappings_json = os.path.join(
                self.targets_dir, f"mappings_{platform}.json")

            with open(mappings_json, "r") as json_fd:
                json_content = json.load(json_fd)

                self.platform_specific_maps_array = list(
                    json_content['Platform_Specific_Mappings']
                )

                self.platform_specific_libs_array = list(
                    json_content['Platform_Libraries_To_Mount']
                )

                self.exports = list(
                    json_content['Exports']
                )

                self.list_of_socs = json_content['Soc']

            platform_specific_maps_array = str()
            platform_specific_libs_array = str()
            exports = str()

            for map in self.platform_specific_maps_array:
                platform_specific_maps_array += f"--device {map} "

            for map in self.platform_specific_libs_array:
                platform_specific_libs_array += f"-v {map}:{map} "

            for export in self.exports:
                exports += f"-e {export} "

            docker_run_cmd = f"docker run -it -d --net host                    \
                    {platform_specific_maps_array}                             \
                    {platform_specific_libs_array} {exports}                   \
                    -h {self.container_name}                                   \
                    --user qimsdk --name {self.container_name} {self.image_name}"

            result_file = os.path.join(
                tmp_dir.name, f"docker_run_{platform}.sh")

            with open(result_file, "w") as result_fd:
                result_fd.write(docker_run_cmd)

            for soc in self.list_of_socs:
                if self.machine == soc:
                    self.target_platform = str(platform)

        shell_to_deploy = os.path.join(
            tmp_dir.name, f"docker_run_{self.target_platform}.sh"
        )

        self.device.push(shell_to_deploy, "/tmp/")

        self.device.execute(
            f"source /tmp/docker_run_{self.target_platform}.sh")

        print_green("Device run container successful !!!")

    def device_load_artifacts(self, variant):
        device_dev_dir = "/tmp/qti/development/"

        self.device.execute(
            f"mkdir -p {device_dev_dir}"
        )

        dev_artifacts_tar = os.path.join(
            self.docker_image_path,
            f"qimsdk_dev_artifacts_{variant}.tar"
        )

        self.device.push(
            dev_artifacts_tar,
            device_dev_dir
        )

        self.device.execute(
            f"cd {device_dev_dir}                                           && \
            tar -xf {device_dev_dir}/qimsdk_dev_artifacts_{variant}.tar     && \
            docker cp usr {self.container_name}:/"
        )

        self.device.execute(
            f"rm -rf {device_dev_dir}/usr"
        )

        self.device.execute(
            f"rm -f {device_dev_dir}/qimsdk_dev_artifacts_{variant}.tar"
        )

        print_green(
            f"Device load artifacts: qimsdk_dev_artifacts_{variant}.tar successfull !!!")


def parse_arguments():
    parser = argparse.ArgumentParser()

    parser.add_argument("-j", "--json", dest="path_to_config_json", required=True,
                        help="Path to config json of qimsdk")

    parser.add_argument("-v", "--variant", dest="variant", required=False,
                        help="artifacts variant - release or debug")

    parser.add_argument("action",
                        choices=['load_image',
                                 'run_container', 'load_artifacts'],
                        help="<load_image/run_container/load_artifacts>")

    return parser.parse_args()


def main():
    args = parse_arguments()

    try:
        docker = Docker(args.path_to_config_json)
    except DeviceCommandException as exception:
        print(exception)

    function_map = {
        "load_image": docker.device_load_image,
        "run_container": docker.device_run_container,
        "load_artifacts": partial(docker.device_load_artifacts, args.variant),
    }

    try:
        do_docker = function_map[args.action]
        do_docker()
    except DeviceCommandException as exception:
        print(exception)


if __name__ == "__main__":
    main()
