# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import tempfile
import os
import sys
import pathlib
import json
import argparse
import glob

from abc import ABC, abstractmethod


class Parsable(ABC):
    def __init__(self, path_to_layers: pathlib.Path) -> None:
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

        self.path_to_gstreamer_recipes = os.path.join(
            path_to_layers, "meta-qti-gst/recipes-gst/gstreamer")

        if not os.path.exists(self.path_to_gstreamer_recipes):
            self.path_to_gstreamer_recipes = os.path.join(
                path_to_layers, "meta-qcom-qim-product-sdk/recipes-gst/gstreamer")

        if not os.path.exists(self.path_to_gstreamer_recipes):
            raise Exception("Gstreamer recipes path cannot be reached !!!")

    def _parse_helper(self, content, suffix=".bb"):

        temp_file = tempfile.NamedTemporaryFile(suffix=suffix)
        temp_file.write(bytes(content, "utf-8"))
        temp_file.flush()
        os.chdir(os.path.dirname(temp_file.name))

        return temp_file

    @abstractmethod
    def process(self):
        pass

    @abstractmethod
    def export_to_json(self, path_to_tmp: pathlib.Path):
        pass


class BBPatchParser(Parsable):
    class Recipe():
        class BitBakeFile():
            def __init__(self) -> None:
                self.path = str()
                self.name = str()

        def __init__(self) -> None:
            self.bb = self.BitBakeFile()
            self.bb_append = self.BitBakeFile()

            self.patches = list(str())
            self.content = str()

            self.title = str()

    def __init__(self, path_to_layers: pathlib.Path, path_to_config_json: pathlib.Path) -> None:

        super().__init__(path_to_layers)

        self.path_to_layers = path_to_layers

        self.path_to_wayland_protocols_bbappend = os.path.join(
            path_to_layers, "meta-qti-display/recipes-graphics/wayland/")

        if not os.path.exists(self.path_to_wayland_protocols_bbappend):
            self.path_to_wayland_protocols_bbappend = os.path.join(
                path_to_layers, "meta-qcom-hwe/recipes-graphics/wayland/")

        if not os.path.exists(self.path_to_wayland_protocols_bbappend):
            raise Exception("Wayland protocols path cannot be reached !!!")

        self.path_to_wayland_protocols_bb = os.path.join(
            path_to_layers, "poky/meta/recipes-graphics/wayland/")

        if not os.path.exists(self.path_to_wayland_protocols_bb):
            raise Exception("Gstreamer recipes path cannot be reached !!!")

        self.path_to_gstreamer_recipes_bb = os.path.join(
            path_to_layers, "poky/meta/recipes-multimedia/gstreamer/")

        if not os.path.exists(self.path_to_gstreamer_recipes_bb):
            raise Exception("Gstreamer recipes path cannot be reached !!!")

        self.recipes = {
            "wayland": self.Recipe(),
            "plugins_good": self.Recipe(),
            "plugins_bad": self.Recipe(),
        }

        self.recipes["wayland"].title = "wayland"
        self.recipes["plugins_good"].title = "plugins_good"
        self.recipes["plugins_bad"].title = "plugins_bad"

        self.recipes["wayland"].bb_append.name = "wayland-protocols_%.bbappend"
        self.recipes["plugins_good"].bb_append.name = "gstreamer1.0-plugins-good_*%.bbappend"
        self.recipes["plugins_bad"].bb_append.name = "gstreamer1.0-plugins-bad_*%.bbappend"

        self.recipes["wayland"].bb.name = "wayland_*.bb"
        self.recipes["plugins_good"].bb.name = "gstreamer1.0-plugins-good_*.bb"
        self.recipes["plugins_bad"].bb.name = "gstreamer1.0-plugins-bad_*.bb"

        self.recipes["wayland"].bb_append.path = self.path_to_wayland_protocols_bbappend
        self.recipes["plugins_good"].bb_append.path = self.path_to_gstreamer_recipes
        self.recipes["plugins_bad"].bb_append.path = self.path_to_gstreamer_recipes

        self.recipes["wayland"].bb.path = self.path_to_wayland_protocols_bb
        self.recipes["plugins_good"].bb.path = self.path_to_gstreamer_recipes_bb
        self.recipes["plugins_bad"].bb.path = self.path_to_gstreamer_recipes_bb

    def __get_content_of_bbappend(self, recipe: Recipe) -> Recipe:

        full_path_to_bbappend = os.path.join(
            recipe.bb_append.path,
            recipe.bb_append.name
        )

        for bbappend in glob.glob(full_path_to_bbappend):
            with open(bbappend) as file:
                recipe.content = file.read()

        return recipe

    def __get_content_of_bb(self, recipe: Recipe) -> Recipe:

        if ("wayland" == recipe.title):
            return recipe

        full_path_to_bb = os.path.join(
            recipe.bb.path,
            recipe.bb.name
        )

        for bb in glob.glob(full_path_to_bb):
            with open(bb) as file:
                recipe.content = file.read()

            # Set BBPATH as {path_to_layers}/poky/meta
            # to be able to inherit cmake or pkgconfig
            recipe.content =                                                                       \
                f"BBPATH = \"{self.path_to_layers}/poky/meta\"\n"                                  \
                +                                                                                  \
                recipe.content

        recipe.content = recipe.content.replace("require", "#")

        return recipe

    def __get_patches_bbappend(self, recipe: Recipe) -> Recipe:

        current_data_smart = bb.data.init()
        bb.parse.siggen = bb.siggen.init(current_data_smart)

        my_temp_file = self._parse_helper(recipe.content)

        bb_parsed = bb.parse.handle(
            my_temp_file.name, current_data_smart)['']

        bb_parsed.setVar("OVERRIDES", "SRC_URI:append:qcom")

        patch = str(bb_parsed.getVar("SRC_URI")).replace('file://', '')

        recipe.patches += patch.strip().split()

        return recipe

    def __get_patches_bb(self, recipe: Recipe) -> Recipe:

        current_data_smart = bb.data.init()
        bb.parse.siggen = bb.siggen.init(current_data_smart)

        my_temp_file = self._parse_helper(recipe.content)

        bb_parsed = bb.parse.handle(
            my_temp_file.name, current_data_smart)['']

        patch = str(bb_parsed.getVar("SRC_URI")).replace('file://', '')

        recipe.patches += patch.strip().split()

        for index, patch in enumerate(recipe.patches):

            if not (".patch") in patch:
                recipe.patches.pop(index)

        return recipe

    def process(self):

        for recipe in self.recipes.values():

            recipe = self.__get_content_of_bb(
                recipe
            )

            recipe = self.__get_patches_bb(
                recipe
            )

            recipe = self.__get_content_of_bbappend(
                recipe
            )

            recipe = self.__get_patches_bbappend(
                recipe
            )

    def export_to_json(self, path_to_tmp: pathlib.Path):

        title_to_patches = dict()

        for recipe in self.recipes.values():
            title_to_patches[recipe.title] = recipe.patches

        path_to_json = os.path.join(path_to_tmp, "recipes_patches.json")

        with open(path_to_json, "w") as recipes_patches:
            json_buffer = json.dumps(title_to_patches, indent=4)
            recipes_patches.write(json_buffer)


