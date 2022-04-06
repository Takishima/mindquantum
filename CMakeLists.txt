# ==============================================================================
#
# Copyright 2021 <Huawei Technologies Co., Ltd>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ==============================================================================

cmake_minimum_required(VERSION 3.20) # mainly because of NVHPC support

cmake_policy(VERSION 3.0...3.23)

list(PREPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)
list(PREPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake/Modules)

# ==============================================================================
# Macro definitions

include(${CMAKE_CURRENT_LIST_DIR}/cmake/macros.cmake)

# ==============================================================================
# Create the MindQuantum project

project(MindQuantum LANGUAGES C CXX)

# Set a default build type if none was specified
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE
      Release
      CACHE STRING "Choose the type of build." FORCE)
  # Set the possible values of build type for cmake-gui
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "RelWithDebInfo")
endif()

set(_doc_targets)

# ==============================================================================
# OS-detection

include(${CMAKE_CURRENT_LIST_DIR}/cmake/os_detection.cmake)

# ==============================================================================
# Options

include(${CMAKE_CURRENT_LIST_DIR}/cmake/options.cmake)

# ==============================================================================
# Package dependencies

include(${CMAKE_CURRENT_LIST_DIR}/cmake/packages.cmake)

# ==============================================================================
# Setup compiler flags

include(${CMAKE_CURRENT_LIST_DIR}/cmake/compiler_flags.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/linker_flags.cmake)

# ==============================================================================
# Some more macro definitions

if(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/mindquantum)
endif()

# ==============================================================================

# First add third-party libraries
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/third_party)

# Then re-define some CMake macros/functions
include(${CMAKE_CURRENT_LIST_DIR}/cmake/macros_more.cmake)

# Then add our libraries
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/ccsrc)

# ==============================================================================
# Convenience target to automatically build all pybind11 C++ modules

get_property(_targets GLOBAL PROPERTY _python_targets)
add_custom_target(
  python
  DEPENDS ${_targets}
  COMMENT "Build python C++ modules")

# ==============================================================================

if(binscope_exec)
  gen_binscope_target(${_targets})
endif()

# ==============================================================================
# Unit testing

if(BUILD_TESTING AND NOT IS_PYTHON_BUILD)
  enable_testing()
  add_subdirectory(tests)
else()
  message(STATUS "Disabling building of tests")
  message(STATUS "  (BUILD_TESTING=${BUILD_TESTING}, IS_PYTHON_BUILD=${IS_PYTHON_BUILD})")
  # Essentially only for CI builds with testing disabled
  add_custom_target(build_all_test COMMENT "Dummy target for CI builds")
  add_custom_target(test COMMENT "Dummy target for CI builds")
endif()

# ==============================================================================

if(NOT IS_PYTHON_BUILD)
  find_package(Doxygen QUIET)
  if(Doxygen_FOUND)
    add_subdirectory(docs)
  endif()
endif()

# ==============================================================================
