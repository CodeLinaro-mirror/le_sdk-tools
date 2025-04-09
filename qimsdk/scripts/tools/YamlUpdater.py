# Copyright (c) 2025 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import yaml
import pathlib
import os
import json
import argparse
import sys


class ExtendedDumper(yaml.Dumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(ExtendedDumper, self).increase_indent(flow, False)


class Json2Yaml():
    def __init__(self, path_to_json: pathlib.Path, path_to_yaml: pathlib.Path):

        self.path_to_yaml = path_to_yaml
        self.copy_right = str()

        with open(path_to_json, "r") as config_json:
            self.json_data = json.load(config_json)

        with open(path_to_yaml, "r") as yaml_file:
            self.yaml_data = yaml.safe_load(yaml_file)

        with open(path_to_yaml, "r") as yaml_file:
            yaml_content = yaml_file.readlines()

            for line in yaml_content:
                if line.startswith("#"):
                    self.copy_right += line

        self.copy_right += "\n"

    def convert(self):
        self.yaml_data['services']['qimsdk']['volumes'] = self.json_data[
            'Platform_Libraries_To_Mount']
        self.yaml_data['services']['qimsdk']['devices'] = self.json_data[
            'Platform_Specific_Mappings']

        index = 0
        for volume in self.yaml_data['services']['qimsdk']['volumes']:
            self.yaml_data['services']['qimsdk']['volumes'][index] = f"{volume}:{volume}"
            index += 1

    def dump(self):
        with open(self.path_to_yaml, 'w') as yaml_file:
            yaml_file.writelines(self.copy_right)

        with open(self.path_to_yaml, 'a') as yaml_file:
            yaml.dump(self.yaml_data,
                      yaml_file,
                      sort_keys=False,
                      Dumper=ExtendedDumper)


class Updater:
    class Platform:
        def __init__(self, name: str, qimsdk_targets_dir: str):
            self.name = name
            self.target_json = os.path.join(
                qimsdk_targets_dir,
                f"mappings_{self.name}.json"
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


class YamlUpdater(Updater):
    def __init__(self, path_to_config_json):
        super().__init__(path_to_config_json)

        self.destination_docker_composes = self.__grep_docker_compose()

        self.json2yaml_converters = list()

        for docker_compose in self.destination_docker_composes:
            for platform in self.platforms:
                if platform.name in docker_compose:

                    self.json2yaml_converters.append(
                        Json2Yaml(platform.target_json, docker_compose)
                    )

    def __grep_docker_compose(self) -> list:
        microservices_docker_composes = list()

        for root, _, files in os.walk(self.solution_microservices_path):
            for file in files:
                result = os.path.join(root, file)

                if "docker-compose" in result:
                    microservices_docker_composes.append(result)

        return microservices_docker_composes

    def update(self):
        for json2yaml in self.json2yaml_converters:
            json2yaml.convert()

    def dump(self):
        for json2yaml in self.json2yaml_converters:
            json2yaml.dump()


class ShellUpdater(Updater):
    class ExtendedPlatform(Updater.Platform):
        def __init__(self, name, qimsdk_targets_dir):
            super().__init__(name, qimsdk_targets_dir)

            with open(self.target_json, "r") as config_json:
                json_data = json.load(config_json)

            self.devices = list(json_data['Platform_Specific_Mappings'])
            self.volumes = list(json_data['Platform_Libraries_To_Mount'])
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
            platform.run_cmd = "docker run -it -d --net host"

            for device in platform.devices:
                platform.run_cmd += f" --device {device}"

            for volume in platform.volumes:
                platform.run_cmd += f" -v {volume}:{volume}"

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
                        choices=['ShellUpdater', 'YamlUpdater'],
                        help="<ShellUpdater/YamlUpdater>")

    return parser.parse_args()


def main():
    args = parse_arguments()

    updater_map = {
        "YamlUpdater": YamlUpdater,
        "ShellUpdater": ShellUpdater
    }

    updater = updater_map[args.action](
        args.path_to_config_json
    )

    updater.update()
    updater.dump()


if __name__ == "__main__":
    sys.exit(main())
