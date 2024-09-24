#!/usr/bin/python3

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import numpy as np
from enum import Enum
from snpe_common import *
from snpe_wrapper import SNPE
import os
import sys

path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../src'))
if not path in sys.path:
    sys.path.insert(1, path)
del path


class bufferType(Enum):
    UNKNOWN = 0
    USERBUFFER_FLOAT = 1
    USERBUFFER_TF8 = 2
    USERBUFFER_TF16 = 3


class ResourceManager(object):

    def __init__(self, init, deinit, *args, **kwargs):

        self.init = init

        self.resource = self.init(*args, **kwargs)

        if self.resource is None:
            raise RuntimeError("self.resource is NULL")

        self.deinit = deinit

    def __enter__(self):
        return self.resource

    def __del__(self):
        self.deinit(self.resource)


class SNPEInterface:

    def __init__(self, snpe_library: SNPE, args) -> None:
        self.settings = args

        self.snpe_library = snpe_library

        self.snpeUserBackedBufferList = list()

        self.outputMapHandle = ResourceManager(
            self.snpe_library.Snpe_UserBufferMap_Create,
            self.snpe_library.Snpe_UserBufferMap_Delete
        )

        self.inputMapHandle = ResourceManager(
            self.snpe_library.Snpe_UserBufferMap_Create,
            self.snpe_library.Snpe_UserBufferMap_Delete
        )

        self.inputRuntimeListHandle = ResourceManager(
            self.snpe_library.Snpe_RuntimeList_Create,
            self.snpe_library.Snpe_RuntimeList_Delete
        )

        if (self.snpe_library.SNPE_RUNTIME[self.settings.runtime] != self.snpe_library.SNPE_RUNTIME["SNPE_RUNTIME_UNSET"]):

            ret = self.snpe_library.Snpe_RuntimeList_Add(
                self.inputRuntimeListHandle.resource,
                self.snpe_library.SNPE_RUNTIME[self.settings.runtime]
            )

            if (ret != 0):
                raise RuntimeError(
                    "Error: Invalid values passed to the argument")
        else:
            raise RuntimeError("Error: Invalid values passed to the argument")

        libVersionHandle = self.snpe_library.Snpe_Util_GetLibraryVersion()
        print(
            f"SNPE v {self.snpe_library.Snpe_DlVersion_ToString(libVersionHandle)}")
        self.snpe_library.Snpe_DlVersion_Delete(libVersionHandle)

        if (self.settings.staticQuantizationStr == "true"):
            self.settings.staticQuantization = True
        elif (self.settings.staticQuantizationStr == "false"):
            self.settings.staticQuantization = False
        else:
            raise RuntimeError("Static quantization value is not valid.")

        if ((self.snpe_library.SNPE_RUNTIME[self.settings.runtime] != self.snpe_library.SNPE_RUNTIME["SNPE_RUNTIME_DSP"]) and self.settings.staticQuantization):
            raise RuntimeError(
                "ERROR: Cannot use static quantization with CPU/GPU runtimes. It is only designed for DSP/AIP runtimes.")

        if (0 == self.snpe_library.Snpe_Util_IsRuntimeAvailable(self.snpe_library.SNPE_RUNTIME[self.settings.runtime])):
            print("Selected runtime not present. Falling back to CPU.")
            self.settings.runtime = self.snpe_library.SNPE_RUNTIME["SNPE_RUNTIME_CPU"]

        # Getting the Container Handle
        self.containerHandle = ResourceManager(
            self.snpe_library.Snpe_DlContainer_Open,
            self.snpe_library.Snpe_DlContainer_Delete,
            self.settings.dlc
        )

        if self.containerHandle.resource is None:
            raise RuntimeError("Error while opening the container file.")

        # Check if given buffer type is valid
        self.bufferType = bufferType.UNKNOWN
        self.bitWidth = 0

        if (self.settings.bufferTypeStr == "USERBUFFER_FLOAT"):
            self.bufferType = bufferType.USERBUFFER_FLOAT
        elif (self.settings.bufferTypeStr == "USERBUFFER_TF8"):
            self.bufferType = bufferType.USERBUFFER_TF8
            self.bitWidth = 8
        elif (self.settings.bufferTypeStr == "USERBUFFER_TF16"):
            self.bufferType = bufferType.USERBUFFER_TF16
            self.bitWidth = 16
        else:
            raise RuntimeError("Buffer type is not valid.")

        # Setting UserSuppliedBuffers to false as buffer mode is ITensor for now
        useUserSuppliedBuffers = ((self.bufferType == bufferType.USERBUFFER_FLOAT) or
                                  (self.bufferType == bufferType.USERBUFFER_TF8) or
                                  (self.bufferType == bufferType.USERBUFFER_TF16))

        self.platformConfigHandle = ResourceManager(
            self.snpe_library.Snpe_PlatformConfig_Create,
            self.snpe_library.Snpe_PlatformConfig_Delete
        )

        snpeBuilderHandle = ResourceManager(
            self.snpe_library.Snpe_SNPEBuilder_Create,
            self.snpe_library.Snpe_SNPEBuilder_Delete,
            self.containerHandle.resource
        )

        if (self.settings.cpuFixedPointMode == "true"):
            self.settings.cpuFixedPointMode = True
        elif (self.settings.cpuFixedPointMode == "false"):
            self.settings.cpuFixedPointMode = False

        if (self.settings.usingInitCache == "true"):
            self.settings.usingInitCache = True
        elif (self.settings.usingInitCache == "false"):
            self.settings.usingInitCache = False

        if (self.snpe_library.Snpe_RuntimeList_Empty(self.inputRuntimeListHandle.resource)):
            self.snpe_library.Snpe_RuntimeList_Add(
                self.inputRuntimeListHandle.resource, self.settings.runtime)

        self.snpe_library.Snpe_SNPEBuilder_SetDebugMode(
            snpeBuilderHandle.resource, False)

        self.snpe_library.Snpe_SNPEBuilder_SetProfilingLevel(
            snpeBuilderHandle.resource,
            self.snpe_library.SNPE_PROFILING_LEVEL[self.settings.profiling_level]
        )

        self.snpe_library.Snpe_SNPEBuilder_SetOutputLayers(
            snpeBuilderHandle.resource, None)
        self.snpe_library.Snpe_SNPEBuilder_SetRuntimeProcessorOrder(
            snpeBuilderHandle.resource, self.inputRuntimeListHandle.resource)
        self.snpe_library.Snpe_SNPEBuilder_SetUseUserSuppliedBuffers(
            snpeBuilderHandle.resource, useUserSuppliedBuffers)
        self.snpe_library.Snpe_SNPEBuilder_SetPlatformConfig(
            snpeBuilderHandle.resource, self.platformConfigHandle.resource)
        self.snpe_library.Snpe_SNPEBuilder_SetInitCacheMode(
            snpeBuilderHandle.resource, self.settings.usingInitCache)
        self.snpe_library.Snpe_SNPEBuilder_SetCpuFixedPointMode(
            snpeBuilderHandle.resource, self.settings.cpuFixedPointMode)

        self.snpeHandle = ResourceManager(
            self.snpe_library.Snpe_SNPEBuilder_Build,
            self.snpe_library.Snpe_SNPE_Delete,
            snpeBuilderHandle.resource
        )

        self.diagLogHandle = ResourceManager(
            self.snpe_library.Snpe_SNPE_GetDiagLogInterface_Ref,
            self.snpe_library.Snpe_IDiagLog_Stop,
            self.snpeHandle.resource
        )
        self.snpe_library.Snpe_IDiagLog_Start(self.diagLogHandle.resource)

        snpeBuilderHandle.__del__()

        if ((self.bufferType == bufferType.USERBUFFER_TF8) or (self.bufferType == bufferType.USERBUFFER_TF16)):
            self.isTfNBuffer = True
        else:
            self.isTfNBuffer = False

        self.applicationInputBuffers = dict()
        self.applicationOutputBuffers = dict()

        if (0 != self.CreateInputBuffer()):
            raise RuntimeError("Error while creating input map.")

        if (0 != self.CreateOutputBuffer()):
            raise RuntimeError("Error while creating output map.")

        print("CreateUserBuffer Succeed !!!")

    def CreateInputBuffer(self):
        # Fill input ML info.
        inputBufferNamesHandle = ResourceManager(
            self.snpe_library.Snpe_SNPE_GetInputTensorNames,
            self.snpe_library.Snpe_StringList_Delete,
            self.snpeHandle.resource
        )

        if (inputBufferNamesHandle.resource is None):
            raise RuntimeError("Error obtaining Input tensor names.")

        inputBufferSize = self.snpe_library.Snpe_StringList_Size(
            inputBufferNamesHandle.resource)

        assert inputBufferSize > 0

        for idx in range(0, inputBufferSize):
            name = self.snpe_library.Snpe_StringList_At(
                inputBufferNamesHandle.resource, idx)

            if (0 != self.CreateUserBuffer(self.inputMapHandle, self.applicationInputBuffers, name)):
                raise RuntimeError("FAILED: CreateUserBuffer.")

        return 0

    def CreateOutputBuffer(self):
        # Fill output ML info.

        outputBufferNamesHandle = ResourceManager(
            self.snpe_library.Snpe_SNPE_GetOutputTensorNames,
            self.snpe_library.Snpe_StringList_Delete,
            self.snpeHandle.resource
        )

        if (outputBufferNamesHandle.resource is None):
            raise RuntimeError("Error obtaining Output tensor names.")

        outputBufferSize = self.snpe_library.Snpe_StringList_Size(
            outputBufferNamesHandle.resource)

        assert outputBufferSize > 0

        for idx in range(0, outputBufferSize):
            name = self.snpe_library.Snpe_StringList_At(
                outputBufferNamesHandle.resource, idx)

            if (0 != self.CreateUserBuffer(self.outputMapHandle, self.applicationOutputBuffers, name)):
                raise RuntimeError("FAILED: CreateUserBuffer.")

        return 0

    def CreateUserBuffer(self, userBufferMap: ResourceManager, applicationBuffers, name):

        bufferAttributesOpt = ResourceManager(
            self.snpe_library.Snpe_SNPE_GetInputOutputBufferAttributes,
            self.snpe_library.Snpe_IBufferAttributes_Delete,
            self.snpeHandle.resource,
            name
        )

        if (bufferAttributesOpt.resource is None):
            raise RuntimeError("Error obtaining attributes for tensor.")

        # calculate the size of buffer required by the input tensor
        bufferShapeHandle = ResourceManager(
            self.snpe_library.Snpe_IBufferAttributes_GetDims,
            self.snpe_library.Snpe_TensorShape_Delete,
            bufferAttributesOpt.resource
        )

        bufferElementSize = 0

        if (self.isTfNBuffer):
            bufferElementSize = int(self.bitWidth / 8)
        else:
            bufferElementSize = 4

        # Calculate the stride based on buffer strides.
        # Note: Strides = Number of bytes to advance to the next element in each dimension.
        # For example, if a float tensor of dimension 2x4x3 is tightly packed in a buffer of 96    bytes, then the strides would be (48,12,4)
        # Note: Buffer stride is usually known and does not need to be calculated.

        rank = self.snpe_library.Snpe_TensorShape_Rank(
            bufferShapeHandle.resource)

        strides = list(range(rank))

        strides[len(strides) - 1] = bufferElementSize
        stride = strides[len(strides) - 1]

        for i in range(rank - 1, 0, -1):
            if (self.snpe_library.Snpe_TensorShape_At(bufferShapeHandle.resource, i) != 0):
                stride = stride * \
                    self.snpe_library.Snpe_TensorShape_At(
                        bufferShapeHandle.resource, i)
            else:
                stride = stride * resizable_dim

            strides[i - 1] = stride

        stridesHandle = ResourceManager(
            self.snpe_library.Snpe_TensorShape_CreateDimsSize,
            self.snpe_library.Snpe_TensorShape_Delete,
            strides
        )

        bufSize = calcSizeFromDims(
            self.snpe_library.Snpe_TensorShape_GetDimensions(
                bufferShapeHandle.resource),
            self.snpe_library.Snpe_TensorShape_Rank(
                bufferShapeHandle.resource),
            bufferElementSize
        )

        userBufferEncodingHandle = None

        if (self.isTfNBuffer):

            if ((self.snpe_library.Snpe_IBufferAttributes_GetEncodingType(bufferAttributesOpt.resource)) ==
                    self.snpe_library.SNPE_USER_BUFFER_ENCODING_ELEMENT_TYPE["SNPE_USERBUFFERENCODING_ELEMENTTYPE_FLOAT"] and self.settings.staticQuantization):

                raise RuntimeError(
                    "ERROR: Quantization parameters not present in model.")

            ubeTfNHandle = self.snpe_library.Snpe_IBufferAttributes_GetEncoding_Ref(
                bufferAttributesOpt.resource)

            snpe_user_buffer_encoding_element_type = self.snpe_library.Snpe_UserBufferEncoding_GetElementType(
                ubeTfNHandle)

            if ((snpe_user_buffer_encoding_element_type != self.snpe_library.SNPE_USER_BUFFER_ENCODING_ELEMENT_TYPE["SNPE_USERBUFFERENCODING_ELEMENTTYPE_TF8"]) and
                    (snpe_user_buffer_encoding_element_type != self.snpe_library.SNPE_USER_BUFFER_ENCODING_ELEMENT_TYPE["SNPE_USERBUFFERENCODING_ELEMENTTYPE_TF16"])):
                raise RuntimeError(f"Quantization encoding not found for tensor: {name}\n\
                                        snpe_user_buffer_encoding_element_type: {snpe_user_buffer_encoding_element_type}")

            stepEquivalentTo0 = self.snpe_library.Snpe_UserBufferEncodingTfN_GetStepExactly0(
                ubeTfNHandle)
            quantizedStepSize = self.snpe_library.Snpe_UserBufferEncodingTfN_GetQuantizedStepSize(
                ubeTfNHandle)
            userBufferEncodingHandle = self.snpe_library.Snpe_UserBufferEncodingTfN_Create(
                stepEquivalentTo0, quantizedStepSize, self.bitWidth)

        else:
            userBufferEncodingHandle = self.snpe_library.Snpe_UserBufferEncodingFloat_Create()

        # create user-backed storage to load input data onto it
        applicationBuffers[name] = np.empty(
            [bufSize], dtype=np.uint8, order='C')

        # create SNPE user buffer from the user-backed buffer
        usrbuffer = self.snpe_library.Snpe_Util_CreateUserBuffer(
            applicationBuffers[name],
            stridesHandle.resource,
            userBufferEncodingHandle
        )

        if usrbuffer is None:
            raise RuntimeError("usrbuffer is None")

        self.snpeUserBackedBufferList.append(usrbuffer)

        self.snpe_library.Snpe_UserBufferMap_Add(
            userBufferMap.resource,
            name,
            self.snpeUserBackedBufferList.pop()
        )

        # Delete all the created handles for creating userBufferEncoding
        if (self.isTfNBuffer):
            self.snpe_library.Snpe_UserBufferEncodingTfN_Delete(
                userBufferEncodingHandle)
        else:
            self.snpe_library.Snpe_UserBufferEncodingFloat_Delete(
                userBufferEncodingHandle)

        return 0

    def Execute(self):
        # Check the batch size for the container
        # SNPE 2.x assumes the first dimension of the tensor shape
        # is the batch size.
        # Getting the Shape of the first input Tensor
        inputShapeHandle = ResourceManager(
            self.snpe_library.Snpe_SNPE_GetInputDimensionsOfFirstTensor,
            self.snpe_library.Snpe_TensorShape_Delete,
            self.snpeHandle.resource
        )

        rc = self.snpe_library.Snpe_TensorShape_Rank(inputShapeHandle.resource)

        if (0 == rc):
            raise RuntimeError("Snpe_TensorShape_Rank output is empty")

        # Getting the first dimension of the input Shape
        inputFirstDimenison = self.snpe_library.Snpe_TensorShape_GetDimensions(
            inputShapeHandle.resource)
        batchSize = inputFirstDimenison[0]

        inputShapeHandle.__del__()

        print(f"Batch size for the container is {batchSize}")

        # Open the input file listing and group input files into batches
        inputs = PreprocessInput(self.settings.inputFile, batchSize)

        # Load contents of input file batches into a SNPE tensor
        # execute the network with the input and save each of the returned output to a file.
        # SNPE allows its input and output buffers that are fed to the network
        # to come from user-backed buffers. First, SNPE buffers are created from
        # user-backed storage. These SNPE buffers are then supplied to the network
        # and the results are stored in user-backed output buffers. This allows for
        # reusing the same buffers for multiple inputs and outputs.

        if (self.isTfNBuffer):
            i = 0

            for input in inputs:

                rc = self.LoadInputUserBufferTfN(input)

                if rc is False:
                    raise RuntimeError("Error while loading the input")

                rc = self.snpe_library.Snpe_SNPE_ExecuteUserBuffers(
                    self.snpeHandle.resource,
                    self.inputMapHandle.resource,
                    self.outputMapHandle.resource
                )

                if (0 != rc):
                    raise RuntimeError("Error while executing the network")

                rc = self.SaveOutputUserBuffer(
                    self.settings.outputDir, i * batchSize, batchSize)

                if rc is False:
                    raise RuntimeError("Error while saving the results")

                i = i + 1
        else:
            i = 0

            for input in inputs:

                rc = self.LoadInputUserBufferFloat(input)

                if rc is False:
                    raise RuntimeError("Error while loading the input")

                rc = self.snpe_library.Snpe_SNPE_ExecuteUserBuffers(
                    self.snpeHandle.resource,
                    self.inputMapHandle.resource,
                    self.outputMapHandle.resource
                )

                if (0 != rc):
                    raise RuntimeError("Error while executing the network")

                rc = self.SaveOutputUserBuffer(
                    self.settings.outputDir, i * batchSize, batchSize)

                if rc is False:
                    raise RuntimeError("Error while saving the results")

                i = i + 1

        self.diagLogHandle.__del__()
        return 0

    def LoadInputUserBufferTfN(self, fileLines):
        # get input tensor names of the network that need to be populated

        inputNamesHandle = ResourceManager(
            self.snpe_library.Snpe_SNPE_GetInputTensorNames,
            self.snpe_library.Snpe_StringList_Delete,
            self.snpeHandle.resource
        )

        if inputNamesHandle.resource is None:
            raise RuntimeError("Error obtaining input tensor names")

        inputNamesSize = self.snpe_library.Snpe_StringList_Size(
            inputNamesHandle.resource)

        assert inputNamesSize > 0

        # Start processing the each Individual Input.
        if (inputNamesSize):
            print("Processing DNN Input: ")

        fileLineIndex = 0

        for fileLine in fileLines:
            # treat each line as a space-separated list of input files
            filePaths = list()
            fileLine = str(fileLine)

            filePaths.append(fileLine.split(' ')[0])

            filePathIndex = 0

            for filePath in filePaths:
                name = self.snpe_library.Snpe_StringList_At(
                    inputNamesHandle.resource, filePathIndex)

                # print out which file is being processed
                print(f"\t {filePathIndex + 1})  {filePath}")

                # load file content onto application storage buffer,
                # on top of which, SNPE has created a user buffer
                if self.settings.staticQuantization is True:
                    # If static quantization is enabled then get the quantization parameters
                    # from the user buffer and use them to load the file contents
                    ubeTfNHandle = self.snpe_library.Snpe_UserBufferMap_GetUserBuffer_Ref(
                        self.inputMapHandle.resource, name)

                    stepEquivalentTo0 = self.snpe_library.Snpe_UserBufferEncodingTfN_GetStepExactly0(
                        ubeTfNHandle)

                    quantizedStepSize = self.snpe_library.Snpe_UserBufferEncodingTfN_GetQuantizedStepSize(
                        ubeTfNHandle)

                    rc, stepEquivalentTo0, quantizedStepSize = self.loadByteDataFileBatchedTfN(
                        filePath,
                        self.applicationInputBuffers[name],
                        fileLineIndex,
                        stepEquivalentTo0,
                        quantizedStepSize
                    )

                    if rc is False:
                        raise RuntimeError(
                            "FAILED: loadByteDataFileBatchedTfN")
                else:
                    # If static quantization is disabled then get the quantization parameters
                    # dynamically from the inputs to load the file contents and set them to user buffer
                    stepEquivalentTo0 = int()
                    quantizedStepSize = float()

                    rc, stepEquivalentTo0, quantizedStepSize = self.loadByteDataFileBatchedTfN(
                        filePath,
                        self.applicationInputBuffers[name],
                        fileLineIndex,
                        stepEquivalentTo0,
                        quantizedStepSize
                    )

                    if rc is False:
                        raise RuntimeError(
                            "FAILED: loadByteDataFileBatchedTfN")

                    usrbuffer = self.snpe_library.Snpe_UserBufferMap_GetUserBuffer_Ref(
                        self.inputMapHandle.resource, name)

                    userBufferEncoding = self.snpe_library.Snpe_IUserBuffer_GetEncoding_Ref(
                        usrbuffer)

                    self.snpe_library.Snpe_UserBufferEncodingTfN_SetStepExactly0(
                        userBufferEncoding, stepEquivalentTo0)
                    self.snpe_library.Snpe_UserBufferEncodingTfN_SetQuantizedStepSize(
                        userBufferEncoding, quantizedStepSize)

                filePathIndex = filePathIndex + 1

            fileLineIndex = fileLineIndex + 1

        return True

    def loadByteDataFileBatchedTfN(self,
                                   inputFile,
                                   loadVector: np.array,
                                   offset,
                                   stepEquivalentTo0,
                                   quantizedStepSize) -> (bool, np.uint64, np.float32):

        length = 0

        with open(inputFile, "rb") as input:

            stats_of_input = os.stat(inputFile)
            length = stats_of_input.st_size

            inVector = np.fromfile(input, dtype=np.float32)

        if (0 == len(loadVector)):
            np.resize(loadVector, length)

        elif (len(loadVector) < int(length / 4)):
            print(
                f"Vector is not large enough to hold data of input file: {inputFile}\n")
            return False

        elementSize = int(self.bitWidth / 8)
        dataStartPos = int((offset * length * elementSize) / 4)

        return FloatToTfN(loadVector,
                          dataStartPos,
                          stepEquivalentTo0,
                          quantizedStepSize,
                          self.settings.staticQuantization,
                          inVector,
                          inVector.size,
                          self.bitWidth
                          )

    # Load multiple batched input user buffers
    def LoadInputUserBufferFloat(self, fileLines) -> bool:
        # get input tensor names of the network that need to be populated

        inputNamesHandle = ResourceManager(
            self.snpe_library.Snpe_SNPE_GetInputTensorNames,
            self.snpe_library.Snpe_StringList_Delete,
            self.snpeHandle.resource
        )

        if inputNamesHandle.resource is None:
            raise RuntimeError("Error obtaining input tensor names")

        inputNamesSize = self.snpe_library.Snpe_StringList_Size(
            inputNamesHandle.resource)

        # Start processing the each Individual Input.
        if (inputNamesSize):
            print("Processing DNN Input: ")

        fileLineIndex = 0

        for fileLine in fileLines:
            # treat each line as a space-separated list of input files
            filePaths = list()
            fileLine = str(fileLine)

            filePaths.append(fileLine.split(' ')[0])

            filePathIndex = 0

            for filePath in filePaths:
                name = self.snpe_library.Snpe_StringList_At(
                    inputNamesHandle.resource, filePathIndex)

                # print out which file is being processed
                print(f"\t {filePathIndex + 1})  {filePath}")

                # load file content onto application storage buffer,
                # on top of which, SNPE has created a user buffer

                rc = loadByteDataFileBatched(
                    filePath, self.applicationInputBuffers[name], fileLineIndex)

                if rc is False:
                    raise RuntimeError("FAILED: loadByteDataFileBatched")

                filePathIndex = filePathIndex + 1

            fileLineIndex = fileLineIndex + 1

        return True

    # Save reult in the raw files for User buffer case
    def SaveOutputUserBuffer(self, outputDir: str, num, batchSize) -> bool:
        # Get all output buffer names from the network

        outputNamesOpt = ResourceManager(
            self.snpe_library.Snpe_UserBufferMap_GetUserBufferNames,
            self.snpe_library.Snpe_StringList_Delete,
            self.outputMapHandle.resource
        )

        elementSize = self.bitWidth / 8

        outputBufferSize = self.snpe_library.Snpe_StringList_Size(
            outputNamesOpt.resource)

        # Iterate through output buffers and print each output to a raw file

        for i in range(0, outputBufferSize):

            for j in range(0, batchSize):
                name = self.snpe_library.Snpe_StringList_At(
                    outputNamesOpt.resource, i)

                path = f"{outputDir}/Result_{num + j}/{name}.raw"

                userbufferHandle = self.snpe_library.Snpe_UserBufferMap_GetUserBuffer_Ref(
                    self.outputMapHandle.resource, name)
                bufferSize = self.snpe_library.Snpe_IUserBuffer_GetSize(
                    userbufferHandle)
                bufferOutputSize = self.snpe_library.Snpe_IUserBuffer_GetOutputSize(
                    userbufferHandle)

                batchChunk = bufferSize / batchSize
                dataChunk = bufferOutputSize / batchSize

                if (batchChunk != dataChunk):
                    print(
                        f"\tUserBuffer size is {bufferSize} bytes, but {bufferOutputSize} bytes of data was found.")

                    batchChunk = min(batchChunk, dataChunk)

                if (self.isTfNBuffer):
                    output = np.empty(
                        [int(self.applicationOutputBuffers[name].size / elementSize)], dtype=np.float32)

                    userBufferEncoding = self.snpe_library.Snpe_IUserBuffer_GetEncoding_Ref(
                        self.snpe_library.Snpe_UserBufferMap_GetUserBuffer_Ref(
                            self.outputMapHandle.resource, name)
                    )

                    TfNToFloat(output,
                               self.applicationOutputBuffers[name],
                               self.snpe_library.Snpe_UserBufferEncodingTfN_GetStepExactly0(
                                   userBufferEncoding),
                               self.snpe_library.Snpe_UserBufferEncodingTfN_GetQuantizedStepSize(
                                   userBufferEncoding),
                               int(
                                   self.applicationOutputBuffers[name].size / elementSize),
                               self.bitWidth
                               )

                    rc = self.SaveUserBufferBatched(
                        path, output, j, int(batchChunk / elementSize))

                    if rc is False:
                        raise RuntimeError("FAILED: SaveUserBufferBatched")

                else:
                    rc = self.SaveUserBufferBatched(
                        path, self.applicationOutputBuffers[name], j, batchChunk)

                    if rc is False:
                        raise RuntimeError("FAILED: SaveUserBufferBatched")

        return True

    def SaveUserBufferBatched(self, path: str, buffer: np.array, batchIndex, batchChunk) -> bool:
        if (batchChunk == 0):
            batchChunk = len(buffer)

        # Create the directory path if it does not exist
        idx = path.rfind('/')

        if idx != -1:

            directory = path[:idx]

            rc = EnsureDirectory(directory)

            if rc is False:
                raise RuntimeError(
                    f"Failed to create output directory: {directory}")

        with open(path, "wb") as output:
            buffer[batchIndex * int(batchChunk): (batchIndex + 1)
                   * int(batchChunk)].tofile(output)

        return True
