#!/usr/bin/python3

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import argparse
import os
import sys
import numpy as np

path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../src'))
if not path in sys.path:
    sys.path.insert(1, path)
del path

from snpe_wrapper import SNPE


def check_single_test(expected_result, result):
    if expected_result != result:
        return "Failed !!! Expected result = " + str(expected_result) + " !!! Result = " + str(result) + " !!!"

    return "Passed"


def run_tests(snpe: SNPE):

    results = dict()

    # Snpe_DlVersion_Handle_t
    results["Snpe_Util_GetLibraryVersion Pos"] = check_single_test(
        42, snpe.Snpe_Util_GetLibraryVersion())

    results["Snpe_DlVersion_ToString Pos"] = check_single_test(
        "yes", snpe.Snpe_DlVersion_ToString(73))
    results["Snpe_DlVersion_ToString Neg"] = check_single_test(
        None, snpe.Snpe_DlVersion_ToString(93))

    results["Snpe_DlVersion_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_DlVersion_Delete(7)])
    results["Snpe_DlVersion_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_DlVersion_Delete(9)])

    # Snpe Util
    results["Snpe_Util_InitializeLogging Pos"] = check_single_test(
        2, snpe.Snpe_Util_InitializeLogging(SNPE.SNPE_LOG_LEVEL["SNPE_LOG_LEVEL_INFO"]))
    results["Snpe_Util_InitializeLogging Neg"] = check_single_test(
        -9, snpe.Snpe_Util_InitializeLogging(SNPE.SNPE_LOG_LEVEL["SNPE_LOG_LEVEL_FATAL"]))

    results["Snpe_Util_IsRuntimeAvailable Pos"] = check_single_test(
        0, snpe.Snpe_Util_IsRuntimeAvailable(SNPE.SNPE_RUNTIME["SNPE_RUNTIME_DSP"]))
    results["Snpe_Util_IsRuntimeAvailable Neg"] = check_single_test(
        -1, snpe.Snpe_Util_IsRuntimeAvailable(SNPE.SNPE_RUNTIME["SNPE_RUNTIME_AIP_FIXED8_TF"]))

    # Snpe_PlatformConfig_Handle_t
    results["Snpe_PlatformConfig_Create Pos"] = check_single_test(
        6, snpe.Snpe_PlatformConfig_Create())

    results["Snpe_PlatformConfig_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_PlatformConfig_Delete(77)])
    results["Snpe_PlatformConfig_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_PlatformConfig_Delete(934)])

    # Snpe_DlContainer_Handle_t
    results["Snpe_DlContainer_Open Pos"] = check_single_test(
        67, snpe.Snpe_DlContainer_Open("yes"))
    results["Snpe_DlContainer_Open Neg"] = check_single_test(
        43, snpe.Snpe_DlContainer_Open("no"))

    results["Snpe_DlContainer_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_DlContainer_Delete(76)])
    results["Snpe_DlContainer_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_DlContainer_Delete(94)])

    # Snpe_StringList_Handle_t
    results["Snpe_StringList_Create Pos"] = check_single_test(
        40, snpe.Snpe_StringList_Create())

    results["Snpe_StringList_Append Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_StringList_Append(576, "yes")])
    results["Snpe_StringList_Append Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_StringList_Append(56, "no")])

    results["Snpe_StringList_Size Pos"] = check_single_test(
        33, snpe.Snpe_StringList_Size(26))
    results["Snpe_StringList_Size Neg"] = check_single_test(
        76, snpe.Snpe_StringList_Size(5))

    results["Snpe_StringList_At Pos"] = check_single_test(
        "yes", snpe.Snpe_StringList_At(5476, 52))
    results["Snpe_StringList_At Neg"] = check_single_test(
        "no", snpe.Snpe_StringList_At(5, 6))

    results["Snpe_StringList_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_StringList_Delete(36)])
    results["Snpe_StringList_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_StringList_Delete(56)])

    # Snpe_RuntimeList_Handle_t
    results["Snpe_RuntimeList_Create Pos"] = check_single_test(
        80, snpe.Snpe_RuntimeList_Create())

    results["Snpe_RuntimeList_StringToRuntime Pos"] = check_single_test(
        "SNPE_RUNTIME_DSP_FIXED8_TF", SNPE.SNPE_RUNTIME[snpe.Snpe_RuntimeList_StringToRuntime("SNPE_RUNTIME_DSP_FIXED8_TF")])
    results["Snpe_RuntimeList_StringToRuntime Neg"] = check_single_test(
        "SNPE_RUNTIME_UNSET", SNPE.SNPE_RUNTIME[snpe.Snpe_RuntimeList_StringToRuntime("SNPE_RUNTIME_HEXAGON")])

    results["Snpe_RuntimeList_Add Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_RuntimeList_Add(346, SNPE.SNPE_RUNTIME["SNPE_RUNTIME_DSP_FIXED8_TF"])])
    results["Snpe_RuntimeList_Add Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_RuntimeList_Add(5, SNPE.SNPE_RUNTIME["SNPE_RUNTIME_GPU_FLOAT32_16_HYBRID"])])

    results["Snpe_RuntimeList_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_RuntimeList_Delete(36)])
    results["Snpe_RuntimeList_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_RuntimeList_Delete(5)])

    results["Snpe_RuntimeList_Empty Pos"] = check_single_test(
        0, snpe.Snpe_RuntimeList_Empty(41))
    results["Snpe_RuntimeList_Empty Neg"] = check_single_test(
        1, snpe.Snpe_RuntimeList_Empty(7))

    # Snpe_SNPEBuilder_Handle_t
    results["Snpe_SNPEBuilder_Create Pos"] = check_single_test(
        80, snpe.Snpe_SNPEBuilder_Create(7))
    results["Snpe_SNPEBuilder_Create Neg"] = check_single_test(
        60, snpe.Snpe_SNPEBuilder_Create(75))

    results["Snpe_SNPEBuilder_SetOutputLayers Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetOutputLayers(336, 8)])
    results["Snpe_SNPEBuilder_SetOutputLayers Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetOutputLayers(5, 8)])

    results["Snpe_SNPEBuilder_SetRuntimeProcessorOrder Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetRuntimeProcessorOrder(6, 83)])
    results["Snpe_SNPEBuilder_SetRuntimeProcessorOrder Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetRuntimeProcessorOrder(5, 8)])

    results["Snpe_SNPEBuilder_SetUseUserSuppliedBuffers Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetUseUserSuppliedBuffers(66, -3)])
    results["Snpe_SNPEBuilder_SetUseUserSuppliedBuffers Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetUseUserSuppliedBuffers(-5, -8)])

    results["Snpe_SNPEBuilder_SetPlatformConfig Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetPlatformConfig(662, 46)])
    results["Snpe_SNPEBuilder_SetPlatformConfig Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetPlatformConfig(35, -94)])

    results["Snpe_SNPEBuilder_SetInitCacheMode Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetInitCacheMode(2, 5)])
    results["Snpe_SNPEBuilder_SetInitCacheMode Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetInitCacheMode(5, 9)])

    results["Snpe_SNPEBuilder_SetCpuFixedPointMode Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetCpuFixedPointMode(42, False)])
    results["Snpe_SNPEBuilder_SetCpuFixedPointMode Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetCpuFixedPointMode(42, True)])

    results["Snpe_SNPEBuilder_SetPerformanceProfile Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetPerformanceProfile(95, SNPE.SNPE_PERFORMANCE_PROFILE["SNPE_PERFORMANCE_PROFILE_BURST"])])
    results["Snpe_SNPEBuilder_SetPerformanceProfile Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetPerformanceProfile(95, SNPE.SNPE_PERFORMANCE_PROFILE["SNPE_PERFORMANCE_PROFILE_HIGH_POWER_SAVER"])])

    results["Snpe_SNPEBuilder_SetDebugMode Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetDebugMode(8, -7)])
    results["Snpe_SNPEBuilder_SetDebugMode Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_SetDebugMode(8, -5)])

    results["Snpe_SNPEBuilder_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_Delete(668)])
    results["Snpe_SNPEBuilder_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPEBuilder_Delete(-5)])

    # Snpe_SNPE_Handle_t
    results["Snpe_SNPEBuilder_Build Pos"] = check_single_test(
        860, snpe.Snpe_SNPEBuilder_Build(77))
    results["Snpe_SNPEBuilder_Build Neg"] = check_single_test(
        560, snpe.Snpe_SNPEBuilder_Build(75))

    results["Snpe_SNPE_GetInputTensorNames Pos"] = check_single_test(
        8, snpe.Snpe_SNPE_GetInputTensorNames(747))
    results["Snpe_SNPE_GetInputTensorNames Neg"] = check_single_test(
        5, snpe.Snpe_SNPE_GetInputTensorNames(75))

    results["Snpe_SNPE_GetOutputTensorNames Pos"] = check_single_test(
        48, snpe.Snpe_SNPE_GetOutputTensorNames(7447))
    results["Snpe_SNPE_GetOutputTensorNames Neg"] = check_single_test(
        45, snpe.Snpe_SNPE_GetOutputTensorNames(75))

    results["Snpe_SNPE_ExecuteUserBuffers Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPE_ExecuteUserBuffers(-668, 87, -90)])
    results["Snpe_SNPE_ExecuteUserBuffers Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPE_ExecuteUserBuffers(-668, 87, 90)])

    results["Snpe_SNPE_GetInputDimensionsOfFirstTensor Pos"] = check_single_test(
        60, snpe.Snpe_SNPE_GetInputDimensionsOfFirstTensor(22))
    results["Snpe_SNPE_GetInputDimensionsOfFirstTensor Neg"] = check_single_test(
        50, snpe.Snpe_SNPE_GetInputDimensionsOfFirstTensor(752))

    results["Snpe_SNPE_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPE_Delete(-6368)])
    results["Snpe_SNPE_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_SNPE_Delete(6368)])

    # Snpe_TensorShape_Handle_t
    values = [5, 9]
    results["Snpe_TensorShape_CreateDimsSize Pos"] = check_single_test(
        458, snpe.Snpe_TensorShape_CreateDimsSize(values))
    values = [5, 9, 8]
    results["Snpe_TensorShape_CreateDimsSize Neg"] = check_single_test(
        455, snpe.Snpe_TensorShape_CreateDimsSize(values))

    results["Snpe_IBufferAttributes_GetDims Pos"] = check_single_test(
        4358, snpe.Snpe_IBufferAttributes_GetDims(2))
    results["Snpe_IBufferAttributes_GetDims Neg"] = check_single_test(
        4355, snpe.Snpe_IBufferAttributes_GetDims(75))

    results["Snpe_TensorShape_Rank Pos"] = check_single_test(
        3, snpe.Snpe_TensorShape_Rank(88))
    results["Snpe_TensorShape_Rank Neg"] = check_single_test(
        0, snpe.Snpe_TensorShape_Rank(75))

    results["Snpe_TensorShape_GetDimensions Pos"] = check_single_test(
        [78, 83, 94], snpe.Snpe_TensorShape_GetDimensions(88))
    results["Snpe_TensorShape_GetDimensions Neg"] = check_single_test(
        None, snpe.Snpe_TensorShape_GetDimensions(55))

    results["Snpe_TensorShape_At Pos"] = check_single_test(
        83, snpe.Snpe_TensorShape_At(233, 54))
    results["Snpe_TensorShape_At Neg"] = check_single_test(
        43, snpe.Snpe_TensorShape_At(735, 66))

    results["Snpe_TensorShape_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_TensorShape_Delete(8)])
    results["Snpe_TensorShape_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_TensorShape_Delete(68)])

    # Snpe_IUserBuffer_Handle_t
    buffer = np.array([22, 12, 54, 21], np.uint8)

    results["Snpe_Util_CreateUserBuffer Pos"] = check_single_test(
        8, snpe.Snpe_Util_CreateUserBuffer(buffer, 89, 99))
    results["Snpe_Util_CreateUserBuffer Null"] = check_single_test(
        86, snpe.Snpe_Util_CreateUserBuffer(None, 89, 99))
    buffer = np.array([1, 2, 3, 4], np.uint8)
    results["Snpe_Util_CreateUserBuffer Neg"] = check_single_test(
        5, snpe.Snpe_Util_CreateUserBuffer(buffer, 89, 99))

    results["Snpe_UserBufferMap_GetUserBuffer_Ref Pos"] = check_single_test(
        38, snpe.Snpe_UserBufferMap_GetUserBuffer_Ref(389, "yes"))
    results["Snpe_UserBufferMap_GetUserBuffer_Ref Neg"] = check_single_test(
        35, snpe.Snpe_UserBufferMap_GetUserBuffer_Ref(735, "66"))

    buffer = np.array([9, 8, 7, 6], np.uint8)
    results["Snpe_IUserBuffer_SetBufferAddress Pos"] = check_single_test(
        438, snpe.Snpe_IUserBuffer_SetBufferAddress(3839, buffer))
    results["Snpe_IUserBuffer_SetBufferAddress Null"] = check_single_test(
        678, snpe.Snpe_IUserBuffer_SetBufferAddress(39, None))
    buffer = np.array([1, 2, 3, 4], np.uint8)
    results["Snpe_IUserBuffer_SetBufferAddress Neg"] = check_single_test(
        345, snpe.Snpe_IUserBuffer_SetBufferAddress(3839, buffer))

    results["Snpe_IUserBuffer_GetEncoding_Ref Pos"] = check_single_test(
        324, snpe.Snpe_IUserBuffer_GetEncoding_Ref(8))
    results["Snpe_IUserBuffer_GetEncoding_Ref Neg"] = check_single_test(
        333, snpe.Snpe_IUserBuffer_GetEncoding_Ref(44))

    results["Snpe_IUserBuffer_GetSize Pos"] = check_single_test(
        6, snpe.Snpe_IUserBuffer_GetSize(83))
    results["Snpe_IUserBuffer_GetSize Neg"] = check_single_test(
        4, snpe.Snpe_IUserBuffer_GetSize(34))

    results["Snpe_IUserBuffer_GetOutputSize Pos"] = check_single_test(
        66, snpe.Snpe_IUserBuffer_GetOutputSize(383))
    results["Snpe_IUserBuffer_GetOutputSize Neg"] = check_single_test(
        44, snpe.Snpe_IUserBuffer_GetOutputSize(434))

    results["Snpe_IUserBuffer_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_IUserBuffer_Delete(88)])
    results["Snpe_IUserBuffer_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_IUserBuffer_Delete(68)])

    # Snpe_UserBufferMap_Handle_t
    results["Snpe_UserBufferMap_Create Pos"] = check_single_test(
        865, snpe.Snpe_UserBufferMap_Create())

    results["Snpe_UserBufferMap_Add Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferMap_Add(884, "here", 1)])
    results["Snpe_UserBufferMap_Add Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferMap_Add(0, "zero", 0)])

    results["Snpe_UserBufferMap_GetUserBufferNames Pos"] = check_single_test(
        24, snpe.Snpe_UserBufferMap_GetUserBufferNames(858))
    results["Snpe_UserBufferMap_GetUserBufferNames Neg"] = check_single_test(
        33, snpe.Snpe_UserBufferMap_GetUserBufferNames(444))

    results["Snpe_UserBufferMap_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferMap_Delete(8824)])
    results["Snpe_UserBufferMap_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferMap_Delete(0)])

    # Snpe_IBufferAttributes_Handle_t
    results["Snpe_SNPE_GetInputOutputBufferAttributes Pos"] = check_single_test(
        8, snpe.Snpe_SNPE_GetInputOutputBufferAttributes(9, "yesss"))
    results["Snpe_SNPE_GetInputOutputBufferAttributes Neg"] = check_single_test(
        3, snpe.Snpe_SNPE_GetInputOutputBufferAttributes(9, "66sss"))

    results["Snpe_IBufferAttributes_GetEncodingType Pos"] = check_single_test(
        SNPE.SNPE_USER_BUFFER_ENCODING_ELEMENT_TYPE["SNPE_USERBUFFERENCODING_ELEMENTTYPE_INT8"], snpe.Snpe_IBufferAttributes_GetEncodingType(933))
    results["Snpe_IBufferAttributes_GetEncodingType Neg"] = check_single_test(
        SNPE.SNPE_USER_BUFFER_ENCODING_ELEMENT_TYPE["SNPE_USERBUFFERENCODING_ELEMENTTYPE_UNKNOWN"], snpe.Snpe_IBufferAttributes_GetEncodingType(92))

    results["Snpe_IBufferAttributes_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_IBufferAttributes_Delete(14)])
    results["Snpe_IBufferAttributes_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_IBufferAttributes_Delete(10)])

    # Snpe_UserBufferEncoding_Handle_t

    results["Snpe_IBufferAttributes_GetEncoding_Ref Pos"] = check_single_test(
        6628, snpe.Snpe_IBufferAttributes_GetEncoding_Ref(93))
    results["Snpe_IBufferAttributes_GetEncoding_Ref Neg"] = check_single_test(
        623, snpe.Snpe_IBufferAttributes_GetEncoding_Ref(92))

    results["Snpe_UserBufferEncoding_GetElementType Pos"] = check_single_test(
        SNPE.SNPE_USER_BUFFER_ENCODING_ELEMENT_TYPE["SNPE_USERBUFFERENCODING_ELEMENTTYPE_TF16"], snpe.Snpe_UserBufferEncoding_GetElementType(9999))
    results["Snpe_UserBufferEncoding_GetElementType Neg"] = check_single_test(
        SNPE.SNPE_USER_BUFFER_ENCODING_ELEMENT_TYPE["SNPE_USERBUFFERENCODING_ELEMENTTYPE_BOOL8"], snpe.Snpe_UserBufferEncoding_GetElementType(992))

    results["Snpe_UserBufferEncodingFloat_Create Pos"] = check_single_test(
        890, snpe.Snpe_UserBufferEncodingFloat_Create())

    results["Snpe_UserBufferEncodingFloat_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingFloat_Delete(4)])
    results["Snpe_UserBufferEncodingFloat_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingFloat_Delete(0)])

    results["Snpe_UserBufferEncodingFloatN_Create Pos"] = check_single_test(
        33553, snpe.Snpe_UserBufferEncodingFloatN_Create(99))
    results["Snpe_UserBufferEncodingFloatN_Create Neg"] = check_single_test(
        5522, snpe.Snpe_UserBufferEncodingFloatN_Create(92))

    results["Snpe_UserBufferEncodingFloatN_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingFloatN_Delete(54)])
    results["Snpe_UserBufferEncodingFloatN_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingFloatN_Delete(55)])

    results["Snpe_UserBufferEncodingUnsigned8Bit_Create Pos"] = check_single_test(
        778, snpe.Snpe_UserBufferEncodingUnsigned8Bit_Create())

    results["Snpe_UserBufferEncodingUnsigned8Bit_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingUnsigned8Bit_Delete(554)])
    results["Snpe_UserBufferEncodingUnsigned8Bit_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingUnsigned8Bit_Delete(55)])

    results["Snpe_UserBufferEncodingUintN_Create Pos"] = check_single_test(
        33, snpe.Snpe_UserBufferEncodingUintN_Create(95))
    results["Snpe_UserBufferEncodingUintN_Create Neg"] = check_single_test(
        5, snpe.Snpe_UserBufferEncodingUintN_Create(92))

    results["Snpe_UserBufferEncodingUintN_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingUintN_Delete(5)])
    results["Snpe_UserBufferEncodingUintN_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingUintN_Delete(55)])

    results["Snpe_UserBufferEncodingIntN_Create Pos"] = check_single_test(
        3333, snpe.Snpe_UserBufferEncodingIntN_Create(99))
    results["Snpe_UserBufferEncodingIntN_Create Neg"] = check_single_test(
        54, snpe.Snpe_UserBufferEncodingIntN_Create(92))

    results["Snpe_UserBufferEncodingIntN_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingIntN_Delete(5544)])
    results["Snpe_UserBufferEncodingIntN_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingIntN_Delete(55)])

    results["Snpe_UserBufferEncodingTfN_Create Pos"] = check_single_test(
        2, snpe.Snpe_UserBufferEncodingTfN_Create(24, float(5.6), 54))
    results["Snpe_UserBufferEncodingTfN_Create Neg"] = check_single_test(
        6, snpe.Snpe_UserBufferEncodingTfN_Create(24, float(5.5), 54))

    results["Snpe_UserBufferEncodingTfN_GetStepExactly0 Pos"] = check_single_test(
        42, snpe.Snpe_UserBufferEncodingTfN_GetStepExactly0(374))
    results["Snpe_UserBufferEncodingTfN_GetStepExactly0 Neg"] = check_single_test(
        76, snpe.Snpe_UserBufferEncodingTfN_GetStepExactly0(545))

    results["Snpe_UserBufferEncodingTfN_GetQuantizedStepSize Pos"] = check_single_test(
        float(2.0), snpe.Snpe_UserBufferEncodingTfN_GetQuantizedStepSize(354))
    results["Snpe_UserBufferEncodingTfN_GetQuantizedStepSize Neg"] = check_single_test(
        float(-8.0), snpe.Snpe_UserBufferEncodingTfN_GetQuantizedStepSize(545))

    print("Snpe_UserBufferEncodingTfN_SetStepExactly0 should pass !")
    results["Snpe_UserBufferEncodingTfN_SetStepExactly0 Pos"] = check_single_test(
        None, snpe.Snpe_UserBufferEncodingTfN_SetStepExactly0(4, 5))
    print("Snpe_UserBufferEncodingTfN_SetStepExactly0 should fail !")
    results["Snpe_UserBufferEncodingTfN_SetStepExactly0 Neg"] = check_single_test(
        None, snpe.Snpe_UserBufferEncodingTfN_SetStepExactly0(6, 7))

    print("Snpe_UserBufferEncodingTfN_SetQuantizedStepSize should pass !")
    results["Snpe_UserBufferEncodingTfN_SetQuantizedStepSize Pos"] = check_single_test(
        None, snpe.Snpe_UserBufferEncodingTfN_SetQuantizedStepSize(44, float(2.14)))
    print("Snpe_UserBufferEncodingTfN_SetQuantizedStepSize should fail !")
    results["Snpe_UserBufferEncodingTfN_SetQuantizedStepSize Neg"] = check_single_test(
        None, snpe.Snpe_UserBufferEncodingTfN_SetQuantizedStepSize(44, float(2.15)))

    results["Snpe_UserBufferEncodingTfN_Delete Pos"] = check_single_test(
        "SNPE_SUCCESS", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingTfN_Delete(54)])
    results["Snpe_UserBufferEncodingTfN_Delete Neg"] = check_single_test(
        "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT", SNPE.SNPE_ERROR_CODE[snpe.Snpe_UserBufferEncodingTfN_Delete(55)])

    # Print failures
    success = "Successfully "
    for key, value in results.items():
        if "Passed" != value:
            print(key, "->", value)
            success = ""

    print("Test Completed " + success + "!!!")


def validate_file(f):
    if not os.path.exists(f):
        raise argparse.ArgumentTypeError("{0} does not exist".format(f))
    return f


def main():

    print('Test SNPE Wrapper')
    print('=================')

    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--path", dest="path", type=validate_file,
                        required=True, help="enter path to SNPE library", metavar="FILE")
    args = parser.parse_args()

    snpe_library = SNPE(args.path)

    run_tests(snpe_library)


if __name__ == '__main__':
    main()
