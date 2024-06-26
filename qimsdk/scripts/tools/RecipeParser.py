# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import tempfile
import os
import sys
import pathlib
import json
import argparse


class RecipeParser():

    # Init of RecipeParser
    # Reads the recipes and buffers them in dictionary (plugin : content)

    def __init__(self, path_to_layers: pathlib.Path, path_to_config_json: pathlib.Path) -> None:

        with open(f"{path_to_config_json}", "r") as json_file:
            json_content = json_file.read()

            info_from_json = json.loads(json_content)

            self.platform = info_from_json["Target_platform"]

        # Append bitbake library path to the system path
        # to be able to import Non-standart modules
        # aka bb modules from eSDK
        bitbake_library_path = os.path.join(
            path_to_layers, "poky/bitbake/lib/")

        if not bitbake_library_path in sys.path:
            sys.path.append(bitbake_library_path)
        del bitbake_library_path

        import bb
        import bb.siggen
        import bb.data
        import bb.parse

        path_to_gstreamer_recipes = os.path.join(
            path_to_layers, "meta-qti-gst/recipes-gst/gstreamer")

        if not os.path.exists(path_to_gstreamer_recipes):
            path_to_gstreamer_recipes = os.path.join(
                path_to_layers, "meta-qcom-qim-product-sdk/recipes-gst/gstreamer")

        if not os.path.exists(path_to_gstreamer_recipes):
            raise Exception("Gstreamer recipes path cannot be reached !!!")

        self.plugin_to_content = dict()

        for file in os.listdir(path_to_gstreamer_recipes):

            # Skip NON bb files
            if not file.endswith(".bb"):
                continue

            full_path_to_bb_file = os.path.join(
                path_to_gstreamer_recipes, file)

            # Read the recipe
            with open(full_path_to_bb_file) as bb_file_content:
                self.plugin_to_content[file] = bb_file_content.read()

            # Set BBPATH as {path_to_layers}/poky/meta
            # to be able to inherit cmake or pkgconfig
            self.plugin_to_content[file] =                                                         \
                f"BBPATH = \"{path_to_layers}/poky/meta\"\n"                                       \
                +                                                                                  \
                self.plugin_to_content[file]

        self.plugin_to_cmake_flags = dict()

    # Process method of RecipeParser
    # Take the buffered content from dictionary (plugin : content)
    # And parse it to dictionary (plugin : cmake flags)

    def process(self):

        for content in self.plugin_to_content.values():

            current_data_smart = bb.data.init()
            bb.parse.siggen = bb.siggen.init(current_data_smart)

            my_temp_file = self.__parse_helper(content)

            bb_parsed = bb.parse.handle(
                my_temp_file.name, current_data_smart)['']

            bb_parsed.setVar("OVERRIDES", self.platform)

            extra_oecmake_string = bb_parsed.getVar("EXTRA_OECMAKE")

            extra_oecmake_string = extra_oecmake_string.replace(
                '${PACKAGECONFIG_CONFARGS}', '')

            splited_string = list(str())
            splited_string = extra_oecmake_string.split(' -D')

            filtred_extra_oecmake = list(str())

            string = str()

            for string in splited_string:

                # Skip NON translated variables
                # like ${SOME_VARIABLE}
                found_non_translated_variable = string.find("${")

                if found_non_translated_variable != -1:
                    continue

                # Skip GST_VERSION_REQUIRED
                found_gst_version_required = string.find(
                    "GST_VERSION_REQUIRED")

                if found_gst_version_required != -1:
                    continue

                filtred_extra_oecmake.append(string)

            cmake_flags = ' -D'.join(filtred_extra_oecmake)
            cmake_flags += ' '

            SRC_URI_string = bb_parsed.getVar("SRC_URI")

            # Remove prefix from SRC_URI to get plugin name
            plugin = SRC_URI_string[len("file://"):]
            plugin = plugin.replace("-", "_")

            self.plugin_to_cmake_flags[plugin] = cmake_flags

    # Export to json method of RecipeParser
    # Take the buffered content from dictionary (plugin : cmake flags)
    # Export it to json file ("plugin" : "cmake flags")

    def export_to_json(self, path_to_tmp: pathlib.Path):

        path_to_json = os.path.join(path_to_tmp, "cmake_flags.json")

        with open(path_to_json, "w") as cmake_flags_json:
            json_buffer = json.dumps(self.plugin_to_cmake_flags, indent=4)
            cmake_flags_json.write(json_buffer)

    def __parse_helper(self, content, suffix=".bb"):

        temp_file = tempfile.NamedTemporaryFile(suffix=suffix)
        temp_file.write(bytes(content, "utf-8"))
        temp_file.flush()
        os.chdir(os.path.dirname(temp_file.name))

        return temp_file

# Parse arguments function
# Parses input arguments
def parse_arguments() -> str:
    parser = argparse.ArgumentParser()

    parser.add_argument("-l", "--layers", dest="path_to_layers", required=True,
                        help="Path to layers directory of eSDK")

    parser.add_argument("-j", "--json", dest="path_to_config_json", required=True,
                        help="Path to config json of the current project")

    parser.add_argument("-t", "--tmp", dest="path_to_tmp", required=True,
                        help="Path to tmp directory of the current project")

    return parser.parse_args()

# Main
def main():
    args = parse_arguments()

    recipe_parser = RecipeParser(args.path_to_layers, args.path_to_config_json)

    recipe_parser.process()
    recipe_parser.export_to_json(args.path_to_tmp)

    return 0


if __name__ == "__main__":
    main()
