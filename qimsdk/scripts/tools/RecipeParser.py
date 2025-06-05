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
    def __init__(self, path_to_layers: pathlib.Path, path_to_meta: pathlib.Path,
                platform: str) -> None:
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
            path_to_meta, "recipes-gst/gstreamer")

        if not os.path.exists(self.path_to_gstreamer_recipes):
            raise Exception("Gstreamer recipes path cannot be reached !!!")

        self.path_to_gstreamer_sample_apps_recipes = os.path.join(
            path_to_meta, "recipes-gst/gstreamer-sample-apps")

        if not os.path.exists(self.path_to_gstreamer_sample_apps_recipes):
            self.path_to_gstreamer_sample_apps_recipes = self.path_to_gstreamer_recipes

        self.platform = platform

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
    def export(self, path_to_tmp: pathlib.Path):
        pass


class BBPatchParser(Parsable):

    plugin_version = str()


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

    def __init__(self, path_to_layers: pathlib.Path, path_to_meta: pathlib.Path,
                platform: str) -> None:

        super().__init__(path_to_layers, path_to_meta, platform)

        self.path_to_layers = path_to_layers

        self.path_to_wayland_protocols_bbappend = os.path.join(
            path_to_layers, "meta-qti-display/recipes-graphics/wayland/")

        if not os.path.exists(self.path_to_wayland_protocols_bbappend):
            self.path_to_wayland_protocols_bbappend = os.path.join(
                path_to_layers, "meta-qcom-hwe/recipes-graphics/wayland/")

        if not os.path.exists(self.path_to_wayland_protocols_bbappend):
            raise Exception("Wayland protocols path cannot be reached !!!")

        self.path_to_pulseaudio_bbappend = os.path.join(
            path_to_layers, "meta-qti-pulseaudio-plugins/recipes-multimedia/audio/")

        if not os.path.exists(self.path_to_pulseaudio_bbappend):
            self.path_to_pulseaudio_bbappend = os.path.join(
                    path_to_layers, "meta-qcom-hwe/recipes-multimedia/audio/")

        if not os.path.exists(self.path_to_pulseaudio_bbappend):
            raise Exception("Pulse audio recipes path cannot be reached !!!")

        self.path_to_pulseaudio_recipe_bb = os.path.join(
            path_to_layers, "poky/meta/recipes-multimedia/pulseaudio/")

        if not os.path.exists(self.path_to_pulseaudio_recipe_bb):
            raise Exception("Pulse audio recipes path cannot be reached !!!")

        self.recipes = {
            "wayland": self.Recipe(),
            "gstreamer": self.Recipe(),
            "plugins_base": self.Recipe(),
            "plugins_good": self.Recipe(),
            "plugins_bad": self.Recipe(),
            "gstd": self.Recipe(),
            "pulseaudio": self.Recipe()
        }

        self.recipes["wayland"].title = "wayland"
        self.recipes["gstreamer"].title = "gstreamer"
        self.recipes["plugins_base"].title = "plugins_base"
        self.recipes["plugins_good"].title = "plugins_good"
        self.recipes["plugins_bad"].title = "plugins_bad"
        self.recipes["gstd"].title = "gstd"
        self.recipes["pulseaudio"].title = "pulseaudio"

        self.recipes["wayland"].bb_append.name = "wayland-protocols_%.bbappend"
        self.recipes["gstreamer"].bb_append.name = "gstreamer1.0_*.bbappend"
        self.recipes["gstd"].bb_append.name = "gstd_*%.bbappend"
        self.recipes["pulseaudio"].bb_append.name = "pulseaudio_*.bbappend"

        self.recipes["pulseaudio"].bb.name = "pulseaudio_*.bb"

        self.recipes["wayland"].bb_append.path = self.path_to_wayland_protocols_bbappend
        self.recipes["gstreamer"].bb_append.path = self.path_to_gstreamer_recipes
        self.recipes["plugins_base"].bb_append.path = self.path_to_gstreamer_recipes
        self.recipes["plugins_good"].bb_append.path = self.path_to_gstreamer_recipes
        self.recipes["plugins_bad"].bb_append.path = self.path_to_gstreamer_recipes
        self.recipes["gstd"].bb_append.path = self.path_to_gstreamer_recipes
        self.recipes["pulseaudio"].bb_append.path = self.path_to_pulseaudio_bbappend

        self.recipes["pulseaudio"].bb.path = self.path_to_pulseaudio_recipe_bb

    def __get_content_of_bbappend(self, recipe: Recipe) -> Recipe:

        full_path_to_bbappend = os.path.join(
            recipe.bb_append.path,
            recipe.bb_append.name
        )

        content = str()
        for bbappend in glob.glob(full_path_to_bbappend):
            with open(bbappend) as file:
                content = file.read()

        recipe.content = recipe.content + content
        recipe.content = recipe.content.replace("require", "#")
        recipe.content = recipe.content.replace("inherit", "#")

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

        return recipe

    def __get_patches(self, recipe: Recipe) -> Recipe:

        current_data_smart = bb.data.init()
        bb.parse.siggen = bb.siggen.init(current_data_smart)

        path_to_esdk = pathlib.Path(self.path_to_layers).parent
        os.chdir(path_to_esdk)

        path_to_local_conf = os.path.join(path_to_esdk, "conf/local.conf")

        current_data_smart = bb.parse.handle(path_to_local_conf,
            current_data_smart, include=True)

        my_temp_file = self._parse_helper(recipe.content)

        current_data_smart.setVar("__bbclasstype", "recipe")

        bb_parsed = bb.parse.handle(
            my_temp_file.name, current_data_smart, include=True)

        bb_parsed.setVar("OVERRIDES", "SRC_URI:append:qcom-custom-bsp")

        patch = bb_parsed.getVar("SRC_URI")

        if patch is None:
            bb_parsed.setVar("OVERRIDES", "SRC_URI:append:qcom")
            patch = bb_parsed.getVar("SRC_URI")

        if patch is None:
            raise Exception(f"SRC_URI couldn't be get from:                                        \
                {recipe.bb_append.path}/{recipe.bb_append.name}")

        recipe.patches += patch.strip().split()
        recipe.patches = [item for item in recipe.patches if ".patch" in item]

        i = 0
        for patch in recipe.patches:
            index = str(patch).rfind('/')
            if index != -1:
                recipe.patches[i] = patch[index + 1:]
            i += 1

        return recipe

    def process(self):
        v = self.plugin_version

        self.recipes["gstreamer"].bb_append.name = f"gstreamer1.0_{v}.bbappend"
        self.recipes["plugins_base"].bb_append.name = f"gstreamer1.0-plugins-base_{v}.bbappend"
        self.recipes["plugins_good"].bb_append.name = f"gstreamer1.0-plugins-good_{v}.bbappend"
        self.recipes["plugins_bad"].bb_append.name = f"gstreamer1.0-plugins-bad_{v}.bbappend"

        for recipe in self.recipes.values():
            path = recipe.bb_append.path

            if "gstreamer1.0" in recipe.bb_append.name:
                parts = recipe.bb_append.name.split("_")
                prefix = parts[0]
                suffix = parts[1].split(".")[-1]

                full_path = os.path.join(path, recipe.bb_append.name)

                if not os.path.exists(full_path):

                    # Replace the middle part
                    v_minor = "1.24%"
                    recipe.bb_append.name = f"{prefix}_{v_minor}.{suffix}"

            recipe = self.__get_content_of_bb(
                recipe
            )

            recipe = self.__get_content_of_bbappend(
                recipe
            )

            recipe = self.__get_patches(
                recipe
            )

    def export(self, path_to_tmp: pathlib.Path):

        title_to_patches = dict()

        for recipe in self.recipes.values():
            title_to_patches[recipe.title] = recipe.patches

        path_to_json = os.path.join(
            path_to_tmp, f"{self.platform}_recipes_patches.json"
        )

        with open(path_to_json, "w") as recipes_patches:
            json_buffer = json.dumps(title_to_patches, indent=4)
            recipes_patches.write(json_buffer)