class RecipeParser(Parsable):

    # Init of RecipeParser
    # Reads the recipes and buffers them in dictionary (plugin : content)
    def __init__(self, path_to_layers: pathlib.Path, path_to_config_json: pathlib.Path) -> None:
        super().__init__(path_to_layers)

        with open(f"{path_to_config_json}", "r") as json_file:
            json_content = json_file.read()

            info_from_json = json.loads(json_content)

            self.platform = info_from_json["Target_platform"]

        self.plugin_to_content = dict()

        for file in os.listdir(self.path_to_gstreamer_recipes):

            # Skip NON bb files
            if not file.endswith(".bb"):
                continue

            full_path_to_bb_file = os.path.join(
                self.path_to_gstreamer_recipes, file)

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

            my_temp_file = self._parse_helper(content)

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

            S_string = bb_parsed.getVar("S")

            # Remove prefix from S variable to get plugin name
            plugin = S_string[len("${WORKDIR}/"):]
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

# Parse arguments function
# Parses input arguments
def parse_arguments() -> str:
    parser = argparse.ArgumentParser()

    parser.add_argument("-l", "--layers", dest="path_to_layers", required=True,
                        help="Path to layers directory of eSDK")

    parser.add_argument("-j", "--json", dest="path_to_config_json", required=False,
                        help="Path to config json of the current project")

    parser.add_argument("-t", "--tmp", dest="path_to_tmp", required=True,
                        help="Path to tmp directory of the current project")

    parser.add_argument("action",
                        choices=['RecipeParser', 'BBPatchParser'],
                        help="<RecipeParser/BBPatchParser>")

    return parser.parse_args()

# Main
def main():
    args = parse_arguments()

    parser_map = {
        "BBPatchParser": BBPatchParser,
        "RecipeParser": RecipeParser
    }

    parser = parser_map[args.action](
        args.path_to_layers,
        args.path_to_config_json
    )

    parser.process()
    parser.export_to_json(args.path_to_tmp)

    return 0


if __name__ == "__main__":
    main()
