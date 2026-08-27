#!/usr/bin/python3

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import numpy as np

from ctypes import cdll
from ctypes import c_bool
from ctypes import c_char_p
from ctypes import c_void_p
from ctypes import c_size_t
from ctypes import c_int
from ctypes import c_int64
from ctypes import c_uint64
from ctypes import c_uint8
from ctypes import c_float
from ctypes import POINTER

from types import MappingProxyType


class SNPE:
    # Map of error codes
    SNPE_ERROR_CODE = MappingProxyType({
        0: "SNPE_SUCCESS",
        10: "SNPE_ERRORCODE_CAPI_CREATE_FAILURE",
        11: "SNPE_ERRORCODE_CAPI_HANDLEGEN_FAILURE ",
        12: "SNPE_ERRORCODE_CAPI_DELETE_FAILURE",
        13: "SNPE_ERRORCODE_CAPI_BAD_HANDLE",
        14: "SNPE_ERRORCODE_CAPI_BAD_ARGUMENT",
        15: "SNPE_ERRORCODE_CAPI_BAD_ALLOC",
        100: "SNPE_ERRORCODE_CONFIG_MISSING_PARAM",
        101: "SNPE_ERRORCODE_CONFIG_INVALID_PARAM",
        102: "SNPE_ERRORCODE_CONFIG_MISSING_FILE",
        103: "SNPE_ERRORCODE_CONFIG_NNCONFIG_NOT_SET",
        104: "SNPE_ERRORCODE_CONFIG_NNCONFIG_INVALID",
        105: "SNPE_ERRORCODE_CONFIG_WRONG_INPUT_NAME",
        106: "SNPE_ERRORCODE_CONFIG_INCORRECT_INPUT_DIMENSIONS",
        107: "SNPE_ERRORCODE_CONFIG_DIMENSIONS_MODIFICATION_NOT_SUPPORTED",
        108: "SNPE_ERRORCODE_CONFIG_BOTH_OUTPUT_LAYER_TENSOR_NAMES_SET",
        120: "SNPE_ERRORCODE_CONFIG_NNCONFIG_ONLY_TENSOR_SUPPORTED",
        121: "SNPE_ERRORCODE_CONFIG_NNCONFIG_ONLY_USER_BUFFER_SUPPORTED",
        200: "SNPE_ERRORCODE_DLSYSTEM_MISSING_BUFFER",
        201: "SNPE_ERRORCODE_DLSYSTEM_TENSOR_CAST_FAILED",
        202: "SNPE_ERRORCODE_DLSYSTEM_FIXED_POINT_PARAM_INVALID",
        203: "SNPE_ERRORCODE_DLSYSTEM_SIZE_MISMATCH",
        204: "SNPE_ERRORCODE_DLSYSTEM_NAME_NOT_FOUND",
        205: "SNPE_ERRORCODE_DLSYSTEM_VALUE_MISMATCH",
        206: "SNPE_ERRORCODE_DLSYSTEM_INSERT_FAILED",
        207: "SNPE_ERRORCODE_DLSYSTEM_TENSOR_FILE_READ_FAILED",
        208: "SNPE_ERRORCODE_DLSYSTEM_DIAGLOG_FAILURE",
        209: "SNPE_ERRORCODE_DLSYSTEM_LAYER_NOT_SET",
        210: "SNPE_ERRORCODE_DLSYSTEM_WRONG_NUMBER_INPUT_BUFFERS",
        211: "SNPE_ERRORCODE_DLSYSTEM_RUNTIME_TENSOR_SHAPE_MISMATCH",
        212: "SNPE_ERRORCODE_DLSYSTEM_TENSOR_MISSING",
        213: "SNPE_ERRORCODE_DLSYSTEM_TENSOR_ITERATION_UNSUPPORTED",
        214: "SNPE_ERRORCODE_DLSYSTEM_BUFFER_MANAGER_MISSING",
        215: "SNPE_ERRORCODE_DLSYSTEM_RUNTIME_BUFFER_SOURCE_UNSUPPORTED",
        216: "SNPE_ERRORCODE_DLSYSTEM_BUFFER_CAST_FAILED",
        217: "SNPE_ERRORCODE_DLSYSTEM_WRONG_TRANSITION_TYPE",
        218: "SNPE_ERRORCODE_DLSYSTEM_LAYER_ALREADY_REGISTERED",
        219: "SNPE_ERRORCODE_DLSYSTEM_TENSOR_DIM_INVALID",
        240: "SNPE_ERRORCODE_DLSYSTEM_BUFFERENCODING_UNKNOWN",
        241: "SNPE_ERRORCODE_DLSYSTEM_BUFFER_INVALID_PARAM",
        300: "SNPE_ERRORCODE_DLCONTAINER_MODEL_PARSING_FAILED",
        301: "SNPE_ERRORCODE_DLCONTAINER_UNKNOWN_LAYER_CODE",
        302: "SNPE_ERRORCODE_DLCONTAINER_MISSING_LAYER_PARAM",
        303: "SNPE_ERRORCODE_DLCONTAINER_LAYER_PARAM_NOT_SUPPORTED",
        304: "SNPE_ERRORCODE_DLCONTAINER_LAYER_PARAM_INVALID",
        305: "SNPE_ERRORCODE_DLCONTAINER_TENSOR_DATA_MISSING",
        306: "SNPE_ERRORCODE_DLCONTAINER_MODEL_LOAD_FAILED",
        307: "SNPE_ERRORCODE_DLCONTAINER_MISSING_RECORDS",
        308: "SNPE_ERRORCODE_DLCONTAINER_INVALID_RECORD",
        309: "SNPE_ERRORCODE_DLCONTAINER_WRITE_FAILURE",
        310: "SNPE_ERRORCODE_DLCONTAINER_READ_FAILURE",
        311: "SNPE_ERRORCODE_DLCONTAINER_BAD_CONTAINER",
        312: "SNPE_ERRORCODE_DLCONTAINER_BAD_DNN_FORMAT_VERSION",
        313: "SNPE_ERRORCODE_DLCONTAINER_UNKNOWN_AXIS_ANNOTATION",
        314: "SNPE_ERRORCODE_DLCONTAINER_UNKNOWN_SHUFFLE_TYPE",
        315: "SNPE_ERRORCODE_DLCONTAINER_TEMP_FILE_FAILURE",
        400: "SNPE_ERRORCODE_NETWORK_EMPTY_NETWORK",
        401: "SNPE_ERRORCODE_NETWORK_CREATION_FAILED",
        402: "SNPE_ERRORCODE_NETWORK_PARTITION_FAILED",
        403: "SNPE_ERRORCODE_NETWORK_NO_OUTPUT_DEFINED",
        404: "SNPE_ERRORCODE_NETWORK_MISMATCH_BETWEEN_NAMES_AND_DIMS",
        405: "SNPE_ERRORCODE_NETWORK_MISSING_INPUT_NAMES",
        406: "SNPE_ERRORCODE_NETWORK_MISSING_OUTPUT_NAMES",
        407: "SNPE_ERRORCODE_NETWORK_EXECUTION_FAILED",
        500: "SNPE_ERRORCODE_HOST_RUNTIME_TARGET_UNAVAILABLE",
        600: "SNPE_ERRORCODE_CPU_LAYER_NOT_SUPPORTED",
        601: "SNPE_ERRORCODE_CPU_LAYER_PARAM_NOT_SUPPORTED",
        602: "SNPE_ERRORCODE_CPU_LAYER_PARAM_INVALID",
        603: "SNPE_ERRORCODE_CPU_LAYER_PARAM_COMBINATION_INVALID",
        604: "SNPE_ERRORCODE_CPU_BUFFER_NOT_FOUND",
        605: "SNPE_ERRORCODE_CPU_NETWORK_NOT_SUPPORTED",
        606: "SNPE_ERRORCODE_CPU_UDO_OPERATION_FAILED",
        700: "SNPE_ERRORCODE_CPU_FXP_LAYER_NOT_SUPPORTED",
        701: "SNPE_ERRORCODE_CPU_FXP_LAYER_PARAM_NOT_SUPPORTED",
        702: "SNPE_ERRORCODE_CPU_FXP_LAYER_PARAM_INVALID",
        703: "SNPE_ERRORCODE_CPU_FXP_OPTION_INVALID",
        800: "SNPE_ERRORCODE_GPU_LAYER_NOT_SUPPORTED",
        801: "SNPE_ERRORCODE_GPU_LAYER_PARAM_NOT_SUPPORTED",
        802: "SNPE_ERRORCODE_GPU_LAYER_PARAM_INVALID",
        803: "SNPE_ERRORCODE_GPU_LAYER_PARAM_COMBINATION_INVALID",
        804: "SNPE_ERRORCODE_GPU_KERNEL_COMPILATION_FAILED",
        805: "SNPE_ERRORCODE_GPU_CONTEXT_NOT_SET",
        806: "SNPE_ERRORCODE_GPU_KERNEL_NOT_SET",
        807: "SNPE_ERRORCODE_GPU_KERNEL_PARAM_INVALID",
        808: "SNPE_ERRORCODE_GPU_OPENCL_CHECK_FAILED",
        809: "SNPE_ERRORCODE_GPU_OPENCL_FUNCTION_ERROR",
        810: "SNPE_ERRORCODE_GPU_BUFFER_NOT_FOUND",
        811: "SNPE_ERRORCODE_GPU_TENSOR_DIM_INVALID",
        812: "SNPE_ERRORCODE_GPU_MEMORY_FLAGS_INVALID",
        813: "SNPE_ERRORCODE_GPU_UNEXPECTED_NUMBER_OF_IO",
        814: "SNPE_ERRORCODE_GPU_LAYER_PROXY_ERROR",
        815: "SNPE_ERRORCODE_GPU_BUFFER_IN_USE",
        816: "SNPE_ERRORCODE_GPU_BUFFER_MODIFICATION_ERROR",
        817: "SNPE_ERRORCODE_GPU_DATA_ARRANGEMENT_INVALID",
        818: "SNPE_ERRORCODE_GPU_UDO_OPERATION_FAILED",
        900: "SNPE_ERRORCODE_DSP_LAYER_NOT_SUPPORTED",
        901: "SNPE_ERRORCODE_DSP_LAYER_PARAM_NOT_SUPPORTED",
        902: "SNPE_ERRORCODE_DSP_LAYER_PARAM_INVALID",
        903: "SNPE_ERRORCODE_DSP_LAYER_PARAM_COMBINATION_INVALID",
        904: "SNPE_ERRORCODE_DSP_STUB_NOT_PRESENT",
        905: "SNPE_ERRORCODE_DSP_LAYER_NAME_TRUNCATED",
        906: "SNPE_ERRORCODE_DSP_LAYER_INPUT_BUFFER_NAME_TRUNCATED",
        907: "SNPE_ERRORCODE_DSP_LAYER_OUTPUT_BUFFER_NAME_TRUNCATED",
        908: "SNPE_ERRORCODE_DSP_RUNTIME_COMMUNICATION_ERROR",
        909: "SNPE_ERRORCODE_DSP_RUNTIME_INVALID_PARAM_ERROR",
        910: "SNPE_ERRORCODE_DSP_RUNTIME_SYSTEM_ERROR",
        911: "SNPE_ERRORCODE_DSP_RUNTIME_CRASHED_ERROR",
        912: "SNPE_ERRORCODE_DSP_BUFFER_SIZE_ERROR",
        913: "SNPE_ERRORCODE_DSP_UDO_EXECUTE_ERROR",
        914: "SNPE_ERRORCODE_DSP_UDO_LIB_NOT_REGISTERED_ERROR",
        915: "SNPE_ERRORCODE_DSP_UDO_INVALID_QUANTIZATION_TYPE_ERROR",
        1000: "SNPE_ERRORCODE_MODEL_VALIDATION_LAYER_NOT_SUPPORTED",
        1001: "SNPE_ERRORCODE_MODEL_VALIDATION_LAYER_PARAM_NOT_SUPPORTED",
        1002: "SNPE_ERRORCODE_MODEL_VALIDATION_LAYER_PARAM_INVALID",
        1003: "SNPE_ERRORCODE_MODEL_VALIDATION_LAYER_PARAM_MISSING",
        1004: "SNPE_ERRORCODE_MODEL_VALIDATION_LAYER_PARAM_COMBINATION_INVALID",
        1005: "SNPE_ERRORCODE_MODEL_VALIDATION_LAYER_ORDERING_INVALID",
        1006: "SNPE_ERRORCODE_MODEL_VALIDATION_INVALID_CONSTRAINT",
        1007: "SNPE_ERRORCODE_MODEL_VALIDATION_MISSING_BUFFER",
        1008: "SNPE_ERRORCODE_MODEL_VALIDATION_BUFFER_REUSE_NOT_SUPPORTED",
        1009: "SNPE_ERRORCODE_MODEL_VALIDATION_LAYER_COULD_NOT_BE_ASSIGNED",
        1010: "SNPE_ERRORCODE_MODEL_VALIDATION_UDO_LAYER_FAILED",
        1100: "SNPE_ERRORCODE_UDL_LAYER_EMPTY_UDL_NETWORK",
        1101: "SNPE_ERRORCODE_UDL_LAYER_PARAM_INVALID",
        1102: "SNPE_ERRORCODE_UDL_LAYER_INSTANCE_MISSING",
        1103: "SNPE_ERRORCODE_UDL_LAYER_SETUP_FAILED",
        1104: "SNPE_ERRORCODE_UDL_EXECUTE_FAILED",
        1105: "SNPE_ERRORCODE_UDL_BUNDLE_INVALID",
        1106: "SNPE_ERRORCODE_UDO_REGISTRATION_FAILED",
        1107: "SNPE_ERRORCODE_UDO_GET_PACKAGE_FAILED",
        1108: "SNPE_ERRORCODE_UDO_GET_IMPLEMENTATION_FAILED",
        1200: "SNPE_ERRORCODE_STD_LIBRARY_ERROR",
        1210: "SNPE_ERRORCODE_UNKNOWN_EXCEPTION",
        1300: "SNPE_ERRORCODE_STORAGE_INVALID_KERNEL_REPO",
        1400: "SNPE_ERRORCODE_AIP_LAYER_NOT_SUPPORTED",
        1401: "SNPE_ERRORCODE_AIP_LAYER_PARAM_NOT_SUPPORTED",
        1402: "SNPE_ERRORCODE_AIP_LAYER_PARAM_INVALID",
        1403: "SNPE_ERRORCODE_AIP_LAYER_PARAM_COMBINATION_INVALID",
        1404: "SNPE_ERRORCODE_AIP_STUB_NOT_PRESENT",
        1405: "SNPE_ERRORCODE_AIP_LAYER_NAME_TRUNCATED",
        1406: "SNPE_ERRORCODE_AIP_LAYER_INPUT_BUFFER_NAME_TRUNCATED",
        1407: "SNPE_ERRORCODE_AIP_LAYER_OUTPUT_BUFFER_NAME_TRUNCATED",
        1408: "SNPE_ERRORCODE_AIP_RUNTIME_COMMUNICATION_ERROR",
        1409: "SNPE_ERRORCODE_AIP_RUNTIME_INVALID_PARAM_ERROR",
        1410: "SNPE_ERRORCODE_AIP_RUNTIME_SYSTEM_ERROR",
        1411: "SNPE_ERRORCODE_AIP_RUNTIME_TENSOR_MISSING",
        1412: "SNPE_ERRORCODE_AIP_RUNTIME_TENSOR_SHAPE_MISMATCH",
        1413: "SNPE_ERRORCODE_AIP_RUNTIME_BAD_AIX_RECORD",
        1500: "SNPE_ERRORCODE_DLCACHING_INVALID_METADATA",
        1501: "SNPE_ERRORCODE_DLCACHING_INVALID_INITBLOB",
        1600: "SNPE_ERRORCODE_INFRA_CLUSTERMGR_INSTANCE_INVALID",
        1601: "SNPE_ERRORCODE_INFRA_CLUSTERMGR_EXECUTE_SYNC_FAILED",
        1700: "SNPE_ERRORCODE_MEMORY_CORRUPTION_ERROR"
    })

    # Map of supported target runtimes.
    SNPE_RUNTIME = MappingProxyType({
        # Special value indicating the property is unset.
        "SNPE_RUNTIME_UNSET": -1,
        -1: "SNPE_RUNTIME_UNSET",

        # Run the processing on Snapdragon CPU.
        # Data: float 32bit
        # Math: float 32bit
        "SNPE_RUNTIME_CPU_FLOAT32": 0,
        0: "SNPE_RUNTIME_CPU_FLOAT32",
        # Default legacy enum to retain backward compatibility.
        # CPU = CPU_FLOAT32
        "SNPE_RUNTIME_CPU": 0,
        0: "SNPE_RUNTIME_CPU",

        # Run the processing on the Adreno GPU.
        # Data: float 16bit
        # Math: float 32bit
        "SNPE_RUNTIME_GPU_FLOAT32_16_HYBRID": 1,
        1: "SNPE_RUNTIME_GPU_FLOAT32_16_HYBRID",
        # Default legacy enum to retain backward compatibility.
        # GPU = GPU_FLOAT32_16_HYBRID
        "SNPE_RUNTIME_GPU": 1,
        1: "SNPE_RUNTIME_GPU",

        # Run the processing on the Hexagon DSP.
        # Data: 8bit fixed point Tensorflow style format
        # Math: 8bit fixed point Tensorflow style forma
        "SNPE_RUNTIME_DSP_FIXED8_TF": 2,
        2: "SNPE_RUNTIME_DSP_FIXED8_TF",
        # Default legacy enum to retain backward compatibility.
        # DSP = DSP_FIXED8_TF
        "SNPE_RUNTIME_DSP": 2,

        # Run the processing on the Adreno GPU.
        # Data: float 16bit
        # Math: float 16bit
        "SNPE_RUNTIME_GPU_FLOAT16": 3,
        3: "SNPE_RUNTIME_GPU_FLOAT16",

        # Run the processing on Snapdragon AIX+HVX.
        # Data: 8bit fixed point Tensorflow style format
        # Math: 8bit fixed point Tensorflow style format
        "SNPE_RUNTIME_AIP_FIXED8_TF": 5,
        "SNPE_RUNTIME_AIP_FIXED_TF": 5,
        5: "SNPE_RUNTIME_AIP_FIXED8_TF"
    })

    # Map of all supported element types in a IUserBuffer
    SNPE_USER_BUFFER_ENCODING_ELEMENT_TYPE = MappingProxyType({
        # Unknown element type.
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UNKNOWN": 0,
        0: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UNKNOWN",

        # Each element is presented by float.
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_FLOAT": 1,
        1: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_FLOAT",

        # Each element is presented by an unsigned int.
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UNSIGNED8BIT": 2,
        2: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UNSIGNED8BIT",

        # Each element is presented by float16.
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_FLOAT16": 3,
        3: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_FLOAT16",

        # Each element is presented by an 8-bit quantized value.
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_TF8": 10,
        10: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_TF8",

        # Each element is presented by an 16-bit quantized value.
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_TF16": 11,
        11: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_TF16",

        # Each element is presented by Int32
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_INT32": 12,
        12: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_INT32",

        # Each element is presented by UInt32
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UINT32": 13,
        13: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UINT32",

        # Each element is presented by Int8
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_INT8": 14,
        14: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_INT8",

        # Each element is presented by UInt8
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UINT8": 15,
        15: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UINT8",

        # Each element is presented by Int16
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_INT16": 16,
        16: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_INT16",

        # Each element is presented by UInt16
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UINT16": 17,
        17: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_UINT16",

        # Each element is present by Bool8
        "SNPE_USERBUFFERENCODING_ELEMENTTYPE_BOOL8": 18,
        18: "SNPE_USERBUFFERENCODING_ELEMENTTYPE_BOOL8",
    })

    # Enumeration that lists the supported LogLevels that can be set by users
    SNPE_LOG_LEVEL = MappingProxyType({
        # Enumeration variable to be used by user to set logging level to FATAL
        "SNPE_LOG_LEVEL_FATAL": 0,
        0: "SNPE_LOG_LEVEL_FATAL",

        # Enumeration variable to be used by user to set logging level to ERROR
        "SNPE_LOG_LEVEL_ERROR": 1,
        1: "SNPE_LOG_LEVEL_ERROR",

        # Enumeration variable to be used by user to set logging level to WARN
        "SNPE_LOG_LEVEL_WARN": 2,
        2: "SNPE_LOG_LEVEL_WARN",

        # Enumeration variable to be used by user to set logging level to INFO
        "SNPE_LOG_LEVEL_INFO": 3,
        3: "SNPE_LOG_LEVEL_INFO",

        # Enumeration variable to be used by user to set logging level to VERBOSE
        "SNPE_LOG_LEVEL_VERBOSE": 4,
        4: "SNPE_LOG_LEVEL_VERBOSE",
    })

    # Enumeration that lists the supported profiling levels that can be set
    SNPE_PROFILING_LEVEL = MappingProxyType({
        # No profiling. Collects no runtime stats in the DiagLog.
        "SNPE_PROFILING_LEVEL_OFF": 0,
        0: "SNPE_PROFILING_LEVEL_OFF",

        # Basic profiling. Collects some runtime stats in the DiagLog.
        "SNPE_PROFILING_LEVEL_BASIC": 1,
        1: "SNPE_PROFILING_LEVEL_BASIC",

        # Detailed profiling. Collects more runtime stats in the DiagLog,
        # including per-layer statistics. Performance may be impacted.
        "SNPE_PROFILING_LEVEL_DETAILED": 2,
        2: "SNPE_PROFILING_LEVEL_DETAILED",

        # Moderate profiling. Collects more runtime stats in the DiagLog,
        # no per-layer statistics.
        "SNPE_PROFILING_LEVEL_MODERATE": 3,
        3: "SNPE_PROFILING_LEVEL_MODERATE",
    })

    # Enumeration of various performance profiles that can be requested
    SNPE_PERFORMANCE_PROFILE = MappingProxyType({
            # Run in a standard mode.
            # This mode will be deprecated in the future and replaced with BALANCED.
            "SNPE_PERFORMANCE_PROFILE_DEFAULT": 0,
            0: "SNPE_PERFORMANCE_PROFILE_DEFAULT",

            # Run in a balanced mode.
            "SNPE_PERFORMANCE_PROFILE_BALANCED": 0,
            0: "SNPE_PERFORMANCE_PROFILE_BALANCED",

            # Run in high performance mode
            "SNPE_PERFORMANCE_PROFILE_HIGH_PERFORMANCE": 1,
            1: "SNPE_PERFORMANCE_PROFILE_HIGH_PERFORMANCE",

            # Run in a power sensitive mode, at the expense of performance.
            "SNPE_PERFORMANCE_PROFILE_POWER_SAVER": 2,
            2: "SNPE_PERFORMANCE_PROFILE_POWER_SAVER",

            # Use system settings.  SNPE makes no calls to any performance related APIs.
            "SNPE_PERFORMANCE_PROFILE_SYSTEM_SETTINGS": 3,
            3: "SNPE_PERFORMANCE_PROFILE_SYSTEM_SETTINGS",

            # Run in sustained high performance mode
            "SNPE_PERFORMANCE_PROFILE_SUSTAINED_HIGH_PERFORMANCE": 4,
            4: "SNPE_PERFORMANCE_PROFILE_SUSTAINED_HIGH_PERFORMANCE",

            # Run in burst mode
            "SNPE_PERFORMANCE_PROFILE_BURST": 5,
            5: "SNPE_PERFORMANCE_PROFILE_BURST",

            # Run in lower clock than POWER_SAVER, at the expense of performance.
            "SNPE_PERFORMANCE_PROFILE_LOW_POWER_SAVER": 6,
            6: "SNPE_PERFORMANCE_PROFILE_LOW_POWER_SAVER",

            # Run in higher clock and provides better performance than POWER_SAVER.
            "SNPE_PERFORMANCE_PROFILE_HIGH_POWER_SAVER": 7,
            7: "SNPE_PERFORMANCE_PROFILE_HIGH_POWER_SAVER",

            # Run in lower balanced mode
            "SNPE_PERFORMANCE_PROFILE_LOW_BALANCED": 8,
            8: "SNPE_PERFORMANCE_PROFILE_LOW_BALANCED",

            # Run in lowest clock at the expense of performance
            "SNPE_PERFORMANCE_PROFILE_EXTREME_POWER_SAVER": 9,
            9: "SNPE_PERFORMANCE_PROFILE_EXTREME_POWER_SAVER",
    })

    def __init__(self, library_path) -> None:
        self.__path_to_snpe_library = library_path

        self.__Snpe_DlVersion_Handle_t                                                    = c_void_p
        self.__Snpe_PlatformConfig_Handle_t                                               = c_void_p
        self.__Snpe_DlContainer_Handle_t                                                  = c_void_p
        self.__Snpe_RuntimeList_Handle_t                                                  = c_void_p
        self.__Snpe_SNPE_Handle_t                                                         = c_void_p
        self.__Snpe_SNPEBuilder_Handle_t                                                  = c_void_p
        self.__Snpe_UserBufferMap_Handle_t                                                = c_void_p
        self.__Snpe_IUserBuffer_Handle_t                                                  = c_void_p
        self.__Snpe_IBufferAttributes_Handle_t                                            = c_void_p
        self.__Snpe_UserBufferEncoding_Handle_t                                           = c_void_p
        self.__Snpe_TensorShape_Handle_t                                                  = c_void_p
        self.__Snpe_StringList_Handle_t                                                   = c_void_p
        self.__Snpe_IDiagLog_Handle_t                                                     = c_void_p

        self.__Snpe_ErrorCode_t                                                              = c_int
        self.__Snpe_UserBufferEncoding_ElementType_t                                         = c_int
        self.__Snpe_Runtime_t                                                                = c_int

        self.__LoadLibrary()
        self.__ResolveSymbols()
        self.__ResolveResType()

    def __LoadLibrary(self):
        self.__library = cdll.LoadLibrary(
            self.__path_to_snpe_library
        )

    def __ResolveSymbols(self):
        # Snpe_DlVersion_Handle_t
        self.__Snpe_Util_GetLibraryVersion                        = self.__library.Snpe_Util_GetLibraryVersion
        self.__Snpe_DlVersion_ToString                            = self.__library.Snpe_DlVersion_ToString
        self.__Snpe_DlVersion_Delete                              = self.__library.Snpe_DlVersion_Delete

        # Snpe Util
        self.__Snpe_Util_InitializeLogging                        = self.__library.Snpe_Util_InitializeLogging
        self.__Snpe_Util_IsRuntimeAvailable                       = self.__library.Snpe_Util_IsRuntimeAvailable

        # Snpe_PlatformConfig_Handle_t
        self.__Snpe_PlatformConfig_Create                         = self.__library.Snpe_PlatformConfig_Create
        self.__Snpe_PlatformConfig_Delete                         = self.__library.Snpe_PlatformConfig_Delete

        # Snpe_DlContainer_Handle_t
        self.__Snpe_DlContainer_Open                              = self.__library.Snpe_DlContainer_Open
        self.__Snpe_DlContainer_Delete                            = self.__library.Snpe_DlContainer_Delete

        # Snpe_StringList_Handle_t
        self.__Snpe_StringList_Create                             = self.__library.Snpe_StringList_Create
        self.__Snpe_StringList_Append                             = self.__library.Snpe_StringList_Append
        self.__Snpe_StringList_Size                               = self.__library.Snpe_StringList_Size
        self.__Snpe_StringList_At                                 = self.__library.Snpe_StringList_At
        self.__Snpe_StringList_Delete                             = self.__library.Snpe_StringList_Delete

        # Snpe_RuntimeList_Handle_t
        self.__Snpe_RuntimeList_Create                            = self.__library.Snpe_RuntimeList_Create
        self.__Snpe_RuntimeList_StringToRuntime                   = self.__library.Snpe_RuntimeList_StringToRuntime
        self.__Snpe_RuntimeList_Add                               = self.__library.Snpe_RuntimeList_Add
        self.__Snpe_RuntimeList_Delete                            = self.__library.Snpe_RuntimeList_Delete
        self.__Snpe_RuntimeList_Empty                             = self.__library.Snpe_RuntimeList_Empty

        # Snpe_SNPEBuilder_Handle_t
        self.__Snpe_SNPEBuilder_Create                            = self.__library.Snpe_SNPEBuilder_Create
        self.__Snpe_SNPEBuilder_SetOutputLayers                   = self.__library.Snpe_SNPEBuilder_SetOutputLayers
        self.__Snpe_SNPEBuilder_SetRuntimeProcessorOrder          = self.__library.Snpe_SNPEBuilder_SetRuntimeProcessorOrder
        self.__Snpe_SNPEBuilder_SetUseUserSuppliedBuffers         = self.__library.Snpe_SNPEBuilder_SetUseUserSuppliedBuffers
        self.__Snpe_SNPEBuilder_SetPlatformConfig                 = self.__library.Snpe_SNPEBuilder_SetPlatformConfig
        self.__Snpe_SNPEBuilder_SetInitCacheMode                  = self.__library.Snpe_SNPEBuilder_SetInitCacheMode
        self.__Snpe_SNPEBuilder_SetCpuFixedPointMode              = self.__library.Snpe_SNPEBuilder_SetCpuFixedPointMode
        self.__Snpe_SNPEBuilder_SetPerformanceProfile             = self.__library.Snpe_SNPEBuilder_SetPerformanceProfile
        self.__Snpe_SNPEBuilder_SetProfilingLevel                 = self.__library.Snpe_SNPEBuilder_SetProfilingLevel
        self.__Snpe_SNPEBuilder_SetDebugMode                      = self.__library.Snpe_SNPEBuilder_SetDebugMode
        self.__Snpe_SNPEBuilder_Delete                            = self.__library.Snpe_SNPEBuilder_Delete

        # Snpe_SNPE_Handle_t
        self.__Snpe_SNPEBuilder_Build                             = self.__library.Snpe_SNPEBuilder_Build
        self.__Snpe_SNPE_GetInputTensorNames                      = self.__library.Snpe_SNPE_GetInputTensorNames
        self.__Snpe_SNPE_GetOutputTensorNames                     = self.__library.Snpe_SNPE_GetOutputTensorNames
        self.__Snpe_SNPE_ExecuteUserBuffers                       = self.__library.Snpe_SNPE_ExecuteUserBuffers
        self.__Snpe_SNPE_GetInputDimensionsOfFirstTensor          = self.__library.Snpe_SNPE_GetInputDimensionsOfFirstTensor
        self.__Snpe_SNPE_Delete                                   = self.__library.Snpe_SNPE_Delete

        # Snpe_TensorShape_Handle_t
        self.__Snpe_TensorShape_CreateDimsSize                    = self.__library.Snpe_TensorShape_CreateDimsSize
        self.__Snpe_IBufferAttributes_GetDims                     = self.__library.Snpe_IBufferAttributes_GetDims
        self.__Snpe_TensorShape_Rank                              = self.__library.Snpe_TensorShape_Rank
        self.__Snpe_TensorShape_At                                = self.__library.Snpe_TensorShape_At
        self.__Snpe_TensorShape_GetDimensions                     = self.__library.Snpe_TensorShape_GetDimensions
        self.__Snpe_TensorShape_Delete                            = self.__library.Snpe_TensorShape_Delete

        # Snpe_IUserBuffer_Handle_t
        self.__Snpe_Util_CreateUserBuffer                         = self.__library.Snpe_Util_CreateUserBuffer
        self.__Snpe_UserBufferMap_GetUserBuffer_Ref               = self.__library.Snpe_UserBufferMap_GetUserBuffer_Ref
        self.__Snpe_IUserBuffer_SetBufferAddress                  = self.__library.Snpe_IUserBuffer_SetBufferAddress
        self.__Snpe_IUserBuffer_GetEncoding_Ref                   = self.__library.Snpe_IUserBuffer_GetEncoding_Ref
        self.__Snpe_IUserBuffer_GetSize                           = self.__library.Snpe_IUserBuffer_GetSize
        self.__Snpe_IUserBuffer_GetOutputSize                     = self.__library.Snpe_IUserBuffer_GetOutputSize
        self.__Snpe_IUserBuffer_Delete                            = self.__library.Snpe_IUserBuffer_Delete

        # Snpe_UserBufferMap_Handle_t
        self.__Snpe_UserBufferMap_Create                          = self.__library.Snpe_UserBufferMap_Create
        self.__Snpe_UserBufferMap_Add                             = self.__library.Snpe_UserBufferMap_Add
        self.__Snpe_UserBufferMap_GetUserBufferNames              = self.__library.Snpe_UserBufferMap_GetUserBufferNames
        self.__Snpe_UserBufferMap_Delete                          = self.__library.Snpe_UserBufferMap_Delete

        # Snpe_IBufferAttributes_Handle_t
        self.__Snpe_SNPE_GetInputOutputBufferAttributes           = self.__library.Snpe_SNPE_GetInputOutputBufferAttributes
        self.__Snpe_IBufferAttributes_GetEncodingType             = self.__library.Snpe_IBufferAttributes_GetEncodingType
        self.__Snpe_IBufferAttributes_Delete                      = self.__library.Snpe_IBufferAttributes_Delete

        # Snpe_UserBufferEncoding_Handle_t
        self.__Snpe_IBufferAttributes_GetEncoding_Ref             = self.__library.Snpe_IBufferAttributes_GetEncoding_Ref
        self.__Snpe_UserBufferEncoding_GetElementType             = self.__library.Snpe_UserBufferEncoding_GetElementType
        self.__Snpe_UserBufferEncodingFloat_Create                = self.__library.Snpe_UserBufferEncodingFloat_Create
        self.__Snpe_UserBufferEncodingFloat_Delete                = self.__library.Snpe_UserBufferEncodingFloat_Delete
        self.__Snpe_UserBufferEncodingFloatN_Create               = self.__library.Snpe_UserBufferEncodingFloatN_Create
        self.__Snpe_UserBufferEncodingFloatN_Delete               = self.__library.Snpe_UserBufferEncodingFloatN_Delete
        self.__Snpe_UserBufferEncodingUnsigned8Bit_Create         = self.__library.Snpe_UserBufferEncodingUnsigned8Bit_Create
        self.__Snpe_UserBufferEncodingUnsigned8Bit_Delete         = self.__library.Snpe_UserBufferEncodingUnsigned8Bit_Delete
        self.__Snpe_UserBufferEncodingUintN_Create                = self.__library.Snpe_UserBufferEncodingUintN_Create
        self.__Snpe_UserBufferEncodingUintN_Delete                = self.__library.Snpe_UserBufferEncodingUintN_Delete
        self.__Snpe_UserBufferEncodingIntN_Create                 = self.__library.Snpe_UserBufferEncodingIntN_Create
        self.__Snpe_UserBufferEncodingIntN_Delete                 = self.__library.Snpe_UserBufferEncodingIntN_Delete
        self.__Snpe_UserBufferEncodingTfN_Create                  = self.__library.Snpe_UserBufferEncodingTfN_Create
        self.__Snpe_UserBufferEncodingTfN_GetStepExactly0         = self.__library.Snpe_UserBufferEncodingTfN_GetStepExactly0
        self.__Snpe_UserBufferEncodingTfN_GetQuantizedStepSize    = self.__library.Snpe_UserBufferEncodingTfN_GetQuantizedStepSize
        self.__Snpe_UserBufferEncodingTfN_SetStepExactly0         = self.__library.Snpe_UserBufferEncodingTfN_SetStepExactly0
        self.__Snpe_UserBufferEncodingTfN_SetQuantizedStepSize    = self.__library.Snpe_UserBufferEncodingTfN_SetQuantizedStepSize
        self.__Snpe_UserBufferEncodingTfN_Delete                  = self.__library.Snpe_UserBufferEncodingTfN_Delete

        # Snpe_IDiagLog_Handle_t
        self.__Snpe_SNPE_GetDiagLogInterface_Ref                  = self.__library.Snpe_SNPE_GetDiagLogInterface_Ref
        self.__Snpe_IDiagLog_Start                                = self.__library.Snpe_IDiagLog_Start
        self.__Snpe_IDiagLog_Stop                                 = self.__library.Snpe_IDiagLog_Stop

    def __ResolveResType(self):
        # Snpe_DlVersion_Handle_t
        self.__Snpe_Util_GetLibraryVersion.restype                        = c_void_p
        self.__Snpe_DlVersion_ToString.restype                            = c_char_p
        self.__Snpe_DlVersion_Delete.restype                              = self.__Snpe_ErrorCode_t

        # Snpe Util
        self.__Snpe_Util_InitializeLogging.restype                        = c_int
        self.__Snpe_Util_IsRuntimeAvailable.restype                       = c_int

        # Snpe_PlatformConfig_Handle_t
        self.__Snpe_PlatformConfig_Create.restype                         = self.__Snpe_PlatformConfig_Handle_t
        self.__Snpe_PlatformConfig_Delete.restype                         = self.__Snpe_ErrorCode_t

        # Snpe_DlContainer_Handle_t
        self.__Snpe_DlContainer_Open.restype                              = self.__Snpe_DlContainer_Handle_t
        self.__Snpe_DlContainer_Delete.restype                            = self.__Snpe_ErrorCode_t

        # Snpe_StringList_Handle_t
        self.__Snpe_StringList_Create.restype                             = self.__Snpe_StringList_Handle_t
        self.__Snpe_StringList_Append.restype                             = self.__Snpe_ErrorCode_t
        self.__Snpe_StringList_Size.restype                               = c_size_t
        self.__Snpe_StringList_At.restype                                 = c_char_p
        self.__Snpe_StringList_Delete.restype                             = self.__Snpe_ErrorCode_t

        # Snpe_RuntimeList_Handle_t
        self.__Snpe_RuntimeList_Create.restype                            = self.__Snpe_RuntimeList_Handle_t
        self.__Snpe_RuntimeList_StringToRuntime.restype                   = self.__Snpe_Runtime_t
        self.__Snpe_RuntimeList_Add.restype                               = self.__Snpe_ErrorCode_t
        self.__Snpe_RuntimeList_Delete.restype                            = self.__Snpe_ErrorCode_t
        self.__Snpe_RuntimeList_Empty.restype                             = c_int

        # Snpe_SNPEBuilder_Handle_t
        self.__Snpe_SNPEBuilder_Create.restype                            = self.__Snpe_SNPEBuilder_Handle_t
        self.__Snpe_SNPEBuilder_SetOutputLayers.restype                   = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPEBuilder_SetRuntimeProcessorOrder.restype          = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPEBuilder_SetUseUserSuppliedBuffers.restype         = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPEBuilder_SetPlatformConfig.restype                 = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPEBuilder_SetInitCacheMode.restype                  = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPEBuilder_SetCpuFixedPointMode.restype              = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPEBuilder_SetPerformanceProfile.restype             = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPEBuilder_SetProfilingLevel.restype                 = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPEBuilder_SetDebugMode.restype                      = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPEBuilder_Delete.restype                            = self.__Snpe_ErrorCode_t

        # Snpe_SNPE_Handle_t
        self.__Snpe_SNPEBuilder_Build.restype                             = self.__Snpe_SNPE_Handle_t
        self.__Snpe_SNPE_GetInputTensorNames.restype                      = self.__Snpe_StringList_Handle_t
        self.__Snpe_SNPE_GetOutputTensorNames.restype                     = self.__Snpe_StringList_Handle_t
        self.__Snpe_SNPE_ExecuteUserBuffers.restype                       = self.__Snpe_ErrorCode_t
        self.__Snpe_SNPE_GetInputDimensionsOfFirstTensor.restype          = self.__Snpe_TensorShape_Handle_t
        self.__Snpe_SNPE_Delete.restype                                   = self.__Snpe_ErrorCode_t

        # Snpe_TensorShape_Handle_t
        self.__Snpe_TensorShape_CreateDimsSize.restype                    = self.__Snpe_TensorShape_Handle_t
        self.__Snpe_IBufferAttributes_GetDims.restype                     = self.__Snpe_TensorShape_Handle_t
        self.__Snpe_TensorShape_Rank.restype                              = c_size_t
        self.__Snpe_TensorShape_At.restype                                = c_size_t
        self.__Snpe_TensorShape_GetDimensions.restype                     = POINTER(c_size_t)
        self.__Snpe_TensorShape_Delete.restype                            = self.__Snpe_ErrorCode_t

        # Snpe_IUserBuffer_Handle_t
        self.__Snpe_Util_CreateUserBuffer.restype                         = self.__Snpe_IUserBuffer_Handle_t
        self.__Snpe_UserBufferMap_GetUserBuffer_Ref.restype               = self.__Snpe_IUserBuffer_Handle_t
        self.__Snpe_IUserBuffer_SetBufferAddress.restype                  = c_int
        self.__Snpe_IUserBuffer_GetEncoding_Ref.restype                   = self.__Snpe_IUserBuffer_Handle_t
        self.__Snpe_IUserBuffer_GetSize.restype                           = c_size_t
        self.__Snpe_IUserBuffer_GetOutputSize.restype                     = c_size_t
        self.__Snpe_IUserBuffer_Delete.restype                            = self.__Snpe_ErrorCode_t

        # Snpe_UserBufferMap_Handle_t
        self.__Snpe_UserBufferMap_Create.restype                          = self.__Snpe_UserBufferMap_Handle_t
        self.__Snpe_UserBufferMap_Add.restype                             = self.__Snpe_ErrorCode_t
        self.__Snpe_UserBufferMap_GetUserBufferNames.restype              = self.__Snpe_StringList_Handle_t
        self.__Snpe_UserBufferMap_Delete.restype                          = self.__Snpe_ErrorCode_t

        # Snpe_IBufferAttributes_Handle_t
        self.__Snpe_SNPE_GetInputOutputBufferAttributes.restype           = self.__Snpe_IBufferAttributes_Handle_t
        self.__Snpe_IBufferAttributes_GetEncodingType.restype             = self.__Snpe_UserBufferEncoding_ElementType_t
        self.__Snpe_IBufferAttributes_Delete.restype                      = self.__Snpe_ErrorCode_t

        # Snpe_UserBufferEncoding_Handle_t
        self.__Snpe_IBufferAttributes_GetEncoding_Ref.restype             = self.__Snpe_UserBufferEncoding_Handle_t
        self.__Snpe_UserBufferEncoding_GetElementType.restype             = self.__Snpe_UserBufferEncoding_ElementType_t
        self.__Snpe_UserBufferEncodingFloat_Create.restype                = self.__Snpe_UserBufferEncoding_Handle_t
        self.__Snpe_UserBufferEncodingFloat_Delete.restype                = self.__Snpe_ErrorCode_t
        self.__Snpe_UserBufferEncodingFloatN_Create.restype               = self.__Snpe_UserBufferEncoding_Handle_t
        self.__Snpe_UserBufferEncodingFloatN_Delete.restype               = self.__Snpe_ErrorCode_t
        self.__Snpe_UserBufferEncodingUnsigned8Bit_Create.restype         = self.__Snpe_UserBufferEncoding_Handle_t
        self.__Snpe_UserBufferEncodingUnsigned8Bit_Delete.restype         = self.__Snpe_ErrorCode_t
        self.__Snpe_UserBufferEncodingUintN_Create.restype                = self.__Snpe_UserBufferEncoding_Handle_t
        self.__Snpe_UserBufferEncodingUintN_Delete.restype                = self.__Snpe_ErrorCode_t
        self.__Snpe_UserBufferEncodingIntN_Create.restype                 = self.__Snpe_UserBufferEncoding_Handle_t
        self.__Snpe_UserBufferEncodingIntN_Delete.restype                 = self.__Snpe_ErrorCode_t
        self.__Snpe_UserBufferEncodingTfN_Create.restype                  = self.__Snpe_UserBufferEncoding_Handle_t
        self.__Snpe_UserBufferEncodingTfN_GetStepExactly0.restype         = c_uint64
        self.__Snpe_UserBufferEncodingTfN_GetQuantizedStepSize.restype    = c_float
        self.__Snpe_UserBufferEncodingTfN_SetStepExactly0.restype         = None
        self.__Snpe_UserBufferEncodingTfN_SetQuantizedStepSize.restype    = None
        self.__Snpe_UserBufferEncodingTfN_Delete.restype                  = self.__Snpe_ErrorCode_t

        # Snpe_IDiagLog_Handle_t
        self.__Snpe_SNPE_GetDiagLogInterface_Ref.restype                  = self.__Snpe_IDiagLog_Handle_t
        self.__Snpe_IDiagLog_Start.restype                                = self.__Snpe_ErrorCode_t
        self.__Snpe_IDiagLog_Stop.restype                                 = self.__Snpe_ErrorCode_t

    # Snpe_DlVersion_Handle_t
    def Snpe_Util_GetLibraryVersion(self) -> int:

        return int(self.__Snpe_Util_GetLibraryVersion())

    def Snpe_DlVersion_ToString(self, handle: int) -> str:

        rv = c_char_p(self.__Snpe_DlVersion_ToString(c_void_p(handle))).value
        if rv is None:
            return None
        else:
            return str(rv.decode())

    def Snpe_DlVersion_Delete(self, handle: int) -> int:

        return int(self.__Snpe_DlVersion_Delete(c_void_p(handle)))

    # Snpe Util
    def Snpe_Util_InitializeLogging(self, level: int) -> int:

        return int(self.__Snpe_Util_InitializeLogging(c_int(level)))

    def Snpe_Util_IsRuntimeAvailable(self, runtime: int) -> int:

        return int(self.__Snpe_Util_IsRuntimeAvailable(c_int(runtime)))

    # Snpe_PlatformConfig_Handle_t
    def Snpe_PlatformConfig_Create(self) -> int:

        return int(self.__Snpe_PlatformConfig_Create())

    def Snpe_PlatformConfig_Delete(self, handle: int) -> int:

        return int(self.__Snpe_PlatformConfig_Delete(c_void_p(handle)))

    # Snpe_DlContainer_Handle_t

    def Snpe_DlContainer_Open(self, filename: str) -> int:

        return int(self.__Snpe_DlContainer_Open(c_char_p(filename.encode('utf-8'))))

    def Snpe_DlContainer_Delete(self, dlContainerHandle: int) -> int:

        return int(self.__Snpe_DlContainer_Delete(c_void_p(dlContainerHandle)))

    # Snpe_StringList_Handle_t

    def Snpe_StringList_Create(self) -> int:

        return int(self.__Snpe_StringList_Create())

    def Snpe_StringList_Append(self, stringListHandle: int, string: str) -> int:

        return int(self.__Snpe_StringList_Append(c_void_p(stringListHandle), c_char_p(string.encode('utf-8'))))

    def Snpe_StringList_Size(self, stringListHandle: int) -> int:

        return int(self.__Snpe_StringList_Size(c_void_p(stringListHandle)))

    def Snpe_StringList_At(self, stringListHandle: int, idx: int) -> str:

        rv = c_char_p(self.__Snpe_StringList_At(
            c_void_p(stringListHandle), c_size_t(idx))).value
        if rv is None:
            return None
        else:
            return str(rv.decode())

    def Snpe_StringList_Delete(self, stringListHandle: int) -> int:

        return int(self.__Snpe_StringList_Delete(c_void_p(stringListHandle)))

    # Snpe_RuntimeList_Handle_t
    def Snpe_RuntimeList_Create(self) -> int:

        return int(self.__Snpe_RuntimeList_Create())

    def Snpe_RuntimeList_StringToRuntime(self, string: str) -> int:

        return int(self.__Snpe_RuntimeList_StringToRuntime(c_char_p(string.encode('utf-8'))))

    def Snpe_RuntimeList_Add(self, runtimeListHandle: int, runtime: int) -> int:

        return int(self.__Snpe_RuntimeList_Add(c_void_p(runtimeListHandle), c_int(runtime)))

    def Snpe_RuntimeList_Delete(self, runtimeListHandle: int) -> int:

        return int(self.__Snpe_RuntimeList_Delete(c_void_p(runtimeListHandle)))

    def Snpe_RuntimeList_Empty(self, runtimeListHandle: int) -> int:

        return int(self.__Snpe_RuntimeList_Empty(c_void_p(runtimeListHandle)))

    # Snpe_SNPEBuilder_Handle_t

    def Snpe_SNPEBuilder_Create(self, containerHandle: int) -> int:

        return int(self.__Snpe_SNPEBuilder_Create(c_void_p(containerHandle)))

    def Snpe_SNPEBuilder_SetOutputLayers(self, snpeBuilderHandle: int, outputLayerNames: int) -> int:

        return int(self.__Snpe_SNPEBuilder_SetOutputLayers(c_void_p(snpeBuilderHandle), c_void_p(outputLayerNames)))

    def Snpe_SNPEBuilder_SetRuntimeProcessorOrder(self, snpeBuilderHandle: int, runtimeListHandle: int) -> int:

        return int(self.__Snpe_SNPEBuilder_SetRuntimeProcessorOrder(c_void_p(snpeBuilderHandle), c_void_p(runtimeListHandle)))

    def Snpe_SNPEBuilder_SetUseUserSuppliedBuffers(self, snpeBuilderHandle: int, bufferMode: int) -> int:

        return int(self.__Snpe_SNPEBuilder_SetUseUserSuppliedBuffers(c_void_p(snpeBuilderHandle), c_int(bufferMode)))

    def Snpe_SNPEBuilder_SetPlatformConfig(self, snpeBuilderHandle: int, platformConfigHandle: int) -> int:

        return int(self.__Snpe_SNPEBuilder_SetPlatformConfig(c_void_p(snpeBuilderHandle), c_void_p(platformConfigHandle)))

    def Snpe_SNPEBuilder_SetInitCacheMode(self, snpeBuilderHandle: int, cacheMode: int) -> int:

        return int(self.__Snpe_SNPEBuilder_SetInitCacheMode(c_void_p(snpeBuilderHandle), c_int(cacheMode)))

    def Snpe_SNPEBuilder_SetCpuFixedPointMode(self, snpeBuilderHandle: int, cpuFxpMode: bool) -> int:

        return int(self.__Snpe_SNPEBuilder_SetCpuFixedPointMode(c_void_p(snpeBuilderHandle), c_bool(cpuFxpMode)))

    def Snpe_SNPEBuilder_SetPerformanceProfile(self, snpeBuilderHandle: int, performanceProfile: int) -> int:

        return int(self.__Snpe_SNPEBuilder_SetPerformanceProfile(c_void_p(snpeBuilderHandle), c_int(performanceProfile)))

    def Snpe_SNPEBuilder_SetProfilingLevel(self, snpeBuilderHandle: int, level: int) -> int:

        return int(self.__Snpe_SNPEBuilder_SetProfilingLevel(c_void_p(snpeBuilderHandle), c_int(level)))

    def Snpe_SNPEBuilder_SetDebugMode(self, snpeBuilderHandle: int, debugMode: int) -> int:

        return int(self.__Snpe_SNPEBuilder_SetDebugMode(c_void_p(snpeBuilderHandle), c_int(debugMode)))

    def Snpe_SNPEBuilder_Delete(self, snpeBuilderHandle: int) -> int:

        return int(self.__Snpe_SNPEBuilder_Delete(c_void_p(snpeBuilderHandle)))

    # Snpe_SNPE_Handle_t

    def Snpe_SNPEBuilder_Build(self, snpeBuilderHandle: int) -> int:

        return int(self.__Snpe_SNPEBuilder_Build(c_void_p(snpeBuilderHandle)))

    def Snpe_SNPE_GetInputTensorNames(self, snpeHandle: int) -> int:

        return int(self.__Snpe_SNPE_GetInputTensorNames(c_void_p(snpeHandle)))

    def Snpe_SNPE_GetOutputTensorNames(self, snpeHandle: int) -> int:

        return int(self.__Snpe_SNPE_GetOutputTensorNames(c_void_p(snpeHandle)))

    def Snpe_SNPE_ExecuteUserBuffers(self, snpeHandle: int, inputHandle: int, outputHandle: int) -> int:

        return int(self.__Snpe_SNPE_ExecuteUserBuffers(c_void_p(snpeHandle), c_void_p(inputHandle), c_void_p(outputHandle)))

    def Snpe_SNPE_GetInputDimensionsOfFirstTensor(self, snpeHandle: int) -> int:

        return int(self.__Snpe_SNPE_GetInputDimensionsOfFirstTensor(c_void_p(snpeHandle)))

    def Snpe_SNPE_Delete(self, snpeHandle: int) -> int:

        return int(self.__Snpe_SNPE_Delete(c_void_p(snpeHandle)))

    # Snpe_TensorShape_Handle_t

    def Snpe_TensorShape_CreateDimsSize(self, values: list) -> int:
        arr = (c_size_t * len(values))(*values)
        return int(self.__Snpe_TensorShape_CreateDimsSize(arr, len(values)))

    def Snpe_IBufferAttributes_GetDims(self, handle: int) -> int:

        return int(self.__Snpe_IBufferAttributes_GetDims(c_void_p(handle)))

    def Snpe_TensorShape_Rank(self, tensorShape: int) -> int:

        return int(self.__Snpe_TensorShape_Rank(c_void_p(tensorShape)))

    def Snpe_TensorShape_At(self, tensorShapeHandle: int, index: int) -> int:

        return int(self.__Snpe_TensorShape_At(c_void_p(tensorShapeHandle), c_size_t(index)))

    def Snpe_TensorShape_GetDimensions(self, tensorShape: int) -> list:
        rank = self.__Snpe_TensorShape_Rank(c_void_p(tensorShape))
        dim = self.__Snpe_TensorShape_GetDimensions(c_void_p(tensorShape))
        rc = None
        if rank != 0:
            rc = np.ctypeslib.as_array(dim, [rank]).tolist()
        return rc

    def Snpe_TensorShape_Delete(self, tensorShapeHandle: int) -> int:

        return int(self.__Snpe_TensorShape_Delete(c_void_p(tensorShapeHandle)))

    # Snpe_IUserBuffer_Handle_t
    def Snpe_Util_CreateUserBuffer(self, buffer: np.array, stridesHandle: int, userBufferEncodingHandle: int) -> int:
        buf = 0
        bufSize = 0
        if buffer is not None:
            buf, _ = buffer.__array_interface__['data']
            bufSize = len(buffer)
        return int(self.__Snpe_Util_CreateUserBuffer(c_void_p(buf), c_size_t(bufSize), c_void_p(stridesHandle), c_void_p(userBufferEncodingHandle)))

    def Snpe_UserBufferMap_GetUserBuffer_Ref(self, handle: int, name: str) -> int:

        return int(self.__Snpe_UserBufferMap_GetUserBuffer_Ref(c_void_p(handle), c_char_p(name.encode('utf-8'))))

    def Snpe_IUserBuffer_SetBufferAddress(self, userBufferHandle: int, buffer) -> int:
        buf = 0
        if buffer is not None:
            buf, _ = buffer.__array_interface__['data']
        return int(self.__Snpe_IUserBuffer_SetBufferAddress(c_void_p(userBufferHandle), c_void_p(buf)))

    def Snpe_IUserBuffer_GetEncoding_Ref(self, userBufferHandle: int) -> int:

        return int(self.__Snpe_IUserBuffer_GetEncoding_Ref(c_void_p(userBufferHandle)))

    def Snpe_IUserBuffer_GetSize(self, userBufferHandle: int) -> int:

        return int(self.__Snpe_IUserBuffer_GetSize(c_void_p(userBufferHandle)))

    def Snpe_IUserBuffer_GetOutputSize(self, userBufferHandle: int) -> int:

        return int(self.__Snpe_IUserBuffer_GetOutputSize(c_void_p(userBufferHandle)))

    def Snpe_IUserBuffer_Delete(self, userBufferHandle: int) -> int:

        return int(self.__Snpe_IUserBuffer_Delete(c_void_p(userBufferHandle)))

    # Snpe_UserBufferMap_Handle_t
    def Snpe_UserBufferMap_Create(self) -> int:

        return int(self.__Snpe_UserBufferMap_Create())

    def Snpe_UserBufferMap_Add(self, handle: int, name: str, bufferHandle: int) -> int:

        return int(self.__Snpe_UserBufferMap_Add(c_void_p(handle), c_char_p(name.encode('utf-8')), c_void_p(bufferHandle)))

    def Snpe_UserBufferMap_GetUserBufferNames(self, handle: int) -> int:

        return int(self.__Snpe_UserBufferMap_GetUserBufferNames(c_void_p(handle)))

    def Snpe_UserBufferMap_Delete(self, handle: int) -> int:

        return int(self.__Snpe_UserBufferMap_Delete(c_void_p(handle)))

    # Snpe_IBufferAttributes_Handle_t
    def Snpe_SNPE_GetInputOutputBufferAttributes(self, snpeHandle: int, name: str) -> int:

        return int(self.__Snpe_SNPE_GetInputOutputBufferAttributes(c_void_p(snpeHandle), c_char_p(name.encode('utf-8'))))

    def Snpe_IBufferAttributes_GetEncodingType(self, handle: int) -> int:

        return int(self.__Snpe_IBufferAttributes_GetEncodingType(c_void_p(handle)))

    def Snpe_IBufferAttributes_Delete(self, handle: int) -> int:

        return int(self.__Snpe_IBufferAttributes_Delete(c_void_p(handle)))

    # Snpe_UserBufferEncoding_Handle_t
    def Snpe_IBufferAttributes_GetEncoding_Ref(self, handle: int) -> int:

        return int(self.__Snpe_IBufferAttributes_GetEncoding_Ref(c_void_p(handle)))

    def Snpe_UserBufferEncoding_GetElementType(self, userBufferEncodingHandle: int) -> int:

        return int(self.__Snpe_UserBufferEncoding_GetElementType(c_void_p(userBufferEncodingHandle)))

    def Snpe_UserBufferEncodingFloat_Create(self) -> int:

        return int(self.__Snpe_UserBufferEncodingFloat_Create())

    def Snpe_UserBufferEncodingFloat_Delete(self, userBufferEncodingHandle: int) -> int:

        return int(self.__Snpe_UserBufferEncodingFloat_Delete(c_void_p(userBufferEncodingHandle)))

    def Snpe_UserBufferEncodingFloatN_Create(self, bWidth: np.uint8) -> int:

        return int(self.__Snpe_UserBufferEncodingFloatN_Create(c_uint8(bWidth)))

    def Snpe_UserBufferEncodingFloatN_Delete(self, userBufferEncodingHandle: int) -> int:

        return int(self.__Snpe_UserBufferEncodingFloatN_Delete(c_void_p(userBufferEncodingHandle)))

    def Snpe_UserBufferEncodingUnsigned8Bit_Create(self) -> int:

        return int(self.__Snpe_UserBufferEncodingUnsigned8Bit_Create())

    def Snpe_UserBufferEncodingUnsigned8Bit_Delete(self, userBufferEncodingHandle: int) -> int:

        return int(self.__Snpe_UserBufferEncodingUnsigned8Bit_Delete(c_void_p(userBufferEncodingHandle)))

    def Snpe_UserBufferEncodingUintN_Create(self, bWidth: np.uint8) -> int:

        return int(self.__Snpe_UserBufferEncodingUintN_Create(c_uint8(bWidth)))

    def Snpe_UserBufferEncodingUintN_Delete(self, userBufferEncodingHandle: int) -> int:

        return int(self.__Snpe_UserBufferEncodingUintN_Delete(c_void_p(userBufferEncodingHandle)))

    def Snpe_UserBufferEncodingIntN_Create(self, bWidth: np.uint8) -> int:

        return int(self.__Snpe_UserBufferEncodingIntN_Create(c_uint8(bWidth)))

    def Snpe_UserBufferEncodingIntN_Delete(self, userBufferEncodingHandle: int) -> int:

        return int(self.__Snpe_UserBufferEncodingIntN_Delete(c_void_p(userBufferEncodingHandle)))

    def Snpe_UserBufferEncodingTfN_Create(self, stepFor0: np.uint64, stepSize: float, bWidth: np.uint8) -> int:

        return int(self.__Snpe_UserBufferEncodingTfN_Create(c_uint64(stepFor0), c_float(stepSize), c_uint8(bWidth)))

    def Snpe_UserBufferEncodingTfN_GetStepExactly0(self, userBufferEncodingHandle: int) -> int:

        return int(self.__Snpe_UserBufferEncodingTfN_GetStepExactly0(c_void_p(userBufferEncodingHandle)))

    def Snpe_UserBufferEncodingTfN_GetQuantizedStepSize(self, userBufferEncodingHandle: int) -> float:

        return float(self.__Snpe_UserBufferEncodingTfN_GetQuantizedStepSize(c_void_p(userBufferEncodingHandle)))

    def Snpe_UserBufferEncodingTfN_SetStepExactly0(self, userBufferEncodingHandle: int, stepExactly0) -> None:

        stepExactly0 = np.uint64(stepExactly0)

        self.__Snpe_UserBufferEncodingTfN_SetStepExactly0(
            c_void_p(userBufferEncodingHandle), c_uint64(stepExactly0))

    def Snpe_UserBufferEncodingTfN_SetQuantizedStepSize(self, userBufferEncodingHandle: int, quantizedStepSize: float) -> None:

        self.__Snpe_UserBufferEncodingTfN_SetQuantizedStepSize(
            c_void_p(userBufferEncodingHandle), c_float(quantizedStepSize))

    def Snpe_UserBufferEncodingTfN_Delete(self, userBufferEncodingHandle: int) -> int:

        return int(self.__Snpe_UserBufferEncodingTfN_Delete(c_void_p(userBufferEncodingHandle)))

    # Snpe_IDiagLog_Handle_t
    def Snpe_SNPE_GetDiagLogInterface_Ref(self, snpeHandle: int) -> int:

        return int(self.__Snpe_SNPE_GetDiagLogInterface_Ref(c_void_p(snpeHandle)))

    def Snpe_IDiagLog_Start(self, diagLogHandle: int) -> int :

        return int(self.__Snpe_IDiagLog_Start(c_void_p(diagLogHandle)))

    def Snpe_IDiagLog_Stop(self, diagLogHandle: int) -> int :

        return int(self.__Snpe_IDiagLog_Stop(c_void_p(diagLogHandle)))