class RecipeParser(Parsable):

    # Init of RecipeParser
    # Reads the recipes and buffers them in dictionary (plugin : content)
    def __init__(self, path_to_layers: pathlib.Path, path_to_meta: pathlib.Path,
                platform: str) -> None:
        super().__init__(path_to_layers, path_to_meta, platform)

        self.plugin_to_content = dict()
        self.path_to_layers = path_to_layers

        # Combine gstreamer and gstreamer-sample-apps recipes
        self.path_to_recipes = [
            os.path.join(self.path_to_gstreamer_recipes, filename)
                for filename in os.listdir(self.path_to_gstreamer_recipes)
                    if filename.endswith(".bb")
        ] + [
            os.path.join(self.path_to_gstreamer_sample_apps_recipes, filename)
                for filename in os.listdir(self.path_to_gstreamer_sample_apps_recipes)
                    if filename.endswith(".bb")
        ]

    def read_recipe(self, file: str):
        # Read the recipe
        with open(file) as bb_file_content:
            self.plugin_to_content[os.path.basename(file)] = bb_file_content.read()

        # Set BBPATH as {path_to_layers}/poky/meta
        # to be able to inherit cmake or pkgconfig
        self.plugin_to_content[os.path.basename(file)] =                                           \
            f"BBPATH = \"{self.path_to_layers}/poky/meta\"\n"                                      \
            +                                                                                      \
            self.plugin_to_content[os.path.basename(file)]

    @abstractmethod
    def process(self):
        pass

    @abstractmethod
    def export(self, path_to_tmp: pathlib.Path):
        pass


