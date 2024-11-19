#!/usr/bin/python3

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import os
import sys
import shutil
import argparse

from PIL import Image
import numpy as np
import cv2

path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../src'))
if not path in sys.path:
    sys.path.insert(1, path)
del path

from snpe_wrapper import SNPE
from snpe import SNPEInterface, ResourceManager

LABEL_MAP = [
            (0, 0, 0),  # background
            (128, 0, 0), # aeroplane
            (0, 128, 0), # bicycle
            (128, 128, 0), # bird
            (0, 0, 128), # boat
            (128, 0, 128), # bottle
            (0, 128, 128), # bus
            (128, 128, 128), # car
            (64, 0, 0), # cat
            (192, 0, 0), # chair
            (64, 128, 0), # cow
            (192, 128, 0), # dining table
            (64, 0, 128), # dog
            (192, 0, 128), # horse
            (64, 128, 128), # motorbike
            (192, 128, 128), # person
            (0, 64, 0), # potted plant
            (128, 64, 0), # sheep
            (0, 192, 0), # sofa
            (128, 192, 0), # train
            (0, 64, 128) # tv/monitor
        ]

# Based on model used
MEAN = [0.485, 0.456, 0.406]
STD = [0.229, 0.224, 0.225]

# Reads input image, preprocesses it and then creates raw file
# To act is input to dlc model along with input_list.txt
def prepare_input_image(path, dim=None):
    # If input dimension is not given, then only create input_list.txt file with raw file path
    if (dim is not None):
        image = Image.open(path).convert("RGB")
        image = image.resize(dim)
        image = np.asarray(image).astype(np.float32)

        # Input image when read by Pillow library reads true pixel values (0-255) without scaling
        # Model pre-processing requires pixel values to be scaled from 0 to 1
        image = image / 255.0 # bring pixel values between 0 and 1
        image = (image - MEAN) / STD # normalization
        image = image.astype(np.float32)
        input_image = np.expand_dims(image, axis=0) # create input as 4 tensor

    # Create directory for holding raw files in same parent directory as input image
    input_directory = os.path.join(os.path.dirname(path), "raw")
    if (os.path.exists(input_directory)):
        shutil.rmtree(input_directory)
    os.mkdir(input_directory)

    raw_file_name = os.path.join(input_directory, "input0.raw")

    # Save raw file for model input
    if (dim is not None):
        if (os.path.isfile(raw_file_name)):
            os.remove(raw_file_name)
        input_image.tofile(raw_file_name)

    # save path of .raw input in text file
    input_file_name = os.path.join(os.path.dirname(path), "input_list.txt")
    with open(input_file_name, 'w') as file:
        file.write(raw_file_name)
        file.write("\n")

    return input_file_name

# Creates segmentation map based on output of dlc model
def draw_segmentation_map(outputs):
    labels = np.argmax(outputs.squeeze(), axis=0)
    red_map = np.zeros_like(labels).astype(np.uint8)
    blue_map = np.zeros_like(labels).astype(np.uint8)
    green_map = np.zeros_like(labels).astype(np.uint8)

    # Add red, green and blue pixel values corresponding to label obtained per pixel
    for label_num in range(0, len(LABEL_MAP)):
        indices = (labels == label_num)
        red_map[indices] =  np.array(LABEL_MAP)[label_num, 0]
        green_map[indices] = np.array(LABEL_MAP)[label_num, 1]
        blue_map[indices] = np.array(LABEL_MAP)[label_num, 2]

    # Stack R, G and B pixel layers in that order to obtain final segmentation mask
    segmentation_map = np.stack([red_map, green_map, blue_map], axis=2)
    return segmentation_map

# Blend input image and segmentation mask into single image
def image_overlay(image, segmented_image):
    alpha = 0.5 # transparency for the original image
    beta = 1 - alpha # transparency for the segmentation map
    gamma = 0 # scalar added to each sum
    segmented_image = cv2.cvtColor(segmented_image, cv2.COLOR_RGB2BGR)

    image = np.array(image)
    image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
    result = cv2.addWeighted(image, alpha, segmented_image, beta, gamma)
    return result

