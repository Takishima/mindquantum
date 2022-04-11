# ==============================================================================
#
# Copyright 2022 <Huawei Technologies Co., Ltd>
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
# NB: Some of the functions in this file have been adapted from version found in the MindSpore package.
# ==============================================================================

include(FetchContent)
set(FETCHCONTENT_QUIET OFF)

# ==============================================================================
# Setup helper variables

list(PREPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/modules)

# ------------------------------------------------------------------------------
# Default values for searching for packages using the Config method

set(MQ_FIND_NO_DEFAULT_PATH
    NO_CMAKE_PATH
    NO_CMAKE_ENVIRONMENT_PATH
    NO_SYSTEM_ENVIRONMENT_PATH
    NO_CMAKE_BUILDS_PATH
    NO_CMAKE_PACKAGE_REGISTRY
    NO_CMAKE_SYSTEM_PATH
    NO_CMAKE_SYSTEM_PACKAGE_REGISTRY)

# ------------------------------------------------------------------------------
# If the CMake generator is not `make`, then look for it NB: this is potentially used when installing packages in the
# local prefix path

if("${CMAKE_GENERATOR}" STREQUAL "Unix Makefiles")
  set(_make_exec ${CMAKE_MAKE_PROGRAM})
elseif(NOT WIN32)
  find_program(
    _make_exec
    NAMES make gmake
    DOC "Path to make command" REQUIRED)
endif()

# ------------------------------------------------------------------------------

if(NOT JOBS)
  include(ProcessorCount)
  ProcessorCount(JOBS)
endif()
message(STATUS "Calling make using ${JOBS} jobs")

# ------------------------------------------------------------------------------
# Allow the user to specify some packages to always built from source locally

if(MQ_FORCE_LOCAL_PKGS)
  string(TOLOWER ${MQ_FORCE_LOCAL_PKGS} _val)
  if("${_val}" STREQUAL "all")
    set(MQ_FORCE_LOCAL_PKGS ON)
  elseif(
    NOT
    ("${_val}" STREQUAL "on"
     OR "${_val}" STREQUAL "true"
     OR "${_val}" STREQUAL "1"
     OR "${_val}" STREQUAL "off"
     OR "${_val}" STREQUAL "false"
     OR "${_val}" STREQUAL "0"))
    string(REPLACE "," ";" MQ_FORCE_LOCAL_PKGS ${MQ_FORCE_LOCAL_PKGS})
    foreach(_name ${MQ_FORCE_LOCAL_PKGS})
      string(TOUPPER ${_name} _name)
      set(MQ_${_name}_FORCE_LOCAL ON)
      message(STATUS "MQ_${_name}_FORCE_LOCAL = ${MQ_${_name}_FORCE_LOCAL}")
    endforeach()
    set(MQ_FORCE_LOCAL_PKGS "")
  endif()
endif()

# ------------------------------------------------------------------------------
# Local prefix path for installing packages from source if we cannot find any suitable versions on the system

if(DEFINED ENV{MQLIBS_CACHE_PATH})
  set(_mq_local_prefix $ENV{MQLIBS_CACHE_PATH}) # similarly to MindSpore
elseif(DEFINED ENV{MQLIBS_LOCAL_PREFIX_PATH})
  set(_mq_local_prefix $ENV{MQLIBS_LOCAL_PREFIX_PATH})
else()
  set(_mq_local_prefix ${CMAKE_BINARY_DIR}/.mqlibs)
endif()
message(STATUS "MQ local prefix:  ${_mq_local_prefix}")

if(NOT EXISTS ${_mq_local_prefix})
  file(MAKE_DIRECTORY ${_mq_local_prefix})
endif()

string(FIND ${_mq_local_prefix} " " _whitespace)
if(NOT _whitespace EQUAL -1)
  message(
    WARNING
      [[
    There appear to be some whitespace in the path to the local prefix path. This could lead to some of the
    third-party libraries not installing properly
  ]])
endif()

# ------------------------------------------------------------------------------
# If desired (e.g. like on CIs), a local server can be used to download the source of packages that need to be built
# locally.

if(DEFINED ENV{MQLIBS_SERVER} AND NOT ENABLE_GITEE)
  set(_local_server $ENV{MQLIBS_SERVER})
elseif(LOCAL_LIBS_SERVER)
  set(_local_server ${LOCAL_LIBS_SERVER})
endif()

if(_local_server)
  if(_local_server MATCHES "(http|https|ssh|ftp)://(.*)")
    set(_local_server_protocol ${CMAKE_MATCH_1})
    set(_local_server ${CMAKE_MATCH_2})
  else()
    set(_local_server_protocol "http")
  endif()

  if(_local_server MATCHES "[ \t\r\n]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):([0-9]+)")
    set(_local_server_host ${CMAKE_MATCH_1})
    set(_local_server_port ${CMAKE_MATCH_2})
  elseif(_local_server MATCHES "[ \t\r\n]*([^:]+):([0-9]+)")
    set(_local_server_host ${CMAKE_MATCH_1})
    set(_local_server_port ${CMAKE_MATCH_2})
  else()
    set(_local_server_host ${_local_server})
    set(_local_server_port 8081)
  endif()

  set(_local_server "${_local_server_protocol}://${_local_server_host}:${_local_server_port}")

  message(STATUS "Local server for third-party libraries: ${_local_server}")

  if(NOT ENV{no_proxy})
    set(ENV{no_proxy} "${_local_server_host}")
  else()
    string(FIND $ENV{no_proxy} ${_local_server_host} IP_POS)
    if(${IP_POS} EQUAL -1)
      set(ENV{no_proxy} "$ENV{no_proxy},${_local_server_host}")
    endif()
  endif()
endif()

# ==============================================================================
# Functions to download a package from a URL or a GIT repository

# Wrapper around the FetchContent_XXX macros
macro(__do_fetch_content pkg_name pkg_url)
  FetchContent_GetProperties(${pkg_name})
  message(STATUS "download: ${${pkg_name}_SOURCE_DIR}, ${pkg_name}, ${pkg_url}")

  if(NOT ${pkg_name}_POPULATED)
    FetchContent_Populate(${pkg_name})
    string(TOLOWER ${pkg_name} _pkg_name)
    set(${pkg_name}_SOURCE_DIR
        ${${_pkg_name}_SOURCE_DIR}
        PARENT_SCOPE)
  endif()
endmacro()