class BuildCodeGenerator(RecipeParser):

    # Init of RecipeParser
    # Reads the recipes and buffers them in dictionary (plugin : content)
    def __init__(self, path_to_layers: pathlib.Path, path_to_meta: pathlib.Path,
                platform: str) -> None:
        super().__init__(path_to_layers, path_to_meta, platform)

        files_to_be_parsed = [
            "recipes-gst/packagegroups/packagegroup-qcom-gst.bb",
            "recipes-qim-product-sdk/packagegroups/packagegroup-qcom-gst.bbappend",
            "recipes-gst/packagegroups/packagegroup-qcom-gst-sample-apps.bb"
        ]

        plugins = str()

        for file_name in files_to_be_parsed:
            content = str()

            file_to_open = str()

            if file_name.endswith(".bb"):
                path = os.path.join(path_to_meta, file_name)
            elif file_name.endswith(".bbappend"):
                path = os.path.join(path_to_layers, "meta-qcom-qim-product-sdk", file_name)
                if not os.path.exists(path):
                    path = os.path.join(path_to_layers, "meta-qti-qim-product-sdk", file_name)

            with open(path) as file:
                content += file.read()

            current_data_smart = bb.data.init()
            bb.parse.siggen = bb.siggen.init(current_data_smart)

            # No need to parse package group class
            content = content.replace("inherit packagegroup", "")
            # Remove qcom-custom-bsp since OVERRIDES can select only by one criteria: target
            content = content.replace(":qcom-custom-bsp", "")
            # Replace hardcoded package name with variable
            content = content.replace("RDEPENDS:packagegroup-qcom-gst", "RDEPENDS:${PN}")

            temp_file = self._parse_helper(content)

            bb_parsed = bb.parse.handle(
                temp_file.name, current_data_smart)['']

            bb.data.expandKeys(bb_parsed)

            if (file_name != "qcom-gstreamer1.0-plugins-oss-qmmfsrc.bb"):
                bb_parsed.setVar("OVERRIDES", "")
            else:
                bb_parsed.setVar("OVERRIDES", self.platform)

            plugins += bb_parsed.getVar("RDEPENDS:${PN}")

        # Plugins that are not enabled yet should be append to the blacklist
        blacklisted = [
        ]

        self.plugins = [
            x for x in plugins.split()
                if "qcom-gstreamer1.0" in x or "qcom-gst-" in x
        ]

        self.plugins = [ x for x in self.plugins if x not in blacklisted ]

        for file in self.path_to_recipes:

            if (os.path.basename(file).replace(".bb","") not in self.plugins):
                continue

            super().read_recipe(file)

        self.plugin_cmake_flags = dict()
        self.plugin_src_uri = dict()

    # Process method of BuildCodeGenerator
    def process(self):

        for recipe,content in self.plugin_to_content.items():

            plugin = recipe.replace('.bb', '')

            if ("inherit cmake" not in content):
                index = self.plugins.index(plugin)
                self.plugins.pop(index)
                continue

            current_data_smart = bb.data.init()
            bb.parse.siggen = bb.siggen.init(current_data_smart)

            my_temp_file = self._parse_helper(content)

            current_data_smart.setVar("__bbclasstype", "recipe")

            bb_parsed = bb.parse.handle(
                my_temp_file.name, current_data_smart)['']

            bb_parsed.setVar("OVERRIDES", self.platform)

            files_path = bb_parsed.getVar("FILESPATH").replace("${WORKSPACE}/", "").replace("/:", "").replace(":", "")
            s = bb_parsed.getVar("S").replace("${WORKDIR}/", "")
            if files_path.strip() == "":
                self.plugin_src_uri[plugin] = s
            else:
                self.plugin_src_uri[plugin] = os.path.join(files_path, s)

            extra_oecmake_string = bb_parsed.getVar("EXTRA_OECMAKE")

            if extra_oecmake_string is None:
                self.plugin_cmake_flags[plugin] = ""
                continue

            extra_oecmake_string = extra_oecmake_string.replace(
                '${PN}', recipe.replace('.bb', ''))

            extra_oecmake_string = extra_oecmake_string.replace(
                '${PACKAGECONFIG_CONFARGS}', '')

            splited_string = list(str())
            splited_string = extra_oecmake_string.split(' -D')

            filtred_extra_oecmake = list(str())

            string = str()

            for string in splited_string:
                # Skip sysroot variables and GST_VERSION_REQUIRED
                if string.find("${STAGING_INCDIR}") != -1 or \
                        string.find("${STAGING_KERNEL_BUILDDIR}") != -1 or \
                        string.find("${STAGING_LIBDIR}") != -1 or \
                        string.find("${PKG_CONFIG_SYSROOT_DIR}") != -1 or \
                        string.find("${bindir}") != -1 or \
                        string.find("${libdir}") != -1 or \
                        string.find("${includedir}") != -1 or \
                        string.find("${PV}") != -1 or \
                        string.find("GST_VERSION_REQUIRED") != -1:
                    continue

                filtred_extra_oecmake.append(string)

            cmake_flags = ' -D'.join(filtred_extra_oecmake)
            cmake_flags += ' '

            self.plugin_cmake_flags[plugin] = cmake_flags

    # Export to shell method of BuildCodeGenerator
    def export(self, path_to_tmp: pathlib.Path):

        path_to_sh = os.path.join(
            path_to_tmp, f"{self.platform}_build_plugins.sh"
        )

        with open(path_to_sh, "w") as build_plugins_sh:
            build_plugins_sh.write("""#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# THIS CODE IS AUTOMATICALLY GENERATED. DO NOT MODIFY IT !!!
""")

            for plugin in self.plugins:
                src_uri = str(self.plugin_src_uri[plugin])
                content="""
# CMake Build ${plugin}
function qimsdk-cmake-build-${plugin} () {
    qimsdk-cmake-build ${QIMSDK_SRC_DIR}/${dir} ${CONFIG_FLAGS} && \\
            print-green "${FUNCNAME} completed successfully!"
}

# Clean CMake ${plugin} build directory
function qimsdk-cmake-clean-${plugin}() {
    rm -rf ${QIMSDK_BUILD_DIR}/${dir}

    print-green "${FUNCNAME} completed successfully!"
}
"""
                content = content.replace("${plugin}", plugin.replace("_", "-"))
                content = content.replace("${dir}", src_uri.replace(" ", ""))
                content = content.replace("${CONFIG_FLAGS}", self.plugin_cmake_flags[plugin])
                build_plugins_sh.write(content)

            build_plugins_sh.write("""
function qimsdk-incremental-build-qti() {
""")

            for plugin in self.plugins:
                if plugin == self.plugins[0]:
                    content = ""
                else:
                    content = "    "
                content += "    qimsdk-cmake-build-" + plugin + " && \\\n"
                build_plugins_sh.write(content)

            build_plugins_sh.write("""        echo "QTI build completed !!!"
}
""")

            build_plugins_sh.write("""
function qimsdk-help-build() {
""")

            for plugin in self.plugins:
                content = "    print-green \"qimsdk-cmake-build-" + plugin + "\"\n"
                content += "        echo \"Build " + plugin + "\"\n"
                content += "    print-red \"qimsdk-cmake-clean-" + plugin + "\"\n"
                content += "        echo \"Clean " + plugin + "\"\n"
                build_plugins_sh.write(content)

            build_plugins_sh.write("""}
""")

            build_plugins_sh.write("""
print-green \"qimsdk-incremental-build-qti\"
echo \"    Incremental build of QTI gst plugins\"
print-yellow \"qimsdk-help-build\"
echo \"    Print build and clean function of each gst plugins\"
""")