# Read output of dlc model from raw file
# Create segmentation map based on the above output
# Blend input image and segmentation mask into final output
# And store the output as a .jpg file
def prepare_output_image(path, input_image_path, dim):
    output_array = np.fromfile(path, dtype=np.float32)
    output_array = output_array.reshape(dim)
    output_array = np.transpose(output_array, (0, 3, 1, 2))

    image = Image.open(input_image_path).convert("RGB")
    image = image.resize((dim[1], dim[2]))

    # Create segmented image and overlay on top input image
    segmented_image = draw_segmentation_map(output_array)
    final_image = image_overlay(image, segmented_image)

    # Create output directory in same parent directory as input image
    cv2.imwrite(os.path.join(os.path.dirname(input_image_path), "output.jpg"), final_image)

def validate_file(f):
    if not os.path.exists(f):
        raise argparse.ArgumentTypeError("{0} does not exist".format(f))
    return f

def parse_arguments():
    parser = argparse.ArgumentParser()
    # Arguments passed are used by SNPEInterface

    # Mandatory arguments
    parser.add_argument("-p", "--snpe_library_path", dest="snpe_library_path",
                        type=validate_file, required=True, help="enter path to SNPE library", metavar="FILE")
    parser.add_argument("-i", "--inputImage", dest="inputImage", type=validate_file, required=True,
                        help="input image", metavar="FILE")
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
    parser.add_argument("-l", "--profiling_level", dest="profiling_level", default="moderate", type=str,
                        required=False, help="Profiling level to be set [off, basic, detailed, moderate]")

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

    if (args.profiling_level == "off"):
        args.profiling_level = "SNPE_PROFILING_LEVEL_OFF"
    elif (args.profiling_level == "basic"):
        args.profiling_level = "SNPE_PROFILING_LEVEL_BASIC"
    elif (args.profiling_level == "detailed"):
        args.profiling_level = "SNPE_PROFILING_LEVEL_DETAILED"
    elif (args.profiling_level == "moderate"):
        args.profiling_level = "SNPE_PROFILING_LEVEL_MODERATE"
    else:
        raise RuntimeError("The provided profiling level option is not valid.")

    args.inputFile = prepare_input_image(args.inputImage, None)

    return args

def main():
    print('Image Segmentation using SNPE')
    print('=================')

    args = parse_arguments()

    if (os.path.exists(os.path.join(args.outputDir, "Result_0"))):
        shutil.rmtree(os.path.join(args.outputDir, "Result_0"))

    snpe_library = SNPE(args.snpe_library_path)

    snpe = SNPEInterface(snpe_library, args)

    # Get input dimensions from dlc model
    inputShapeHandle = ResourceManager(
        snpe.snpe_library.Snpe_SNPE_GetInputDimensionsOfFirstTensor,
        snpe.snpe_library.Snpe_TensorShape_Delete,
        snpe.snpeHandle.resource
    )
    inputFirstDimension = snpe.snpe_library.Snpe_TensorShape_GetDimensions(
        inputShapeHandle.resource)
    prepare_input_image(args.inputImage, (inputFirstDimension[1], inputFirstDimension[2]))
    rc = snpe.Execute()

    if (0 != rc):
        raise RuntimeError("Failed to execute SNPE")

    # Get output buffer names
    outputBufferNamesHandle = ResourceManager(
        snpe.snpe_library.Snpe_SNPE_GetOutputTensorNames,
        snpe.snpe_library.Snpe_StringList_Delete,
        snpe.snpeHandle.resource
    )
    outputBufferName = snpe.snpe_library.Snpe_StringList_At(
        outputBufferNamesHandle.resource, 0)

    # Get output buffer attributes to extract output dimension
    bufferAttributesOpt = ResourceManager(
        snpe.snpe_library.Snpe_SNPE_GetInputOutputBufferAttributes,
        snpe.snpe_library.Snpe_IBufferAttributes_Delete,
        snpe.snpeHandle.resource,
        outputBufferName
    )
    bufferShapeHandle = ResourceManager(
        snpe.snpe_library.Snpe_IBufferAttributes_GetDims,
        snpe.snpe_library.Snpe_TensorShape_Delete,
        bufferAttributesOpt.resource
    )
    outputDimension = snpe.snpe_library.Snpe_TensorShape_GetDimensions(
        bufferShapeHandle.resource)

    prepare_output_image(os.path.join(args.outputDir, "Result_0", f"{outputBufferName}.raw"), args.inputImage, outputDimension)

if __name__ == '__main__':
    main()