# Fetch some content by downloading an archive
function(__download_pkg pkg_name pkg_url pkg_md5)
  if(_local_server)
    get_filename_component(_url_file_name ${pkg_url} NAME)
    set(pkg_url "${_local_server}/libs/${pkg_name}/${_url_file_name}" ${pkg_url})
  endif()

  FetchContent_Declare(
    ${pkg_name}
    URL ${pkg_url}
    URL_HASH MD5=${pkg_md5})

  __do_fetch_content(${pkg_name} ${pkg_url})
endfunction()

# Fetch some content by downloading a Git repository (or from an archive on the local server with a specific commit)
function(__download_pkg_with_git pkg_name pkg_url pkg_git_commit pkg_md5)
  if(_local_server)
    set(pkg_url "${_local_server}/libs/${pkg_name}/${pkg_git_commit}")
    FetchContent_Declare(
      ${pkg_name}
      URL ${pkg_url}
      URL_HASH MD5=${pkg_md5})
  else()
    FetchContent_Declare(
      ${pkg_name}
      GIT_REPOSITORY ${pkg_url}
      GIT_TAG ${pkg_git_commit})
  endif()

  __do_fetch_content(${pkg_name} ${pkg_url})
endfunction()

# ==============================================================================
# Some helper functions

# Wrapper over execute_process()
function(__exec_cmd)
  set(options)
  set(oneValueArgs WORKING_DIRECTORY)
  set(multiValueArgs COMMAND)

  cmake_parse_arguments(EXEC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(ENABLE_CMAKE_DEBUG)
    message(STATUS "  execute_process(")
    message(STATUS "      COMMAND ${EXEC_COMMAND}")
    message(STATUS "      WORKING_DIRECTORY ${EXEC_WORKING_DIRECTORY}")
    message(STATUS "      ...)")
  endif()

  # cmake-format: off
  execute_process(
    COMMAND ${EXEC_COMMAND}
    WORKING_DIRECTORY ${EXEC_WORKING_DIRECTORY}
    OUTPUT_VARIABLE _stdout
    ERROR_VARIABLE _stderr
    RESULTS_VARIABLE _results_out
    RESULT_VARIABLE RESULT)
  # cmake-format: on
  if(NOT RESULT EQUAL "0")
    if(ENABLE_CMAKE_DEBUG)
      message(SEND_ERROR "STDOUT:\n${_stdout}")
      message(SEND_ERROR "STDERR:\n${_stderr}")
      message(SEND_ERROR "RESULTS OUT:\n${_results_out}")
    endif()

    message(FATAL_ERROR "error! when ${EXEC_COMMAND} in ${EXEC_WORKING_DIRECTORY}")
  endif()
endfunction()

# ------------------------------------------------------------------------------

# Function to check that patches are valid
function(__check_patches pkg_patches)
  # check patches
  if(pkg_patches)
    file(TOUCH ${_mq_local_prefix}/${pkg_name}_patch.md5)
    file(READ ${_mq_local_prefix}/${pkg_name}_patch.md5 ${pkg_name}_PATCHES_MD5)

    message(STATUS "patches MD5:${${pkg_name}_PATCHES_MD5}")

    set(${pkg_name}_PATCHES_NEW_MD5)
    foreach(_patch ${pkg_patches})
      file(MD5 ${_patch} _patch_md5)
      set(${pkg_name}_PATCHES_NEW_MD5 "${${pkg_name}_PATCHES_NEW_MD5},${_patch_md5}")
    endforeach()

    if(NOT "${${pkg_name}_PATCHES_MD5}" STREQUAL "${${pkg_name}_PATCHES_NEW_MD5}")
      set(${pkg_name}_PATCHES ${pkg_patches})
      file(REMOVE_RECURSE "${_mq_local_prefix}/${pkg_name}-subbuild")
      file(WRITE ${_mq_local_prefix}/${pkg_name}_patch.md5 ${${pkg_name}_PATCHES_NEW_MD5})
      message(STATUS "patches changed : ${${pkg_name}_PATCHES_NEW_MD5}")
    endif()
  endif()
endfunction()

# ------------------------------------------------------------------------------

# ~~~
# Extract a number of elements from a list
#
# __create_target_aliases(<start_idx>, <stop_idx> <var_name>)
# ~~~
function(__extract_n_args start stop var)
  # cmake-lint: disable=E1120
  set(num_range)
  foreach(idx RANGE ${start} ${stop})
    list(APPEND num_range ${idx})
  endforeach()
  list(GET ARGN ${num_range} _value)
  set(${var}
      ${_value}
      PARENT_SCOPE)
endfunction()

# ~~~
# Create target aliases based on a list of either
#  1. tuple of key-value pairs where:
#      + key: target alias name
#      + value: target to alias
#  2. triplets of the form (number, values) where:
#      + number: size of values list
#      + values: list of values [alias, targets]
#         * alias: target alias name
#         * targets: list of potential targets to alias
#
# Using 1. syntax:
# __create_target_aliases([[<tgt_alias>, <tgt_name>]...])
# Using 2. syntax:
# __create_target_aliases([[<N> <tgt_alias>, <tgt_name_1>...<tgt_name_N>]...])
#
# Examples:
# __create_target_aliases(A B 3 D E F)
#   -> create alias A -> B, and either D -> E or D -> F
# ~~~
function(__create_target_aliases)
  # cmake-lint: disable=R0915
  list(LENGTH ARGN n_args)
  if(NOT n_args)
    return()
  endif()

  message(STATUS "Creating mindspore target aliases")
  list(APPEND CMAKE_MESSAGE_INDENT "  ")

  set(idx 0)
  while(idx LESS n_args)
    set(incr 2)
    list(GET ARGN ${idx} _arg)
    if(_arg MATCHES "^[0-9]+$")
      set(incr ${_arg})
      math(EXPR incr "${incr} + 1") # NB: we need to count _arg itself for shifting
      math(EXPR start "${idx} + 1")
    else()
      set(start ${idx})
    endif()
    math(EXPR stop "${idx} + ${incr} -1")
    __extract_n_args(${start} ${stop} _args ${ARGN})
    math(EXPR idx "${idx} + ${incr}")

    # ----------------------------------

    list(POP_FRONT _args tgt_alias)
    set(tgt_list ${_args})

    set(tgt_name)
    foreach(_tgt ${tgt_list})
      if(NOT TARGET ${_tgt})
        message(STATUS "${_tgt} does not exist... -> skipping")
      else()
        message(STATUS "${_tgt} exists -> using it")
        set(tgt_name ${_tgt})
        break()
      endif()
    endforeach()
    if("${tgt_name}" STREQUAL "")
      message(FATAL_ERROR "None of ${tgt_list} targets can be found, not defining ${tgt_alias} alias")
    endif()

    get_target_property(_aliased ${tgt_name} ALIASED_TARGET)
    if(_aliased)
      set(tgt_name ${_aliased})
    endif()

    get_target_property(_imported ${tgt_name} IMPORTED)
    get_target_property(_imported_global ${tgt_name} IMPORTED_GLOBAL)
    if(_imported AND NOT _imported_global)
      set_property(TARGET ${tgt_name} PROPERTY IMPORTED_GLOBAL TRUE)
    endif()

    get_target_property(_aliased ${tgt_name} ALIASED_TARGET)
    if(_aliased)
      set(tgt_name ${_aliased})
    endif()

    get_target_property(_type ${tgt_name} TYPE)
    if("${_type}" STREQUAL "EXECUTABLE")
      add_executable(${tgt_alias} ALIAS ${tgt_name})
    else()
      add_library(${tgt_alias} ALIAS ${tgt_name})
    endif()
    message(STATUS "Creating alias target: ${tgt_alias} -> ${tgt_name}")
  endwhile()
  list(POP_BACK CMAKE_MESSAGE_INDENT)
endfunction()

# ------------------------------------------------------------------------------

# ~~~
# Find the largest common prefix of two strings
#
# __largest_common_prefix(<a> <b> <var>)
# ~~~
function(__largest_common_prefix str_a str_b var)
  # cmake-lint: disable=E1120
  string(LENGTH "${str_a}" _len_a)
  string(LENGTH "${str_b}" _len_b)

  if(${_len_a} LESS ${_len_b})
    set(_len ${_len_a})
  else()
    set(_len ${_len_b})
  endif()

  # iterate over the length
  foreach(end RANGE 1 ${_len})
    # get substrings
    string(SUBSTRING "${str_a}" 0 ${end} sub_a)
    string(SUBSTRING "${str_b}" 0 ${end} sub_b)

    if("${sub_a}" STREQUAL "${sub_b}")
      set(${var}
          ${sub_a}
          PARENT_SCOPE)
    else()
      break()
    endif()
  endforeach()
endfunction()

# ==============================================================================

# ~~~
# Extract imported location from an interface library
#
# __get_imported_location_from_interface_library(<target> <out-var>)
# ~~~
function(__get_imported_location_from_interface_library tgt var)
  # cmake-lint: disable=E1126
  set(_basename ${tgt})
  if(tgt MATCHES "([a-zA-Z0-9_]+)::([a-zA-Z0-9_]+)")
    set(_basename ${CMAKE_MATCH_2})
    string(TOLOWER ${CMAKE_MATCH_2} _basename_lower)
  endif()

  set(_imported_location _imported_location-NOTFOUND)
  get_target_property(_libs ${tgt} INTERFACE_LINK_LIBRARIES)
  if(_libs)
    foreach(_lib ${_libs})
      if(_lib MATCHES ".*${_basename}.*" OR _lib MATCHES ".*${_basename_lower}.*")
        set(_imported_location "${_lib}")
        real_path("${_imported_location}" _imported_location)
        break()
      endif()
    endforeach()
  endif()
  set(${var}
      "${_imported_location}"
      PARENT_SCOPE)
endfunction()

# ------------------------------------------------------------------------------

# ~~~
# Get the imported location of a library
#
# __get_library_imported_location(<target> <out-var>)
# ~~~
function(__get_library_imported_location tgt var)
  # cmake-lint: disable=E1126
  foreach(_prop IMPORTED_LOCATION IMPORTED_LOCATION_DEBUG IMPORTED_LOCATION_RELEASE IMPORTED_LOCATION_NONE
                IMPORTED_LOCATION_NOCONFIG)
    get_target_property(_location ${tgt} ${_prop})
    if(_location)
      real_path("${_location}" _location)
      set(${var}
          ${_location}
          PARENT_SCOPE)
      return()
    endif()
  endforeach()
  set(${var}
      ""
      PARENT_SCOPE)
endfunction()

# ------------------------------------------------------------------------------

# ~~~
# Get the real type of a library
#
# __get_library_real_type(<filename> <out-var>)
# ~~~
function(__get_library_real_type filename var)
  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.20)
    cmake_path(GET filename EXTENSION _ext)
  else()
    get_filename_component(_ext "${filename}" EXT)
  endif()

  if(_ext MATCHES "${CMAKE_SHARED_LIBRARY_SUFFIX}(\\.[0-9]+)*")
    set(${var}
        "SHARED_LIBRARY"
        PARENT_SCOPE)
  elseif(_ext MATCHES "${CMAKE_STATIC_LIBRARY_SUFFIX}")
    set(${var}
        "STATIC_LIBRARY"
        PARENT_SCOPE)
  else()
    set(${var}
        "UNKNOWN_LIBRARY"
        PARENT_SCOPE)
  endif()