class RuntimeFlagsGenerator(RecipeParser):


    class Platform:
        def __init__(self, name: str, list_of_socs: list):
            self.name = name
            self.list_of_socs = list_of_socs

    # Init of RecipeFlagsParser
    # Reads the recipes and buffers them in dictionary (plugin : content)
    def __init__(self, path_to_layers: pathlib.Path, path_to_meta: pathlib.Path,
                platform: str) -> None:
        super().__init__(path_to_layers, path_to_meta, platform)

        target_json = os.path.join(
            os.getcwd(), f"targets/mappings_{self.platform}.json"
        )

        list_of_socs = list(str())

        with open(target_json, "r") as mappings:
            json_content = json.load(mappings)
            list_of_socs = json_content['Soc']

        self.target_platform = self.Platform(self.platform, list_of_socs)

        self.plugin_to_flags = dict()

        for file in self.path_to_recipes:
            super().read_recipe(file)

    # Process method of RecipeFlagsParser
    def process(self):

        for content in self.plugin_to_content.values():

            current_data_smart = bb.data.init()
            bb.parse.siggen = bb.siggen.init(current_data_smart)

            my_temp_file = self._parse_helper(content)

            current_data_smart.setVar("__bbclasstype", "recipe")

            bb_parsed = bb.parse.handle(
                my_temp_file.name, current_data_smart)['']

            bb_parsed.setVar("OVERRIDES", self.target_platform.name)

            extra_oecmake_string = bb_parsed.getVar("EXTRA_OECMAKE")

            if extra_oecmake_string is None:
                continue

            extra_oecmake_string = extra_oecmake_string.replace(
                '${PACKAGECONFIG_CONFARGS}', '')

            splited_string = list(str())
            splited_string = extra_oecmake_string.split(' -D')

            string = str()

            flag_to_value = dict()

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

                pair_flag_to_value = string.split("=")

                if (len(pair_flag_to_value) > 1):

                    flag_to_value.update({
                        pair_flag_to_value[0] : pair_flag_to_value[1]
                    })


            S_string = bb_parsed.getVar("S")

            # Remove prefix from S variable to get plugin name
            plugin = S_string[len("${WORKDIR}/"):]
            plugin = plugin.replace("-", "_")
            if plugin.endswith('/') :
                plugin = plugin[:-1]

            self.plugin_to_flags.update({
                plugin : flag_to_value
            })

    # Export to json method of RecipeFlagsParser
    # Export it to json file ("plugin" : { "member" : "flags" })
    def export(self, path_to_tmp: pathlib.Path):

        for soc in self.target_platform.list_of_socs:

            path_to_json = os.path.join(
                path_to_tmp, f"{soc}_runtime_flags.json"
            )

            with open(path_to_json, "w") as runtime_flags_json:
                json_buffer = json.dumps(self.plugin_to_flags, indent=4)
                runtime_flags_json.write(json_buffer)

