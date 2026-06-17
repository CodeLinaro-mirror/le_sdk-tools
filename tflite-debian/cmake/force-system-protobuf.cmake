# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# cmake/protobuf_redirect.cmake Creates a Protobuf "redirect" config so
# find_package(Protobuf) always uses the *system* FindProtobuf.cmake, regardless
# of CMAKE_MODULE_PATH contents.

# Make sure CMake provided the redirects directory (3.24+).
if(NOT DEFINED CMAKE_FIND_PACKAGE_REDIRECTS_DIR)
  message(FATAL_ERROR "CMAKE_FIND_PACKAGE_REDIRECTS_DIR is not defined. "
                      "Need CMake >= 3.24 for redirects.")
endif()

# Create a minimal 'protobuf-config.cmake' that forwards to the system finder.
file(
  WRITE "${CMAKE_FIND_PACKAGE_REDIRECTS_DIR}/protobuf-config.cmake"
  [=[
# Auto-generated redirect written into CMAKE_FIND_PACKAGE_REDIRECTS_DIR.
# Force the system FindProtobuf.cmake (from CMake's built-ins).
include("${CMAKE_ROOT}/Modules/FindProtobuf.cmake")
]=])

# Provide a permissive version file so any version query succeeds.
file(
  WRITE "${CMAKE_FIND_PACKAGE_REDIRECTS_DIR}/protobuf-config-version.cmake"
  [=[
# Always compatible; use exact if you prefer.
set(PACKAGE_VERSION_COMPATIBLE TRUE)
set(PACKAGE_VERSION_EXACT FALSE)
]=])
