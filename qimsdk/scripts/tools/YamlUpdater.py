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


class YamlUpdater:
    class Platform:
        def __init__(self, name: str, qimsdk_targets_dir: str):
            self.name = name
            self.target_json = os.path.join(
                qimsdk_targets_dir,
                f"mappings_{self.name}.json"
            )

    def __init__(self, path_to_config_json: pathlib.Path, destination_docker_composes: list):

        self.destination_docker_composes = destination_docker_composes

        self.supported_targets = list(str())

        with open(path_to_config_json, "r") as config_json:
            self.config_json_content = json.load(config_json)
            self.supported_targets = self.config_json_content['Supported_targets']

        qimsdk_targets_dir = os.path.dirname(path_to_config_json)

        self.platforms = list()

        for target in self.supported_targets:
            self.platforms.append(
                self.Platform(target, qimsdk_targets_dir)
            )

        self.json2yaml_converters = list()

        for docker_compose in self.destination_docker_composes:
            for platform in self.platforms:
                if platform.name in docker_compose:

                    self.json2yaml_converters.append(
                        Json2Yaml(platform.target_json, docker_compose)
                    )

    def update(self):
        for json2yaml in self.json2yaml_converters:
            json2yaml.convert()

    def dump(self):
        for json2yaml in self.json2yaml_converters:
            json2yaml.dump()


def grep_docker_compose(solution_microservices_path: pathlib.Path) -> list:
    microservices_docker_composes = list()

    for root, _, files in os.walk(solution_microservices_path):
        for file in files:
            result = os.path.join(root, file)

            if "docker-compose" in result:
                microservices_docker_composes.append(result)

    return microservices_docker_composes


def parse_arguments():
    parser = argparse.ArgumentParser()

    parser.add_argument("-j", "--json", dest="path_to_config_json",
                        required=True, help="Path to config json of qimsdk")

    parser.add_argument("-s", "--solutions-microservices", dest="solutions_microservices",
                        required=True, help="Path to solutions-microservices")

    return parser.parse_args()


def main():
    args = parse_arguments()

    solution_microservices_path = pathlib.Path(args.solutions_microservices)

    microservices_docker_composes = grep_docker_compose(
        solution_microservices_path)

    yaml_updater = YamlUpdater(
        args.path_to_config_json, microservices_docker_composes)

    yaml_updater.update()
    yaml_updater.dump()

    print(f"Success: docker compose files in {solution_microservices_path} have been updated!")


if __name__ == "__main__":
    sys.exit(main())
