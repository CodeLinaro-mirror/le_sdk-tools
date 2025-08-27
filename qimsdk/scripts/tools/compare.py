# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import os
import re


class ColorPrinter:
    RED     = "\033[91m"
    YELLOW  = "\033[93m"
    GREEN   = "\033[92m"
    RESET   = "\033[0m"

    @staticmethod
    def print_red(text):
        print(f"{ColorPrinter.RED}{text}{ColorPrinter.RESET}")

    @staticmethod
    def print_yellow(text):
        print(f"{ColorPrinter.YELLOW}{text}{ColorPrinter.RESET}")

    @staticmethod
    def print_green(text):
        print(f"{ColorPrinter.GREEN}{text}{ColorPrinter.RESET}")


class LibraryLister:
    def __init__(self):
        self.dir1 = "/usr/lib"
        self.dir2 = "/usr/lib/aarch64-linux-gnu"

    def list_libs(self, directory):
        lib_files = set()

        for entry in os.listdir(directory):
            full_path = os.path.join(directory, entry)

            if os.path.isfile(full_path):
                if re.match(r"lib.*\.so", entry):
                    lib_files.add(entry)

        return lib_files

    def compare_libs(self):
        libs1 = self.list_libs(self.dir1)
        libs2 = self.list_libs(self.dir2)

        intersection = sorted(libs1.intersection(libs2))

        len_total_matches = len(intersection)

        if len_total_matches > 0:
            ColorPrinter.print_yellow("Matching libraries:")

            for lib in intersection:
                ColorPrinter.print_red(f"\t{lib}")

            ColorPrinter.print_yellow(f"Total matches: {len_total_matches}")

def main():

    # Instantiate and run the comparison
    comparator = LibraryLister()
    comparator.compare_libs()

if __name__ == "__main__":
    main()
