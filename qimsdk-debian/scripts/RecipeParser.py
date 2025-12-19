# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import tempfile
import os
import sys
import pathlib
import json
import argparse
import glob
import re

from abc import ABC, abstractmethod


class Parsable(ABC):
    def __init__(self, path_to_layers: pathlib.Path, path_to_meta: pathlib.Path) -> None:

        self.path_to_tmp = str()

        self.path_to_gstreamer_recipes = os.path.join(
            path_to_meta, "recipes-gst/gstreamer")

        if not os.path.exists(self.path_to_gstreamer_recipes):
            raise Exception("Gstreamer recipes path cannot be reached !!!")

        self.path_to_gstreamer_sample_apps_recipes = os.path.join(
            path_to_meta, "recipes-gst/gstreamer-sample-apps")

        if not os.path.exists(self.path_to_gstreamer_sample_apps_recipes):
            self.path_to_gstreamer_sample_apps_recipes = self.path_to_gstreamer_recipes

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
    def export(self):
        pass


class RecipeParser(Parsable):

    # Init of RecipeParser
    # Reads the recipes and buffers them in dictionary (plugin : content)
    def __init__(self, path_to_layers: pathlib.Path, path_to_meta: pathlib.Path) -> None:
        super().__init__(path_to_layers, path_to_meta)

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


