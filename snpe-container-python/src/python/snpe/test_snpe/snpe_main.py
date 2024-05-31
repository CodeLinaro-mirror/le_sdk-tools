#!/usr/bin/python3

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import os
import sys
import argparse

path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../src'))
if not path in sys.path:
    sys.path.insert(1, path)
del path

from snpe_wrapper import SNPE
from snpe import SNPEInterface


def validate_file(f):
    if not os.path.exists(f):
        raise argparse.ArgumentTypeError("{0} does not exist".format(f))
    return f


def parse_arguments():
    parser = argparse.ArgumentParser()

    # Mandatory arguments
    parser.add_argument("-p", "--snpe_library_path", dest="snpe_library_path",
                        type=validate_file, required=True, help="enter path to SNPE library", metavar="FILE")
    parser.add_argument("-i", "--input", dest="inputFile", type=validate_file, required=True,
                        help="Path to a file listing the inputs for the network", metavar="FILE")
    parser.add_argument("-d", "--dlc", dest="dlc", type=validate_file, required=True,
                        help="Path to the DL container containing the network", metavar="FILE")

    # Optional arguments
    parser.add_argument("-o", "--output", dest="outputDir", default="./output/",
                        required=False, help="Path to directory to store output results", metavar="FILE")
    parser.add_argument("-b", "--bufferTypeStr", dest="bufferTypeStr", default="USERBUFFER_FLOAT", type=str,
                        required=False, help="Type of buffers to use [USERBUFFER_FLOAT, USERBUFFER_TF8, USERBUFFER_TF16]")
    parser.add_argument("-q", "--staticQuantizationStr", dest="staticQuantizationStr", default="false", type=str, required=False,
                        help="Specifies to use static quantization parameters from the model instead of input specific quantization")
    parser.add_argument("-r", "--runtime", dest="runtime", default="cpu", type=str,
                        required=False, help="The runtime to be used [gpu, dsp, aip, cpu]")
    parser.add_argument("-c", "--usingInitCache", dest="usingInitCache", default="false", type=str, required=False,
                        help="Enable init caching to accelerate the initialization process of SNPE. Defaults to disable")
    parser.add_argument("-x", "--cpuFixedPointMode", dest="cpuFixedPointMode", default="false", type=str,
                        required=False, help="Enable the fixed point execution on CPU runtime for SNPE. Defaults to disable")

    args = parser.parse_args()

    if (args.runtime == "gpu"):
        args.runtime = "SNPE_RUNTIME_GPU"
    elif (args.runtime == "aip"):
        args.runtime = "SNPE_RUNTIME_AIP_FIXED8_TF"
    elif (args.runtime == "dsp"):
        args.runtime = "SNPE_RUNTIME_DSP"
    elif (args.runtime == "cpu"):
        args.runtime = "SNPE_RUNTIME_CPU_FLOAT32"
    else:
        raise RuntimeError("The provided runtime option is not valid.")

    return args


def main():
    print('Test SNPE Wrapper')
    print('=================')

    args = parse_arguments()

    snpe_library = SNPE(args.snpe_library_path)

    snpe = SNPEInterface(snpe_library, args)

    rc = snpe.Execute()

    if (0 != rc):
        raise RuntimeError("Failed to execute SNPE")

    print("App completed successfully")


if __name__ == '__main__':
    main()
