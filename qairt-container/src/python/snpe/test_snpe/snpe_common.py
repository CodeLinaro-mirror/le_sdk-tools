#!/usr/bin/python3

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import os
import sys
import numpy as np


def calcSizeFromDims(dims, rank, elementSize):

    if (rank == 0):
        return rank

    size = elementSize

    dims_index = 0

    while (rank):
        size = size * dims[dims_index]

        dims_index = dims_index + 1
        rank = rank - 1

    return size


def PreprocessInput(filePath, batchSize):
    # Read lines from the input lists file
    # and store the paths to inputs in strings

    lines = list()

    with open(filePath, "r") as inputList:

        fileLine = [line.strip() for line in inputList.readlines()]
        lines = fileLine

    batch = list()
    result = list()

    for line in lines:
        if (len(batch) == batchSize):
            result.append(batch.copy())
            batch.clear()

        batch.append(line)

    result.append(batch.copy())

    return result


def FloatToTfN(output: np.array,
               dataStartPos,
               stepEquivalentTo0,
               quantizedStepSize,
               staticQuantization,
               input: np.array,
               numElement,
               bitWidth) -> (bool, np.uint64, np.float32):
    encodingMin = float()
    encodingMax = float()
    encodingRange = float()
    trueBitWidthMax = float((1 << bitWidth) - 1)

    if staticQuantization is False:

        trueMax = np.max(input)
        trueMin = np.min(input)

        stepCloseTo0 = float()

        if (trueMin > 0.0):
            stepCloseTo0 = 0.0
            encodingMin = 0.0
            encodingMax = trueMax
        elif (trueMax < 0.0):
            stepCloseTo0 = trueBitWidthMax
            encodingMin = trueMin
            encodingMax = 0.0
        else:
            trueStepSize = float(float(trueMax - trueMin) / trueBitWidthMax)
            stepCloseTo0 = -trueMin / trueStepSize
            if (stepCloseTo0 == round(stepCloseTo0)):
                # 0.0 is exactly representable
                encodingMin = trueMin
                encodingMax = trueMax
            else:
                stepCloseTo0 = round(stepCloseTo0)
                encodingMin = (0.0 - stepCloseTo0) * trueStepSize
                encodingMax = (trueBitWidthMax - stepCloseTo0) * trueStepSize

        minEncodingRange = 0.01
        encodingRange = encodingMax - encodingMin
        quantizedStepSize = encodingRange / trueBitWidthMax
        stepEquivalentTo0 = round(stepCloseTo0)

        if (encodingRange < minEncodingRange):
            raise RuntimeError(f"Expect the encoding range to be larger than {minEncodingRange}\n\
                    Got: {encodingRange}\n")
    else:
        if (bitWidth == 8):
            encodingMin = (0 - stepEquivalentTo0) * quantizedStepSize
        elif (bitWidth == 16):
            encodingMin = (0 - stepEquivalentTo0) * quantizedStepSize
        else:
            raise RuntimeError("Quantization bitWidth is invalid")

        encodingMax = (trueBitWidthMax - stepEquivalentTo0) * quantizedStepSize
        encodingRange = encodingMax - encodingMin

    if (bitWidth == 8):
        output[dataStartPos:dataStartPos + numElement] = np.clip(
            np.round((int(trueBitWidthMax) * (input[0:numElement].astype(np.float32) - encodingMin) / encodingRange)),
            0, int(trueBitWidthMax)
        ).astype(np.uint8)
    elif (bitWidth == 16):
        output[dataStartPos:dataStartPos + numElement] = np.clip(
            np.round((trueBitWidthMax * (input[0:numElement].astype(np.float32) - encodingMin) / encodingRange)),
            0, trueBitWidthMax
        ).astype(np.uint16)

    return (True, stepEquivalentTo0, quantizedStepSize)


def TfNToFloat(output: np.array,
               input: np.array,
               stepEquivalentTo0,
               quantizedStepSize,
               numElement,
               bitWidth) -> None:

    stepEqTo0 = float(stepEquivalentTo0)

    if (bitWidth == 8):
        np.multiply(input[0:numElement].astype(np.uint8) -
                    stepEqTo0, quantizedStepSize, out=output)
    elif (bitWidth == 16):
        np.multiply(input[0:numElement].astype(np.uint16) -
                    stepEqTo0, quantizedStepSize, out=output)


def loadByteDataFileBatched(inputFile: str, loadVector: np.array, offset) -> bool:

    with open(inputFile, "rb") as input:

        stats_of_input = os.stat(inputFile)
        length = stats_of_input.st_size

        if (0 == len(loadVector)):
            np.resize(loadVector, length)
        elif (len(loadVector) < length):
            print(
                f"Vector is not large enough to hold data of input file: {inputFile}")

        np.resize(loadVector, (offset + 1) * length)

        index = int(offset * stats_of_input.st_size)

        memory_view = memoryview(loadVector)
        input.readinto(memory_view[index:])

    return True


def EnsureDirectory(directory: str) -> bool:

    try:
        os.makedirs(directory)
    except OSError as error:
        return 0