endfunction()

# ------------------------------------------------------------------------------

# ~~~
# Generate a "fake" CMake config file for packages not built using CMake
#
# __generate_pseudo_cmake_package_config(<dest_dir> <pkg_name> <pkg_namespace> <components>)
# ~~~
function(__generate_pseudo_cmake_package_config root_dir pkg_name pkg_namespace comp_list)
  # cmake-lint: disable=R0912,R0915,W0106,E1126
  set(dest_dir "${root_dir}/${pkg_name}/share/${pkg_name}")
  set(tgt_list)
  foreach(_comp ${comp_list})
    if(TARGET ${pkg_namespace}::${_comp})
      list(APPEND tgt_list ${pkg_namespace}::${_comp})
    endif()
    if(TARGET ${pkg_namespace}::${PKG_NS_NAME}_${_comp})
      list(APPEND tgt_list ${pkg_namespace}::${PKG_NS_NAME}_${_comp})
    endif()
  endforeach()

  # ----------------------------------------------------------------------------

  file(MAKE_DIRECTORY ${dest_dir})
  string(REPLACE ";" "\;" tgt_list_escaped "${tgt_list}")

  # ----------------------------------------------------------------------------

  set(_config_version_content
      [[
set(PACKAGE_VERSION "${PKG_VER}")

if (PACKAGE_FIND_VERSION_RANGE)
  # Package version must be in the requested version range
  if (("${PACKAGE_FIND_VERSION_RANGE_MIN}" STREQUAL "INCLUDE" AND PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION_MIN)
      OR (("${PACKAGE_FIND_VERSION_RANGE_MAX}" STREQUAL "INCLUDE"
             AND PACKAGE_VERSION VERSION_GREATER PACKAGE_FIND_VERSION_MAX)
           OR ("${PACKAGE_FIND_VERSION_RANGE_MAX}" STREQUAL "EXCLUDE"
                 AND PACKAGE_VERSION VERSION_GREATER_EQUAL PACKAGE_FIND_VERSION_MAX)))
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
  else()
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
  endif()
else()
  if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
  else()
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
    if("${PACKAGE_FIND_VERSION}" STREQUAL "${PACKAGE_VERSION}")
      set(PACKAGE_VERSION_EXACT TRUE)
    endif()
  endif()
endif()
]])
  file(WRITE ${dest_dir}/${pkg_name}ConfigVersion.cmake ${_config_version_content})

  # ----------------------------------------------------------------------------

  set(_config_content
      [[
get_filename_component(_IMPORT_PREFIX "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_IMPORT_PREFIX "${_IMPORT_PREFIX}" PATH)
get_filename_component(_IMPORT_PREFIX "${_IMPORT_PREFIX}" PATH)
get_filename_component(_IMPORT_PREFIX "${_IMPORT_PREFIX}" PATH)
if("${_IMPORT_PREFIX}" STREQUAL "/")
  set(_IMPORT_PREFIX "")
endif()
]]
      "include (\"\${CMAKE_CURRENT_LIST_DIR}/${pkg_name}Targets.cmake\")\n")
  file(WRITE ${dest_dir}/${pkg_name}Config.cmake ${_config_content})

  # ----------------------------------------------------------------------------

  set(_targets_prefix_content
      [[
cmake_policy(PUSH)
cmake_policy(VERSION 2.6...3.20)

set(CMAKE_IMPORT_FILE_VERSION 1)

]])

  set(_targets_suffix_content
      [[

if(CMAKE_VERSION VERSION_LESS 3.0.0)
  message(FATAL_ERROR "This file relies on consumers using CMake 3.0.0 or greater.")
endif()

set(CMAKE_IMPORT_FILE_VERSION)
cmake_policy(POP)
]])

  foreach(_tgt ${tgt_list})
    if(NOT TARGET ${_tgt})
      continue()
    endif()

    get_target_property(_libs ${_tgt} INTERFACE_LINK_LIBRARIES)
    if(_libs)
      foreach(_lib ${_libs})
        if(_lib MATCHES "([a-zA-Z0-9_]+)::([a-zA-Z0-9_]+)")
          set(_ns ${CMAKE_MATCH_1})
          set(_tgt ${CMAKE_MATCH_2})

          if("${_ns}" STREQUAL "${ns}" AND TARGET ${_lib})
            list(PREPEND tgt_list ${_lib})
          endif()
        endif()
      endforeach()
    endif()
  endforeach()

  set(_tgt_props
      COMPILE_DEFINITIONS
      COMPILE_FEATURES
      COMPILE_OPTIONS
      INCLUDE_DIRECTORIES
      LINK_OPTIONS
      LINK_LIBRARIES
      INTERFACE_COMPILE_DEFINITIONS
      INTERFACE_COMPILE_FEATURES
      INTERFACE_COMPILE_OPTIONS
      INTERFACE_INCLUDE_DIRECTORIES
      INTERFACE_LINK_OPTIONS
      INTERFACE_LINK_LIBRARIES
      IMPORTED_CONFIGURATIONS
      IMPORTED_SONAME
      IMPORTED_SONAME_DEBUG
      IMPORTED_SONAME_RELEASE
      IMPORTED_LOCATION
      IMPORTED_LOCATION_DEBUG
      IMPORTED_LOCATION_RELEASE
      IMPORTED_LOCATION_NONE
      IMPORTED_LOCATION_NOCONFIG)

  real_path("${root_dir}" root_dir_absolute)
  set(_library_content)
  foreach(_tgt ${tgt_list})
    if(NOT TARGET ${_tgt})
      continue()
    endif()

    list(APPEND _library_content "if(NOT TARGET ${_tgt})\n")

    get_target_property(_type ${_tgt} TYPE)

    # If the CMake library type is UNKNOWN, try to guess it
    if("${_type}" STREQUAL "UNKNOWN_LIBRARY")
      __get_library_imported_location(${_tgt} _location)
      __get_library_real_type("${_location}" _type)
    elseif("${_type}" STREQUAL "INTERFACE_LIBRARY")
      __get_imported_location_from_interface_library(${_tgt} _imported_location)
      if(_imported_location)
        __get_library_real_type("${_imported_location}" _type)
      endif()
    endif()

    if("${_type}" STREQUAL "EXECUTABLE")
      list(APPEND _library_content "  add_executable(${_tgt} IMPORTED)\n")
    elseif("${_type}" STREQUAL "UNKNOWN_LIBRARY")
      list(APPEND _library_content "  add_library(${_tgt} UNKNOWN IMPORTED)\n")
    elseif("${_type}" STREQUAL "INTERFACE_LIBRARY")
      list(APPEND _library_content "  add_library(${_tgt} INTERFACE IMPORTED)\n")
    elseif("${_type}" STREQUAL "STATIC_LIBRARY")
      list(APPEND _library_content "  add_library(${_tgt} STATIC IMPORTED)\n")
    elseif("${_type}" STREQUAL "SHARED_LIBRARY")
      list(APPEND _library_content "  add_library(${_tgt} SHARED IMPORTED)\n")
    endif()

    if(_imported_location)
      list(APPEND _library_content "\n  set_target_properties(${_tgt} PROPERTIES\n")
      list(APPEND _library_content "      IMPORTED_LOCATION \"${_imported_location}\"")
      list(APPEND _library_content "  )\n")
    endif()

    list(APPEND _library_content "\n  set_target_properties(${_tgt} PROPERTIES\n")
    foreach(_prop ${_tgt_props})
      get_target_property(_val ${_tgt} ${_prop})
      if(_val)
        set(_resolved_var)
        foreach(_value ${_val})
          if(EXISTS "${_value}")
            real_path("${_value}" _value)
            string(REPLACE "${root_dir_absolute}" "\${_IMPORT_PREFIX}" _value "${_value}")
          endif()
          list(APPEND _resolved_var "${_value}")
        endforeach()
        set(_val ${_resolved_var})

        if(_imported_location)
          list(REMOVE_ITEM _val "${_imported_location}")
        endif()

        if(NOT "${_val}" STREQUAL "")
          string(REPLACE ";" "\;" _val "${_val}")
          list(APPEND _library_content "       ${_prop} \"${_val}\"\n")
        endif()
      endif()
    endforeach()
    list(APPEND _library_content "  )\n\n\n")

    list(APPEND _library_content "endif()\n")
  endforeach()

  if(_${pkg}_COMPONENTS_SEARCHED)
    string(REPLACE ";" "\;" _val "${_${pkg}_COMPONENTS_SEARCHED}")
    list(APPEND _library_content "set(_${pkg}_COMPONENTS_SEARCHED ${_val})\n\n\n")
  endif()

  file(WRITE ${dest_dir}/${pkg_name}Targets.cmake ${_targets_prefix_content} ${_library_content}
       ${_targets_suffix_content})
endfunction()

# ==============================================================================

# ~~~
# Find a package.
#
# In practice this calls find_package() and performs some additional checks
#
# __find_package(<pkg_name>
#                <version>
#                <components>
#                <pkg_search_no_components>
#                <search_name>)
# ~~~
macro(__find_package pkg_name version components pkg_search_no_components search_name) # cmake-lint: disable=R0913
  message(CHECK_START "Looking ${pkg_name} using CMake find_package(): ${search_name}")

  list(APPEND CMAKE_MESSAGE_INDENT "  ")

  string(TOUPPER ${pkg_name} PKG_NAME)

  set(_find_package_args)
  if(PKG_FORCE_EXACT_VERSION)
    list(APPEND _find_package_args EXACT)
  endif()

  if(NOT pkg_search_no_components AND NOT "${components}" STREQUAL "")
    list(APPEND _find_package_args COMPONENTS ${components})
  endif()

  # Prefer system installed libraries instead of compiling everything from source
  if(ENABLE_CMAKE_DEBUG)
    message(STATUS "find_package(${pkg_name} ${version} ${_find_package_args} ${ARGN})")
  endif()
  find_package(${pkg_name} ${version} ${_find_package_args} ${ARGN})
  if(${pkg_name}_FOUND)
    list(POP_BACK CMAKE_MESSAGE_INDENT)
    message(CHECK_PASS "Done")
  else()
    list(POP_BACK CMAKE_MESSAGE_INDENT)
    message(CHECK_FAIL "Failed")
  endif()
endmacro()

# ------------------------------------------------------------------------------

# ~~~
# Make sure that a package was located in a specific root directory
#
# __check_package_location(<base_dir> <pkg_name> <pkg_namespace>)
# ~~~
function(__check_package_location pkg_name pkg_namespace)
  file(TO_CMAKE_PATH "${${pkg_name}_BASE_DIR}" _base_dir)
  set(_tgt_list)
  foreach(_comp ${ARGN})
    set(_tgt ${pkg_namespace}::${_comp})
    if(TARGET ${_tgt})
      foreach(_prop IMPORTED_LOCATION IMPORETD_LOCATION_DEBUG IMPORTED_LOCATION_RELEASE IMPORTED_LOCATION_NONE
                    IMPORTED_LOCATION_NOCONFIG)
        get_target_property(_imported_location ${_tgt} ${_prop})
        if(_imported_location)
          file(TO_CMAKE_PATH "${_imported_location}" _imported_location)
          break()
        endif()
      endforeach()
      if(_imported_location)
        string(FIND "${_imported_location}" "${_base_dir}" _idx)
        if(_idx LESS 0)
          message(
            FATAL_ERROR
              "Imported location of ${_tgt} not found in ${_base_dir}!
- ${_imported_location}
Please clear up CMake cache (${CMAKE_CURRENT_BINARY_DIR}/CMakeCache.txt and re-run CMake.")
        endif()
      endif()
    endif()
  endforeach()
endfunction()

# ------------------------------------------------------------------------------

# ~~~
# Make imported targets global (also make alias global if possible)
#
# __make_target_global(<pkg_namespace> [<target>, ...])
# ~~~
function(__make_target_global pkg_namespace)
  foreach(_tgt ${ARGN})
    set(_tgt ${pkg_namespace}::${_tgt})

    get_target_property(_aliased ${_tgt} ALIASED_TARGET)
    if(_aliased)
      if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.18)
        set_property(TARGET ${_tgt} PROPERTY ALIAS_GLOBAL TRUE)
      endif()
      set(_tgt ${_aliased})
    endif()

    set_property(TARGET ${_tgt} PROPERTY IMPORTED_GLOBAL TRUE)
  endforeach()
endfunction()

# ==============================================================================
# ==============================================================================

# ~~~
# Add an external dependency
#
# mindquantum_add_pkg(<pkg_name>
#                     [CMAKE_PKG_NO_COMPONENTS, FORCE_CONFIG_SEARCH, FORCE_EXACT_VERSION, GEN_CMAKE_CONFIG,
#                        ONLY_MAKE, ONLY_UNPACK, SKIP_BUILD_STEP, SKIP_INSTALL_STEP]
#                      [CMAKE_PATH <path-to-cmakefiles-txt>]
#                      [CUSTOM_CMAKE <custom_cmake>]
#                      [DIR <pkg-cache-directory>]
#                      [EXE <exec-name>]
#                      [GIT_REPOSITORY <git-url>]
#                      [GIT_TAG <tag>]
#                      [MD5 <archive-md5>]
#                      [NS_NAME <ns_name>]
#                      [URL <archive-url>]
#                      [VER <version-num>]
#                      [BUILD_COMMAND  <command> [... <args>]]
#                      [BUILD_DEPENDENCIES <package> [... <package>]]
#                      [BUILD_OPTION <option> [... <option>]]
#                      [CMAKE_OPTION <cmake_option> [... <cmake_option>]]
#                      [CONFIGURE_COMMAND  <command> [... <args>]]
#                      [COPY_TO_BINARY_DIR <COPY_TO_BINARY_DIR>]
#                      [INSTALL_COMMAND  <command> [... <args>]]
#                      [INSTALL_INCS <directory> [... <directory>]]
#                      [INSTALL_LIBS <directory> [... <directory>]]
#                      [LIBS <lib-names> [... <lib-names>]]
#                      [ONLY_MAKE_INCS <directory> [... <directory>]]
#                      [ONLY_MAKE_LIBS <directory> [... <directory>]]
#                      [PATCHES <patch-file> [... <patch-file>]]
#                      [PRE_CONFIGURE_COMMAND <command> [... <args>]]
#                      [TARGET_ALIAS <alias-name> <target-library>|
#                         TARGET_ALIAS <num> <alias-name> <target-library> [...<target-library>]]
# )
#
# BUILD_DEPENDENCIES is a list of lists of arguments to pass onto to `find_package()` prior to start building the
# package.
# e.g. (... BUILD_DEPENDENCIES "Git REQUIRED" "Boost COMPONENTS system" ...)
# ~~~
function(mindquantum_add_pkg pkg_name)
  # cmake-lint: disable=R0912,R0915,C0103,E1126
  set(options
      CMAKE_PKG_NO_COMPONENTS
      FORCE_CONFIG_SEARCH
      FORCE_EXACT_VERSION
      GEN_CMAKE_CONFIG
      ONLY_MAKE
      ONLY_UNPACK
      SKIP_BUILD_STEP
      SKIP_INSTALL_STEP)
  set(oneValueArgs
      CMAKE_PATH
      CUSTOM_CMAKE
      DIR
      EXE
      GIT_REPOSITORY
      GIT_TAG
      MD5
      NS_NAME
      URL
      VER)
  set(multiValueArgs
      BUILD_COMMAND
      BUILD_DEPENDENCIES
      BUILD_OPTION
      CMAKE_OPTION
      CONFIGURE_COMMAND
      COPY_TO_BINARY_DIR
      INSTALL_COMMAND
      INSTALL_INCS
      INSTALL_LIBS
      LIBS
      ONLY_MAKE_INCS
      ONLY_MAKE_LIBS
      PATCHES
      PRE_CONFIGURE_COMMAND
      TARGET_ALIAS)
  cmake_parse_arguments(PKG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT PKG_NS_NAME)
    set(PKG_NS_NAME ${pkg_name})
  endif()

  set(_components ${PKG_LIBS} ${PKG_EXE})

  string(TOUPPER ${pkg_name} PKG_NAME)

  message(CHECK_START "Adding external dependency: ${pkg_name}")
  list(APPEND CMAKE_MESSAGE_INDENT "  ")

  if(NOT MQ_FORCE_LOCAL_PKGS AND NOT MQ_${PKG_NAME}_FORCE_LOCAL)
    set(_args)
    if(PKG_FORCE_CONFIG_SEARCH)
      list(APPEND _args CONFIG)
    endif()
    __find_package("${pkg_name}" "${PKG_VER}" "${_components}" "${PKG_CMAKE_PKG_NO_COMPONENTS}" "system packages"
                   ${_args})

    if(${pkg_name}_FOUND)
      if(${pkg_name}_DIR)
        message(STATUS "Package CMake config dir: ${${pkg_name}_DIR}")
      endif()
      __make_target_global(${PKG_NS_NAME} ${PKG_LIBS} ${PKG_EXE})
      __create_target_aliases(${PKG_TARGET_ALIAS})

      list(POP_BACK CMAKE_MESSAGE_INDENT)
      message(CHECK_PASS "Done")
      return()
    endif()

    # Otherwise we try to compile from source
  endif()

  # ==============================================================================
  # Ignore system installed libraries and compile a local version instead

  set(${pkg_name}_PATCHES_HASH)
  foreach(_patch ${PKG_PATCHES})
    file(MD5 ${_patch} _patch_md5)
    set(${pkg_name}_PATCHES_HASH "${${pkg_name}_PATCHES_HASH},${_patch_md5}")
  endforeach()

  # check options
  set(${pkg_name}_CONFIG_TXT
      "${CMAKE_CXX_COMPILER_VERSION}-${CMAKE_C_COMPILER_VERSION}
            ${ARGN} - ${${pkg_name}_USE_STATIC_LIBS}- ${${pkg_name}_PATCHES_HASH}
            ${${pkg_name}_CXXFLAGS}--${${pkg_name}_CFLAGS}--${${pkg_name}_LDFLAGS}")
  string(REPLACE ";" "-" ${pkg_name}_CONFIG_TXT ${${pkg_name}_CONFIG_TXT})
  string(MD5 ${pkg_name}_CONFIG_HASH ${${pkg_name}_CONFIG_TXT})

  message(STATUS "${pkg_name} config hash: ${${pkg_name}_CONFIG_HASH}")

  set(${pkg_name}_BASE_DIR ${_mq_local_prefix}/${pkg_name}_${PKG_VER}_${${pkg_name}_CONFIG_HASH})
  set(${pkg_name}_DIRPATH
      ${${pkg_name}_BASE_DIR}
      CACHE STRING INTERNAL)

  if(EXISTS "${${pkg_name}_BASE_DIR}")
    __find_package(
      "${pkg_name}"
      "${PKG_VER}"
      "${_components}"
      "${PKG_CMAKE_PKG_NO_COMPONENTS}"
      "MindQuantum build dir"
      CONFIG
      ${MQ_FIND_NO_DEFAULT_PATH}
      PATHS
      "${${pkg_name}_BASE_DIR}")
    if(${pkg_name}_FOUND)
      if(${pkg_name}_DIR)
        message(STATUS "Package CMake config dir: ${${pkg_name}_DIR}")
      endif()
      __check_package_location(${pkg_name} ${PKG_NS_NAME} ${PKG_LIBS} ${PKG_EXE})
      __make_target_global(${PKG_NS_NAME} ${PKG_LIBS} ${PKG_EXE})
      __create_target_aliases(${PKG_TARGET_ALIAS})

      list(POP_BACK CMAKE_MESSAGE_INDENT)
      message(CHECK_PASS "Done")
      return()
    endif()
  endif()

  if(NOT PKG_DIR)
    message(STATUS "PKG_GIT_REPOSITORY = ${PKG_GIT_REPOSITORY}")
    if(PKG_GIT_REPOSITORY)
      __download_pkg_with_git(${pkg_name} ${PKG_GIT_REPOSITORY} ${PKG_GIT_TAG} ${PKG_MD5})
    else()
      __download_pkg(${pkg_name} ${PKG_URL} ${PKG_MD5})
    endif()
  else()
    set(${pkg_name}_SOURCE_DIR ${PKG_DIR})
  endif()
  file(WRITE ${${pkg_name}_BASE_DIR}/options.txt ${${pkg_name}_CONFIG_TXT})
  message(STATUS "${pkg_name}_SOURCE_DIR : ${${pkg_name}_SOURCE_DIR}")

  apply_patches("${${pkg_name}_SOURCE_DIR}" ${PKG_PATCHES})

  file(
    LOCK
    ${${pkg_name}_BASE_DIR}
    DIRECTORY
    GUARD
    FUNCTION
    RESULT_VARIABLE
    ${pkg_name}_LOCK_RET
    TIMEOUT
    600)
  if(NOT ${pkg_name}_LOCK_RET EQUAL "0")
    message(FATAL_ERROR "error! when try lock ${${pkg_name}_BASE_DIR} : ${${pkg_name}_LOCK_RET}")
  endif()

  if(PKG_CUSTOM_CMAKE)
    file(GLOB ${pkg_name}_cmake ${PKG_CUSTOM_CMAKE}/CMakeLists.txt)
    file(COPY ${${pkg_name}_cmake} DESTINATION ${${pkg_name}_SOURCE_DIR})
  endif()

  if(${pkg_name}_SOURCE_DIR)
    # Look for any dependencies (if any)
    foreach(_pkg_dep ${PKG_BUILD_DEPENDENCIES})
      if(ENABLE_CMAKE_DEBUG)
        message(STATUS "Looking for build dependency for ${pkg_name}: find_package(${_pkg_dep} REQUIRED)")
      endif(ENABLE_CMAKE_DEBUG)
      find_package(${_pkg_dep} REQUIRED)
    endforeach()

    if(PKG_ONLY_UNPACK)
      file(GLOB ${pkg_name}_SOURCE_SUBDIRS ${${pkg_name}_SOURCE_DIR}/*)
      file(COPY ${${pkg_name}_SOURCE_SUBDIRS} DESTINATION ${${pkg_name}_BASE_DIR})
    elseif(PKG_COPY_TO_BINARY_DIR)
      set(_dir_list)
      foreach(_dir ${PKG_COPY_TO_BINARY_DIR})
        message(STATUS "Copying ${${pkg_name}_SOURCE_DIR}/${_dir} -> ${CMAKE_BINARY_DIR}/${pkg_name}")
        file(COPY ${${pkg_name}_SOURCE_DIR}/${_dir} DESTINATION ${CMAKE_BINARY_DIR}/${pkg_name})
        list(APPEND _dir_list ${CMAKE_BINARY_DIR}/${pkg_name})
      endforeach()

      set(${pkg_name}_INC
          ${${CMAKE_BINARY_DIR}/${pkg_name}}
          PARENT_SCOPE)

      add_library(${PKG_NS_NAME}::${pkg_name} INTERFACE IMPORTED)
      target_include_directories(${PKG_NS_NAME}::${pkg_name} INTERFACE ${_dir_list})

      message(STATUS "Generating fake CMake config file...")
      __generate_pseudo_cmake_package_config("${${pkg_name}_BASE_DIR}" ${pkg_name} ${PKG_NS_NAME} "${pkg_name}")
    elseif(PKG_ONLY_MAKE)
      __exec_cmd(COMMAND ${_make_exec} ${${pkg_name}_CXXFLAGS} -j${JOBS} WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR})
      set(PKG_INSTALL_INCS ${PKG_ONLY_MAKE_INCS})
      set(PKG_INSTALL_LIBS ${PKG_ONLY_MAKE_LIBS})
      file(GLOB ${pkg_name}_INSTALL_INCS ${${pkg_name}_SOURCE_DIR}/${PKG_INSTALL_INCS})
      file(GLOB ${pkg_name}_INSTALL_LIBS ${${pkg_name}_SOURCE_DIR}/${PKG_INSTALL_LIBS})
      file(COPY ${${pkg_name}_INSTALL_INCS} DESTINATION ${${pkg_name}_BASE_DIR}/include)
      file(COPY ${${pkg_name}_INSTALL_LIBS} DESTINATION ${${pkg_name}_BASE_DIR}/lib)

    elseif(NOT "${PKG_CMAKE_OPTION}" STREQUAL "")
      # in cmake
      file(MAKE_DIRECTORY ${${pkg_name}_SOURCE_DIR}/_build)
      if(${pkg_name}_CFLAGS)
        set(${pkg_name}_CMAKE_CFLAGS "-DCMAKE_C_FLAGS=${${pkg_name}_CFLAGS}")
      endif()

      if(${pkg_name}_CXXFLAGS)
        set(${pkg_name}_CMAKE_CXXFLAGS "-DCMAKE_CXX_FLAGS=${${pkg_name}_CXXFLAGS}")
      endif()

      if(MSVC)
        if(ENABLE_MT)
          set(${pkg_name}_CL_RT_FLAG "-DCMAKE_CXX_FLAGS_DEBUG=/MTd" "-DCMAKE_CXX_FLAGS_RELEASE=/MT")
        elseif(ENABLE_MD)
          set(${pkg_name}_CL_RT_FLAG "-DCMAKE_CXX_FLAGS_DEBUG=/MDd" "-DCMAKE_CXX_FLAGS_RELEASE=/MD")
        endif()
      endif()

      if(${pkg_name}_LDFLAGS)
        if(${pkg_name}_USE_STATIC_LIBS)
          # set(${pkg_name}_CMAKE_LDFLAGS "-DCMAKE_STATIC_LINKER_FLAGS=${${pkg_name}_LDFLAGS}")
        else()
          set(${pkg_name}_CMAKE_LDFLAGS "-DCMAKE_SHARED_LINKER_FLAGS=${${pkg_name}_LDFLAGS}")
        endif()
      endif()
      if(NOT APPLE)
        list(APPEND PKG_CMAKE_OPTION -G ${CMAKE_GENERATOR})
      endif()

      message(STATUS "Calling CMake configure for ${pkg_name}")
      __exec_cmd(
        COMMAND
          ${CMAKE_COMMAND} ${PKG_CMAKE_OPTION} ${${pkg_name}_CMAKE_CFLAGS} ${${pkg_name}_CMAKE_CXXFLAGS}
          ${${pkg_name}_CL_RT_FLAG} ${${pkg_name}_CMAKE_LDFLAGS} -DCMAKE_INSTALL_PREFIX=${${pkg_name}_BASE_DIR}
          ${${pkg_name}_SOURCE_DIR}/${PKG_CMAKE_PATH}
        WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR}/_build)

      message(STATUS "Building CMake targets for ${pkg_name}")
      if(MSVC)
        __exec_cmd(COMMAND ${CMAKE_COMMAND} --build . --target install -j${JOBS} --config Debug
                   WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR}/_build)
        __exec_cmd(COMMAND ${CMAKE_COMMAND} --build . --target install -j${JOBS} --config Release
                   WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR}/_build)
      else()
        __exec_cmd(COMMAND ${CMAKE_COMMAND} --build . --target install -j${JOBS}
                   WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR}/_build)
      endif()
    else()
      set(PREFIX ${${pkg_name}_BASE_DIR})
      set(MAKE ${_make_exec})
      if(${pkg_name}_CFLAGS)
        set(${pkg_name}_MAKE_CFLAGS "CFLAGS=${${pkg_name}_CFLAGS}")
      endif()
      if(${pkg_name}_CXXFLAGS)
        set(${pkg_name}_MAKE_CXXFLAGS "CXXFLAGS=${${pkg_name}_CXXFLAGS}")
      endif()
      if(${pkg_name}_LDFLAGS)
        set(${pkg_name}_MAKE_LDFLAGS "LDFLAGS=${${pkg_name}_LDFLAGS}")
      endif()
      # in configure && make
      if(PKG_PRE_CONFIGURE_COMMAND)
        message(STATUS "Calling pre-configure script for ${pkg_name}")
        __exec_cmd(COMMAND ${PKG_PRE_CONFIGURE_COMMAND} WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR})
      endif()

      if(PKG_CONFIGURE_COMMAND)
        message(STATUS "Calling configure script for ${pkg_name}")
        __exec_cmd(
          COMMAND ${PKG_CONFIGURE_COMMAND} ${${pkg_name}_MAKE_CFLAGS} ${${pkg_name}_MAKE_CXXFLAGS}
                  ${${pkg_name}_MAKE_LDFLAGS} --prefix=${${pkg_name}_BASE_DIR}
          WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR})
      endif()
      string(CONFIGURE "${PKG_BUILD_OPTION}" PKG_BUILD_OPTION @ONLY ESCAPE_QUOTES)
      set(${pkg_name}_BUILD_OPTION ${PKG_BUILD_OPTION})
      if(NOT PKG_CONFIGURE_COMMAND)
        set(${pkg_name}_BUILD_OPTION ${${pkg_name}_BUILD_OPTION} ${${pkg_name}_MAKE_CFLAGS}
                                     ${${pkg_name}_MAKE_CXXFLAGS} ${${pkg_name}_MAKE_LDFLAGS})
      endif()

      if(PKG_BUILD_COMMAND)
        message(STATUS "Calling build command for ${pkg_name}")
        string(CONFIGURE "${PKG_BUILD_COMMAND}" PKG_BUILD_COMMAND @ONLY ESCAPE_QUOTES)
        __exec_cmd(COMMAND ${PKG_BUILD_COMMAND} -j${JOBS} WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR})
      elseif(NOT PKG_SKIP_BUILD_STEP)
        message(STATUS "Calling build command for ${pkg_name}")
        __exec_cmd(COMMAND ${_make_exec} ${${pkg_name}_BUILD_OPTION} -j${JOBS}
                   WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR})
      endif()

      if(PKG_INSTALL_INCS OR PKG_INSTALL_LIBS)
        file(GLOB ${pkg_name}_INSTALL_INCS ${${pkg_name}_SOURCE_DIR}/${PKG_INSTALL_INCS})
        file(GLOB ${pkg_name}_INSTALL_LIBS ${${pkg_name}_SOURCE_DIR}/${PKG_INSTALL_LIBS})
        file(COPY ${${pkg_name}_INSTALL_INCS} DESTINATION ${${pkg_name}_BASE_DIR}/include)
        file(COPY ${${pkg_name}_INSTALL_LIBS} DESTINATION ${${pkg_name}_BASE_DIR}/lib)
      elseif(NOT PKG_SKIP_INSTALL_STEP)
        message(STATUS "Calling install command for ${pkg_name}")
        if(PKG_INSTALL_COMMAND)
          string(CONFIGURE "${PKG_INSTALL_COMMAND}" PKG_INSTALL_COMMAND @ONLY ESCAPE_QUOTES)
          __exec_cmd(COMMAND ${PKG_INSTALL_COMMAND} WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR})
        else()
          __exec_cmd(COMMAND ${_make_exec} install WORKING_DIRECTORY ${${pkg_name}_SOURCE_DIR})
        endif()
      endif()
      unset(PREFIX)
      unset(MAKE)
    endif()
  endif()

  if(PKG_GEN_CMAKE_CONFIG AND NOT PKG_COPY_TO_BINARY_DIR)
    message(STATUS "Generating fake CMake config file...")

    list(PREPEND CMAKE_PREFIX_PATH "${${pkg_name}_BASE_DIR}")
    set(${PKG_NAME}_ROOT "${${pkg_name}_BASE_DIR}")
    set(${pkg_name}_ROOT "${${pkg_name}_BASE_DIR}")

    set(_comps ${PKG_LIBS})
    if(PKG_EXE)
      list(APPEND _comps ${PKG_EXE})
    endif()

    # Not using PkgConfig here so that we get the libraries type right (ie. SHARED or STATIC instead of INTERFACE)
    set(${pkg_name}_NO_PKGCONFIG ON)
    find_package(
      ${pkg_name} QUIET
      COMPONENTS ${_comps}
      REQUIRED)
    __generate_pseudo_cmake_package_config("${${pkg_name}_BASE_DIR}" ${pkg_name} ${PKG_NS_NAME} "${_comps}")
    list(POP_FRONT CMAKE_PREFIX_PATH)
  endif()

  __find_package(
    "${pkg_name}"
    "${PKG_VER}"
    "${_components}"
    "${PKG_CMAKE_PKG_NO_COMPONENTS}"
    "MindQuantum build dir"
    REQUIRED
    CONFIG
    ${MQ_FIND_NO_DEFAULT_PATH}
    HINTS
    "${${pkg_name}_BASE_DIR}")
  __check_package_location(${pkg_name} ${PKG_NS_NAME} ${PKG_LIBS} ${PKG_EXE})
  __make_target_global(${PKG_NS_NAME} ${PKG_LIBS} ${PKG_EXE})
  __create_target_aliases(${PKG_TARGET_ALIAS})

  list(POP_BACK CMAKE_MESSAGE_INDENT)
  message(CHECK_PASS "Done")
endfunction()

# ==============================================================================
