# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import pathlib
import os
import json
import argparse
import sys

class Updater:
    class Platform:
        def __init__(self, name: str, qimsdk_targets_dir: str):
            self.name = name
            self.target_json = os.path.join(
                qimsdk_targets_dir,
                f"{self.name}.json"
            )

    def __init__(self, path_to_config_json: pathlib.Path, platform_type=Platform):
        self.supported_targets = list(str())

        with open(path_to_config_json, "r") as config_json:
            self.config_json_content = json.load(config_json)

            self.supported_targets = self.config_json_content['Supported_targets']
            self.solution_microservices_path = self.config_json_content[
                'Solution_Microservices_Dir']

        qimsdk_targets_dir = os.path.dirname(path_to_config_json)

        self.platforms = list()

        for target in self.supported_targets:
            self.platforms.append(
                platform_type(target, qimsdk_targets_dir)
            )

class ShellUpdater(Updater):
    class ExtendedPlatform(Updater.Platform):
        def __init__(self, name, qimsdk_targets_dir):
            super().__init__(name, qimsdk_targets_dir)

            with open(self.target_json, "r") as config_json:
                json_data = json.load(config_json)

            self.exports = list(json_data['Exports'])

            self.run_cmd = str()

    def __init__(self, path_to_config_json):
        super().__init__(path_to_config_json, self.ExtendedPlatform)

        self.docker_runs = self.__grep_docker_run_shell()

    def __grep_docker_run_shell(self) -> list:
        microservices_docker_runs = list()

        for root, _, files in os.walk(self.solution_microservices_path):
            for file in files:
                result = os.path.join(root, file)

                if "docker_run.sh" in result:
                    microservices_docker_runs.append(result)

        return microservices_docker_runs

    def update(self):

        for platform in self.platforms:
            platform.run_cmd = "docker run -it -d --net host --device qualcomm.com/device=cdi-hw-acc"

            for export in platform.exports:
                platform.run_cmd += f" -e {export}"

            platform.run_cmd += " -h qimsdk --user qimsdk --name qimsdk qimsdk"
            platform.run_cmd += "\n"

    def dump(self):
        for docker_run in self.docker_runs:

            with open(docker_run, "r+") as run_shell:
                copy_right = str()

                run_shell_content = run_shell.readlines()
                run_shell.seek(0)

                for line in run_shell_content:
                    if line.startswith("#"):
                        copy_right += line

                copy_right += "\n"

                for platform in self.platforms:
                    if platform.name in docker_run:
                        dump = copy_right + platform.run_cmd

                        run_shell.write(dump)
                        run_shell.truncate()


def parse_arguments():
    parser = argparse.ArgumentParser()

    parser.add_argument("-j", "--json", dest="path_to_config_json",
                        required=True, help="Path to config json of qimsdk")

    parser.add_argument("action",
                        choices=['ShellUpdater'],
                        help="<ShellUpdater>")

    return parser.parse_args()

def main():
    args = parse_arguments()

    updater_map = {
        "ShellUpdater": ShellUpdater
    }

    updater = updater_map[args.action](
        args.path_to_config_json
    )

    updater.update()
    updater.dump()


if __name__ == "__main__":
    sys.exit(main())