class BuildCodeGenerator(RecipeParser):
    files_to_be_parsed = list(str())
    mode = str()

    # Init of RecipeParser
    # Reads the recipes and buffers them in dictionary (plugin : content)
    def __init__(self, path_to_layers: pathlib.Path, path_to_meta: pathlib.Path) -> None:
        super().__init__(path_to_layers, path_to_meta)

        # Insert these files at the beginning of list
        self.files_to_be_parsed.insert(
            0, "recipes-qim-product-sdk/packagegroups/packagegroup-qcom-gst.bbappend"
        )
        self.files_to_be_parsed.insert(
            0, "recipes-gst/packagegroups/packagegroup-qcom-gst.bb"
        )
        self.files_to_be_parsed.insert(
            0, "recipes-gst/packagegroups/packagegroup-qcom-gst-basic.bb"
        )

        plugins = str()

        for file_name in self.files_to_be_parsed:
            content = str()

            file_to_open = str()

            if file_name.endswith(".bb"):
                path = os.path.join(path_to_meta, file_name)

            try:
                with open(path) as file:
                    content += file.read()
            except FileNotFoundError:
                print("The file was not found.")
            except IOError:
                print("An I/O error occurred.")

            # No need to parse package group class
            content = content.replace("inherit packagegroup", "")

            # Replace hardcoded package name with variable
            content = content.replace("RDEPENDS:packagegroup-qcom-gst", "RDEPENDS:${PN}")

            # Regex to find the qti plugins list
            pattern = r'RDEPENDS:\$\{PN\}:qcom = "(.*?)"'
            matches = re.findall(pattern, content, re.DOTALL)

            if not matches:
                raise Exception("qti plugins list not found in recipes !!!")

            plugins = []
            for m in matches:
                cleaned = m.replace('\\', '')
                tokens = cleaned.split()
                plugins.extend(tokens)

        self.plugins = [
            x for x in plugins
                if "qcom-gstreamer1.0" in x or "qcom-gst-" in x
        ]

        # Blacklist certain plugins not to be built
        self.blacklisted = []

        self.plugins = [ x for x in self.plugins if x not in self.blacklisted ]

        # Whitelist gst tensorflow-lite plugin
        self.plugins.append("qcom-gstreamer1.0-plugins-oss-mltflite")

        for file in self.path_to_recipes:

            if (os.path.basename(file).replace(".bb","") not in self.plugins):
                continue

        self.plugin_cmake_flags = dict()
        self.plugin_src_uri = dict()

    # Process method of BuildCodeGenerator
    def process(self):

        for plugin in self.plugins:

            recipe = plugin + '.bb'

            with open (os.path.join(self.path_to_gstreamer_recipes, recipe), 'r') as file:
                content = file.read()

            match = re.search(r'\nS = "(.*?)"', content, re.DOTALL)

            # Get s variable from gst recipes meta and extrapolate gst-plugins-qti-oss path from it
            if not match:
                raise Exception("Source path not found in " + recipe + " recipe !!!")
            s = match.group(1).replace("${WORKDIR}/", "")

            self.plugin_src_uri[plugin] = s

            match = re.search(r'\nSUMMARY = "(.*?)"', content, re.DOTALL)

            # Get package summary for current plugin from gst recipes meta
            if not match:
                raise Exception("Package summary not found in " + recipe + " recipe !!!")
            summary = "'" + match.group(1).replace("${WORKDIR}/", "") + "'"

            # Set cmake flags for current plugin
            cmake_flags = " -DGST_PLUGINS_QTI_OSS_SUMMARY=" + summary + \
                          " -DGST_PLUGINS_QTI_OSS_LICENSE=BSD " + \
                          " -DGST_PLUGINS_QTI_OSS_PACKAGE=" + plugin + \
                          " -DGST_PLUGINS_QTI_OSS_ORIGIN='Unknown package origin'"

            self.plugin_cmake_flags[plugin] = cmake_flags

    # Export to shell method of BuildCodeGenerator
    def export(self):

        path_to_sh = os.path.join(
            self.path_to_tmp, f"build_plugins.sh"
        )

        with open(path_to_sh, "w") as build_plugins_sh:
            build_plugins_sh.write("""#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
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

            base_plugins = [
                    "qcom-gstreamer1.0-plugins-oss-base"
                    ]

            # Remove from list with parallelized plugins as they won't be parallelized
            for base_plugin in base_plugins:
                if base_plugin in self.plugins:
                    self.plugins.remove(base_plugin)

            # Number of available cores, or number of parallelized plugins that needs to be built
            # Whichever is less
            needed_threads = os.cpu_count()
            plugins_count = len(self.plugins)
            if plugins_count < needed_threads:
                needed_threads = plugins_count

            for base_plugin in base_plugins:
                content = "    qimsdk-cmake-build-" + base_plugin + " && \\\n"
                build_plugins_sh.write(content)

            # Add plugins in batches of n, where n is the number of available threads
            content = ""
            for i in range(0, plugins_count, needed_threads):
                batch = self.plugins[ i:i + needed_threads ]
                content += "    (\n"
                content += "        trap 'kill 0' SIGINT;\n"
                for task in batch:
                    content += "        qimsdk-cmake-build-" + task + " || kill 0 & \\\n"
                content += "        wait\n"
                content += "    ) && \\\n"
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

# Parse arguments function
# Parses input arguments
def parse_arguments() -> str:
    parser = argparse.ArgumentParser()

    parser.add_argument("-l", "--layers", dest="path_to_layers", required=True,
                        help="Path to layers directory of eSDK")

    parser.add_argument("-m", "--meta", dest="path_to_meta", required=True,
                        help="Path to meta layer of qimsdk")

    parser.add_argument("-t", "--tmp", dest="path_to_tmp", required=True,
                        help="Path to tmp directory of the current project")

    parser.add_argument("-v", "--version", dest="version", required=False,
                        help="gst-plugins good, bad and base version")

    parser.add_argument("action",
                        choices=['BuildCodeGenerator'],
                        help="<BuildCodeGenerator>")

    return parser.parse_args()

# Main
def main():
    args = parse_arguments()

    parser_map = {
        "BuildCodeGenerator" : BuildCodeGenerator
    }

    parser = parser_map[args.action](
        args.path_to_layers,
        args.path_to_meta
    )

    parser.plugin_version = str(args.version)
    parser.path_to_tmp = args.path_to_tmp

    parser.process()
    parser.export()

    return 0

if __name__ == "__main__":
    main()