# Parse arguments function
# Parses input arguments
def parse_arguments() -> str:
    parser = argparse.ArgumentParser()

    parser.add_argument("-l", "--layers", dest="path_to_layers", required=True,
                        help="Path to layers directory of eSDK")

    parser.add_argument("-m", "--meta", dest="path_to_meta", required=True,
                        help="Path to meta layer of qimsdk")

    parser.add_argument("-p", "--platform", dest="platform", required=False,
                        help="Platform e.g. qcs6490, qcs9100, qcs8300")

    parser.add_argument("-t", "--tmp", dest="path_to_tmp", required=True,
                        help="Path to tmp directory of the current project")

    parser.add_argument("-v", "--version", dest="version", required=False,
                        help="gst-plugins good, bad and base version")

    parser.add_argument("action",
                        choices=['BuildCodeGenerator', 'BBPatchParser', 'RuntimeFlagsGenerator'],
                        help="<BuildCodeGenerator/BBPatchParser/RuntimeFlagsGenerator>")

    return parser.parse_args()

# Main
def main():
    args = parse_arguments()

    parser_map = {
        "BBPatchParser"         : BBPatchParser,
        "BuildCodeGenerator"    : BuildCodeGenerator,
        "RuntimeFlagsGenerator" : RuntimeFlagsGenerator
    }

    parser = parser_map[args.action](
        args.path_to_layers,
        args.path_to_meta,
        args.platform
    )

    parser.plugin_version = str(args.version)

    parser.process()
    parser.export(args.path_to_tmp)

    return 0

if __name__ == "__main__":
    main()
