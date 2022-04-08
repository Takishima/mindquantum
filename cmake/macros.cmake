# ==============================================================================
#
# Copyright 2020 <Huawei Technologies Co., Ltd>
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

# lint_cmake: -whitespace/indent

include(CheckCompilerFlag OPTIONAL RESULT_VARIABLE _check_compiler_flag)
if(NOT _check_compiler_flag)
  include(Internal/CMakeCheckCompilerFlag)
endif()

# Check if a language has been enabled without attempting to enable it
#
# is_language_enabled(<lang> <resultvar>)
#
# If the language <lang> has already been enabled, <resultvar> is set to TRUE. Otherwise it is set to FALSE.
function(is_language_enabled _lang _var)
  get_property(_supported_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
  if(NOT _lang IN_LIST _supported_languages)
    set(${_var}
        FALSE
        PARENT_SCOPE)
  else()
    set(${_var}
        TRUE
        PARENT_SCOPE)
  endif()
endfunction()

# ==============================================================================

# ~~~
# (helper function) Convert a path to CMake format
#
# to_cmake_path(<path-var>)
# ~~~
macro(to_cmake_path path_var)
  if(DEFINED ${path_var})
    if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.20)
      cmake_path(CONVERT "${${path_var}}" TO_CMAKE_PATH_LIST ${path_var} NORMALIZE)
    else()
      file(TO_CMAKE_PATH "${${path_var}}" ${path_var})
    endif()
  endif()
endmacro()

# ------------------------------------------------------------------------------

# ~~~
# (helper function) Compute the absolute path to an existing file or directory with symlinks resolved.
#
# real_path(<path> <out-var>)
# ~~~
function(real_path path var)
  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.19)
    file(REAL_PATH "${path}" _resolved_path)
  else()
    get_filename_component(_resolved_path "${path}" REALPATH)
  endif()

  set(${var}
      "${_resolved_path}"
      PARENT_SCOPE)
endfunction()

# ==============================================================================

# ~~~
# (helper function) Copy a property from a source target to a destination target if set
#
# _copy_target_property(<source> <destination> <property>)
# ~~~
function(_copy_target_property source destination property)
  get_property(
    _is_set
    TARGET ${source}
    PROPERTY ${property}
    SET)
  if(_is_set)
    get_target_property(_value ${source} ${property})
    set_target_properties(${destination} PROPERTIES ${property} "${_value}")
  endif()
endfunction()

# ------------------------------------------------------------------------------

# ~~~
# Create a copy of an existing target
#
# duplicate_target(<new_target> <original_target>)
#
# WARNING: not designed to work with aliased targets!
# ~~~
function(duplicate_target new_target original_target)
  get_target_property(_type ${original_target} TYPE)

  set(_lib_type)
  if("${_type}" STREQUAL "STATIC_LIBRARY")
    set(_lib_type STATIC)
  elseif("${_type}" STREQUAL "MODULE_LIBRARY")
    set(_lib_type MODULE)
  elseif("${_type}" STREQUAL "SHARED_LIBRARY")
    set(_lib_type SHARED)
  elseif("${_type}" STREQUAL "OBJECT_LIBRARY")
    set(_lib_type OBJECT)
  elseif("${_type}" STREQUAL "INTERFACE_LIBRARY")
    set(_lib_type INTERFACE)
  endif()

  get_target_property(_imported ${original_target} IMPORTED)
  if(_imported)
    get_target_property(_global ${original_target} IMPORTED_GLOBAL)
    if(_global)
      set(_args GLOBAL)
    endif()

    if("${_type}" STREQUAL "EXECUTABLE")
      add_executable(${new_target} IMPORTED ${_args})
    else()
      add_library(${new_target} ${_lib_type} IMPORTED ${_args})
    endif()
  else()
    if("${_type}" STREQUAL "EXECUTABLE")
      add_executable(${new_target})
    else()
      add_library(${new_target} ${_lib_type})
    endif()
  endif()

  foreach(
    _prop
    COMPILE_FLAGS
    C_COMPILER_LAUNCHER
    C_EXTENSIONS
    C_LINKER_LAUNCHER
    C_STANDARD
    C_STANDARD_REQUIRED
    C_VISIBILITY_PRESET
    CXX_COMPILER_LAUNCHER
    CXX_EXTENSIONS
    CXX_LINKER_LAUNCHER
    CXX_STANDARD
    CXX_STANDARD_REQUIRED
    CXX_VISIBILITY_PRESET
    EXCLUDE_FROM_ALL
    EXPORT_NAME
    IMPORTED_CONFIGURATIONS)
    _copy_target_property(${original_target} ${new_target} ${_prop})
  endforeach()

  foreach(
    _prop
    COMPILE_DEFINITIONS
    COMPILE_FEATURES
    COMPILE_OPTIONS
    INCLUDE_DIRECTORIES
    LINK_DEPENDS
    LINK_LIBRARIES
    LINK_OPTIONS
    POSITION_INDEPENDENT_CODE
    PRECOMPILE_HEADERS
    SOURCES)
    _copy_target_property(${original_target} ${new_target} ${_prop})
    _copy_target_property(${original_target} ${new_target} INTERFACE_${_prop})
  endforeach()
  _copy_target_property(${original_target} ${new_target} INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)

  foreach(
    _prop
    COMPILE_PDB_NAME
    EXCLUDE_FROM_DEFAULT_BUILD
    IMPORTED_IMPLIB
    IMPORTED_LIBNAME
    IMPORTED_LINK_DEPENDENT_LIBRARIES
    IMPORTED_LINK_INTERFACE_LANGUAGES
    IMPORTED_LINK_INTERFACE_MULTIPLICITY
    IMPORTED_LOCATION
    IMPORTED_NO_SONAME
    IMPORTED_OBJECTS
    IMPORTED_SONAME
    INTERPROCEDURAL_OPTIMIZATION
    LINK_FLAGS
    LINK_INTERFACE_LIBRARIES
    LINK_INTERFACE_MULTIPLICITY
    PDB_NAME
    PDB_OUTPUT_DIRECTORY
    RUNTIME_OUTPUT_DIRECTORY
    RUNTIME_OUTPUT_NAME
    STATIC_LIBRARY_FLAGS)
    _copy_target_property(${original_target} ${new_target} ${_prop})

    foreach(_config DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
      _copy_target_property(${original_target} ${new_target} ${_prop}_${_config})
    endforeach()

  endforeach()
  foreach(_prop OUTPUT_NAME POSTFIX)
    foreach(_config DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
      _copy_target_property(${original_target} ${new_target} ${_config}_${prop})
    endforeach()
  endforeach()
endfunction()

# ==============================================================================

# ~~~
# Apply a list of patches by calling `patch -p1 <patch-file>`
#
# apply_patches(<working_directory> [<patch-file> [... <patch-file>]])
# ~~~
function(apply_patches working_directory)
  set(_execute_patch_args)
  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.18)
    list(APPEND _execute_patch_args ECHO_OUTPUT_VARIABLE ECHO_ERROR_VARIABLE)
  endif()

  foreach(_patch_file ${ARGN})
    # NB: All these shenanigans with file(CONFIGURE ...) are just to make sure that we get a file with LF line
    # endings...
    get_filename_component(_patch_file_name ${_patch_file} NAME)
    set(_lf_patch_file ${CMAKE_BINARY_DIR}/_mq_patch/${_patch_file_name})
    file(READ "${_patch_file}" _content)
    # NB: escape patches that have @XXX@ since those would be replaced by the call to file(CONFIGURE)
    set(_at @)
    string(REGEX REPLACE [[\@([a-zA-Z_]+)\@]] [[@_at@\1@_at@]] _content "${_content}")
    if(CMAKE_VERSION VERSION_LESS 3.20)
      set(_less <)
      set(_greater >)
      # NB: some of the patches contain email addresses <name.surname@email.com>
      string(REGEX REPLACE [[<([a-zA-Z0-9\.]+)\@([a-zA-Z0-9\.]+)>]] [[@_less@\1@_at@\2@_greater@]] _content
                           "${_content}")
      string(REPLACE "<" "@_less@" _content "${_content}")
      string(REPLACE ">" "@_greater@" _content "${_content}")
    endif()
    set(NEWLINE_STYLE LF)
    if(PATCH_USE_NATIVE_ENCODING AND WIN32)
      set(NEWLINE_STYLE CRLF)
    endif()

    file(
      CONFIGURE
      OUTPUT "${_lf_patch_file}"
      CONTENT "${_content}"
      @ONLY
      NEWLINE_STYLE ${NEWLINE_STYLE})

    file(MD5 "${_lf_patch_file}" _md5)
    set(_patch_lock_file "${working_directory}/mq_applied_patch_${_md5}")

    if(NOT EXISTS "${_patch_lock_file}")
      message(STATUS "Applying patch ${_patch_file}")
      execute_process(
        COMMAND "${Patch_EXECUTABLE}" -p1
        INPUT_FILE "${_lf_patch_file}"
        WORKING_DIRECTORY "${working_directory}"
        RESULT_VARIABLE _result ${_execute_patch_args})
      if(NOT _result EQUAL "0")
        message(FATAL_ERROR "Failed patch: ${_lf_patch_file}")
      endif()
      file(TOUCH ${_patch_lock_file})
    else()
      message(STATUS "Skipping patch ${_patch_file} since already applied.")
    endif()
  endforeach()

endfunction()

# ==============================================================================

# ~~~
# Convenience function to test for the existence of some compiler flags for a a particular language
#
# check_compiler_flag(<lang> <var_prefix> [FLAGCHECK] [TRY_COMPILE_TARGET <target>] <flags1> [<flags2>...])
#
# Check whether a compiler option is valid for the <lang> compiler. For each set of compiler options provided in the
# lists <flagsN>, it will test whether one of the element can be used by the corresponding compiler. If a flag is valid,
# it will be added to the GLOBAL property named <prefix>_<lang> as well as to a variable with the same name. If the
# property already exists, any valid flag is appended to the current value.
#
# If FLAGCHECK is specified, call the compiler directly using execute_process() instead of using
# cmake_check_compiler_flag() as we expect that no output file will be produced.

# Each call to this function also sets the _added_count variable to the number of flags added automatically (if any).
# ~~~
function(check_compiler_flags lang var_prefix)
  cmake_parse_arguments(PARSE_ARGV 2 CCF "FLAGCHECK" "TRY_COMPILE_TARGET" "")

  # cmake-lint: disable=C0103,E1120
  set(_${lang}_opts)

  if(CCF_TRY_COMPILE_TARGET AND TARGET ${lang}_try_compile)
    get_target_property(_flags ${CCF_TRY_COMPILE_TARGET} INTERFACE_COMPILE_OPTIONS)
  endif()

  foreach(_flag_list ${CCF_UNPARSED_ARGUMENTS})
    separate_arguments(_flag_list)

    foreach(_flag ${_flag_list})
      # Drop the first character (most likely either '-' or '/')
      string(SUBSTRING ${_flag} 1 -1 _flag_name)
      string(REGEX REPLACE "^-+" "" _flag_name ${_flag_name})
      string(REGEX REPLACE "[-:/,=]" "_" _flag_name ${_flag_name})

      if(NOT CCF_FLAGCHECK)
        set(CMAKE_REQUIRED_FLAGS ${_flags})
        cmake_check_compiler_flag(${lang} ${_flag} ${lang}_compiler_has_${_flag_name})
      else()
        set(_var ${lang}_compiler_has_${_flag_name})
        set(_lang_textual NVHPC-C++)

        if(NOT DEFINED "${_var}")
          message(CHECK_START "Performing Test ${_var}")
          set(_cmd ${CMAKE_${lang}_COMPILER} ${_flag} ${_flags})
          execute_process(
            COMMAND ${_cmd}
            RESULT_VARIABLE _result
            OUTPUT_VARIABLE _output
            ERROR_VARIABLE _error)

          if(_result EQUAL 0)
            set(${_var}
                1
                CACHE INTERNAL "Test ${_var}")
            message(CHECK_PASS "Success")
            file(APPEND ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeOutput.log
                 "Performing ${_lang_textual} FLAG CHECK Test ${_var} with the following command line:\n${_cmd}\n"
                 "has succeeded\n\n")
          else()
            message(CHECK_FAIL "Failed")
            set(${_var}
                ""
                CACHE INTERNAL "Test ${_var}")
            file(
              APPEND
              ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeError.log
              "Performing ${_lang_textual} FLAG CHECK Test ${_var} with the following command line:\n${_cmd}\n"
              "has failed with the following output:\n"
              "${_output}\n"
              "And the following error output:\n"
              "${_error}\n\n")
          endif()
        endif()
      endif()

      if(${lang}_compiler_has_${_flag_name})
        list(APPEND _${lang}_opts ${_flag})
        break()
      endif()
    endforeach()
  endforeach()

  # Is there a property that already corresponds to this?
  get_property(_opts GLOBAL PROPERTY ${var_prefix}_${lang})
  if(_opts)
    list(APPEND _opts ${_${lang}_opts})
  else()
    define_property(
      GLOBAL
      PROPERTY ${var_prefix}_${lang}
      BRIEF_DOCS "Compiler flags for ${var_prefix}"
      FULL_DOCS "Compiler flags for ${var_prefix}")
    set(_opts ${_${lang}_opts})
  endif()

  # Set GLOBAL property so that other parts of the code can have access to it
  set_property(GLOBAL PROPERTY ${var_prefix}_${lang} ${_opts})

  list(LENGTH _${lang}_opts _added_count)
  set(_added_count
      ${_added_count}
      PARENT_SCOPE)
  set(_added_flags
      ${_${lang}_opts}
      PARENT_SCOPE)

  # Also set a variable for convenience
  set(${var_prefix}_${lang}
      ${_opts}
      PARENT_SCOPE)
endfunction()

# ~~~
# Convenience function to test for the existence of some compiler flags for a set of languages.
#
# test_compile_option(<prefix>
#                     LANGS <lang1> [<lang2>...]
#                     FLAGS <flags1> [<flags2>...]
#                     [AUTO_ADD_CO, FLAGCHECK]
#                     [GENEX <genex>]
#                     [TRY_COMPILE_TARGET <target>]
#                     [TARGETS <target1> [<target2>...]])
#
# Check that a compiler option can be applied to each of the specified languages <lang>. For each set of compiler
# options provided in the lists <flagsN>, it will test whether one of the element can be used by the corresponding
# compiler. If a flag is valid, it will be added to the GLOBAL property named <prefix>_<lang> as well as to a variable
# with the same name.
# If AUTO_ADD_CO is specified, the compiler option will be automatically added globally using
# add_compile_option(...). By default, the generator expression used in that function call restricts the compile option
# to the current language (ie. $<$<COMPILE_LANGUAGE:@lang@>:${_flag}>). This can be changed by using the <genex>
# argument (which defaults to "$<COMPILE_LANGUAGE:@lang@>").
#
# NB: This function calls check_compiler_flags() internally.
#
# ~~~
function(test_compile_option prefix)
  # cmake-lint: disable=R0912,R0915,C0103
  cmake_parse_arguments(PARSE_ARGV 1 TEST_CO "AUTO_ADD_CO;FLAGCHECK" "GENEX;TRY_COMPILE_TARGET" "LANGS;FLAGS;TARGETS")

  if(NOT TEST_CO_LANGS)
    message(FATAL_ERROR "Missing LANGS argument")
  endif()
  if(NOT TEST_CO_FLAGS)
    message(FATAL_ERROR "Missing FLAGS argument")
  endif()

  set(_mode_no_target 1)
  set(_mode_target 2)

  set(_mode ${_mode_no_target})

  if(TEST_CO_TARGETS)
    set(_mode ${_mode_target})
  endif()

  set(_ccf_args)
  if(TEST_CO_FLAGCHECK)
    list(APPEND _ccf_args FLAGCHECK)
  endif()
  if(TEST_CO_TRY_COMPILE_TARGET)
    list(APPEND _ccf_args TRY_COMPILE_TARGET ${TEST_CO_TRY_COMPILE_TARGET})
  endif()

  if(_mode EQUAL _mode_target)
    if(TEST_CO_GENEX OR TEST_CO_AUTO_ADD_CO)
      message(FATAL_ERROR "Cannot specify GENEX or AUTO_ADD_CO if TARGETS is specified!")
    endif()

    foreach(lang ${TEST_CO_LANGS})
      is_language_enabled(${lang} _enabled)
      if(_enabled)
        check_compiler_flags(${lang} ${prefix} ${_ccf_args} ${TEST_CO_FLAGS})

        set(${prefix}_${lang}
            ${${prefix}_${lang}}
            PARENT_SCOPE)

        if(_added_count)
          list(LENGTH ${prefix}_${lang} _L)
          math(EXPR _start_idx "${_L} - ${_added_count}")
          list(SUBLIST ${prefix}_${lang} ${_start_idx} -1 _added_flags)
          foreach(_target ${TEST_CO_TARGETS})
            target_compile_options(${_target} INTERFACE ${_added_flags})
          endforeach()
        endif()
      else()
        set(${prefix}_${lang} PARENT_SCOPE)
      endif()
    endforeach()
  elseif(_mode EQUAL _mode_no_target)
    if(NOT TEST_CO_GENEX)
      set(TEST_CO_GENEX "$<COMPILE_LANGUAGE:@lang@>")
    endif()
    # cmake-lint: disable=C0103
    foreach(lang ${TEST_CO_LANGS})
      is_language_enabled(${lang} _enabled)
      if(_enabled)
        check_compiler_flags(${lang} ${prefix} ${_ccf_args} ${TEST_CO_FLAGS})

        set(${prefix}_${lang}
            ${${prefix}_${lang}}
            PARENT_SCOPE)

        if(TEST_CO_AUTO_ADD_CO AND _added_flags)
          string(CONFIGURE "${TEST_CO_GENEX}" _genex @ONLY)
          list(LENGTH ${prefix}_${lang} _L)
          math(EXPR _start_idx "${_L} - ${_added_count}")
          list(SUBLIST ${prefix}_${lang} ${_start_idx} -1 _added_flags)
          foreach(_flag ${_added_flags})
            add_compile_options("$<${_genex}:${_flag}>")
          endforeach()
        endif()
      else()
        set(${prefix}_${lang} PARENT_SCOPE)
      endif()
    endforeach()
  endif()
endfunction()

# ==============================================================================

# ~~~
# Convenience function to test for the existence of some compiler flags for a a particular language
#
# check_link_flag(<lang> <var_prefix> [VERBATIM] <flags1> [<flags2>...])
#
# Check whether a linker option is valid for the <lang> linker. For each set of linker options provided in the lists
# <flagsN>, it will test whether one of the element can be used by the corresponding compiler. If a flag is valid, it
# will be added to the GLOBAL property named <prefix>_<lang> as well as to a variable with the same name. If the
# property already exists, any valid flag is appended to the current value.
#
# If VERBATIM is passed as argument, the flag is passed onto the linker without prepending the 'LINKER:' prefix.
#
# Each call to this function also sets the _added_count variable to the number of flags added automatically (if any).
# ~~~
function(check_link_flags lang var_prefix)
  # cmake-lint: disable=R0915,C0103,E1120

  cmake_parse_arguments(PARSE_ARGV 2 CHECK_LF "VERBATIM" "" "")
  set(_${lang}_link_opts)
  # This is a CMake 3.18 addition
  include(CheckLinkerFlag OPTIONAL RESULT_VARIABLE _check_linker_flags)

  set(_wrapper_flag ${CMAKE_${lang}_LINKER_WRAPPER_FLAG})
  list(GET _wrapper_flag -1 _last)
  set(_separate_options FALSE)
  if("${_last}" STREQUAL " ")
    set(_separate_options TRUE)
    list(REMOVE_AT _wrapper_flag -1)
  endif()
  string(REPLACE ";" " " _wrapper_flag "${_wrapper_flag}")

  foreach(_flag_list ${CHECK_LF_UNPARSED_ARGUMENTS})
    separate_arguments(_flag_list)

    foreach(_flag ${_flag_list})
      # Drop the first character (most likely either '-' or '/')
      string(SUBSTRING ${_flag} 1 -1 _flag_name)
      string(REGEX REPLACE "^-+" "" _flag_name ${_flag_name})
      string(REGEX REPLACE "[-:/,=]" "_" _flag_name ${_flag_name})
      if(CHECK_LF_VERBATIM)
        set(_prefix)
      else()
        set(_prefix "LINKER:")
      endif()

      if(_check_linker_flags)
        check_linker_flag(${lang} "${_prefix}${_flag}" ${lang}_linker_has_${_flag_name})
      else()
        if(NOT CHECK_LF_VERBATIM)
          if(_separate_options)
            string(REPLACE "," ";" _flags ${_flag})
            set(_expanded_flag)
            foreach(subflag ${_flags})
              set(_expanded_flag "${_expanded_flag} ${_wrapper_flag} ${subflag}")
            endforeach()
          else()
            set(_expanded_flag "${_wrapper_flag}${_flag}")
          endif()
        else()
          set(_expanded_flag "${_flag}")
        endif()

        set(CMAKE_REQUIRED_LINK_OPTIONS ${_expanded_flag})
        check_compiler_flag(${lang} "" ${lang}_linker_has_${_flag_name})
      endif()

      if(${lang}_linker_has_${_flag_name})
        list(APPEND _${lang}_link_opts ${_flag})
        break()
      endif()
    endforeach()
  endforeach()

  # Is there a property that already corresponds to this?
  get_property(_opts GLOBAL PROPERTY ${var_prefix}_${lang})
  if(_opts)
    list(APPEND _opts ${_${lang}_link_opts})
  else()
    define_property(
      GLOBAL
      PROPERTY ${var_prefix}_${lang}
      BRIEF_DOCS "Linker flags ${var_prefix}"
      FULL_DOCS "Linker flags ${var_prefix}")
    set(_opts ${_${lang}_link_opts})
  endif()

  # Set GLOBAL property so that other parts of the code can have access to it
  set_property(GLOBAL PROPERTY ${var_prefix}_${lang} ${_opts})

  list(LENGTH _${lang}_link_opts _added_count)
  set(_added_count
      ${_added_count}
      PARENT_SCOPE)
  set(_added_flags
      ${_${lang}_link_opts}
      PARENT_SCOPE)

  # Also set a variable for convenience
  set(${var_prefix}_${lang}
      ${_opts}
      PARENT_SCOPE)
endfunction()

# ~~~
# Convenience function to test for the existence of some linker flags for a set of languages.
#
# test_link_option(<prefix>
#                  LANGS <lang1> [<lang2>...]
#                  FLAGS <flags1> [<flags2>...]
#                  [AUTO_ADD_LO]
#                  [VERBATIM]
#                  [GENEX <genex>])
#
# Check that a linker option can be applied to each of the specified languages <lang>. For each set of linker
# options provided in the lists <flagsN>, it will test whether one of the element can be used by the corresponding
# linker. If a flag is valid, it will be added to the GLOBAL property named <prefix>_<lang> as well as to a variable
# with the same name.
# If VERBATIM is passed as argument, the flag is passed onto the linker without prepending the 'LINKER:' prefix.
# If AUTO_ADD_LO is specified, the linker option will be automatically added globally using
# add_compile_option(...). By default, the generator expression used in that function call restricts the compile option
# to the current language (ie. $<$<LINK_LANGUAGE:@lang@>:LINKER:${_flag}>). This can be changed by using the <genex>
# argument (which defaults to "$<LINK_LANGUAGE:@lang@>").
#
# NB: This function calls check_link_flags() internally.
# ~~~
function(test_link_option prefix)
  cmake_parse_arguments(PARSE_ARGV 1 TEST_LO "AUTO_ADD_LO;VERBATIM" "GENEX" "LANGS;FLAGS")

  if(NOT TEST_LO_LANGS)
    message(FATAL_ERROR "Missing LANGS argument")
  endif()
  if(NOT TEST_LO_FLAGS)
    message(FATAL_ERROR "Missing FLAGS argument")
  endif()

  if(NOT TEST_LO_GENEX)
    if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.18)
      set(TEST_LO_GENEX "$<LINK_LANGUAGE:@lang@>")
    else()
      set(TEST_LO_GENEX "1")
    endif()
  endif()

  # cmake-lint: disable=C0103
  foreach(lang ${TEST_LO_LANGS})
    is_language_enabled(${lang} _enabled)
    if(_enabled)
      set(_args ${TEST_LO_FLAGS})
      if(TEST_LO_VERBATIM)
        set(_args "VERBATIM;${_args}")
      endif()
      check_link_flags(${lang} ${prefix} ${_args})

      set(${prefix}_${lang}
          ${${prefix}_${lang}}
          PARENT_SCOPE)

      if(TEST_LO_AUTO_ADD_LO AND _added_flags)
        string(CONFIGURE "${TEST_LO_GENEX}" _genex @ONLY)
        list(LENGTH ${prefix}_${lang} _L)
        math(EXPR _start_idx "${_L} - ${_added_count}")
        list(SUBLIST ${prefix}_${lang} ${_start_idx} -1 _added_flags)
        foreach(_flag ${_added_flags})
          if(TEST_LO_VERBATIM)
            add_link_options("$<${_genex}:${_flag}>")
          else()
            add_link_options("$<${_genex}:LINKER:${_flag}>")
          endif()
        endforeach()
      endif()
    else()
      set(${prefix}_${lang} PARENT_SCOPE)
    endif()
  endforeach()
endfunction()

# ==============================================================================

# ~~~
# Append a value to a property (creating the latter if necessary)
#
# append_to_property(<property_name>
#                    <GLOBAL             |
#                     DIRECTORY [<dir>]  |
#                     TARGET    <target> |
#                     SOURCE    <source> |
#                               [DIRECTORY <dir> | TARGET_DIRECTORY <target>] |
#                     INSTALL   <file>   |
#                     TEST      <test>   |
#                     CACHE     <entry>  |
#                     VARIABLE           >
#                    <value>)
# ~~~
macro(append_to_property name scope value)
  get_property(_prop ${scope} PROPERTY ${name})
  if(_prop)
    list(APPEND _prop ${value})
  else()
    define_property(
      ${scope}
      PROPERTY ${name}
      BRIEF_DOCS "${scope} property for ${name}"
      FULL_DOCS "${scope} property for ${name}")
    set(_prop ${value})
  endif()

  set_property(${scope} PROPERTY ${name} ${_prop})
endmacro()

# ==============================================================================

# Automatically set the output directory for a particular target with a potential hint
#
# set_output_directory_auto(<target> <hint>)
#
# Automatically set the output directory for <target>. <hint> must be an existing path in the current CMake project
# directory. It is only used if the CMake variable IN_PLACE_BUILD is set to a truthful value. Otherwise, the macro will
# look at ${target}_OUTPUT_DIR CMake variable (if it exists) to set the output directory (it will create the directory
# if it does not already exist on the filesystem).
#
macro(set_output_directory_auto target hint)
  string(TOUPPER ${target} _TARGET)

  if(IN_PLACE_BUILD)
    # Automatically calculate the output directory
    set(${_TARGET}_OUTPUT_DIR ${CMAKE_SOURCE_DIR}/${hint})
  endif()

  # Normalize variable name
  if(${target}_OUTPUT_DIR)
    set(${_TARGET}_OUTPUT_DIR ${${target}_OUTPUT_DIR})
  endif()

  # Create output directory if it does not exist already
  if(${_TARGET}_OUTPUT_DIR AND NOT EXISTS ${${_TARGET}_OUTPUT_DIR})
    file(MAKE_DIRECTORY ${${_TARGET}_OUTPUT_DIR})
  endif()

  # Properly set output directory for a target so that during an installation using either 'pip install' or 'python3
  # setup.py install' the libraries get built in the proper directory
  if(${_TARGET}_OUTPUT_DIR)
    set_target_properties(
      ${target}
      PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${${_TARGET}_OUTPUT_DIR}
                 LIBRARY_OUTPUT_DIRECTORY_DEBUG ${${_TARGET}_OUTPUT_DIR}
                 LIBRARY_OUTPUT_DIRECTORY_RELEASE ${${_TARGET}_OUTPUT_DIR}
                 LIBRARY_OUTPUT_DIRECTORY_RELWITHDEBINFO ${${_TARGET}_OUTPUT_DIR}
                 LIBRARY_OUTPUT_DIRECTORY_MINSIZEREL ${${_TARGET}_OUTPUT_DIR})
  elseif(IS_PYTHON_BUILD)
    message(
      WARNING "IS_PYTHON_BUILD=ON but ${_TARGET}_OUTPUT_DIR "
              "was not defined! The shared library for target ${target} "
              "will probably not be copied to the correct directory. "
              "Did you forget to add a CMakeExtension in setup.py?")
  elseif(CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    set_target_properties(
      ${target}
      PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
                 LIBRARY_OUTPUT_DIRECTORY_DEBUG ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
                 LIBRARY_OUTPUT_DIRECTORY_RELEASE ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
                 LIBRARY_OUTPUT_DIRECTORY_RELWITHDEBINFO ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
                 LIBRARY_OUTPUT_DIRECTORY_MINSIZEREL ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
  endif()
endmacro()

# ==============================================================================

# Set RPATH of target only if building for Python (ie. IS_PYTHON_BUILD=ON) or if building in-place (IN_PLACE_BUILD=ON)
macro(python_install_set_rpath target path)
  if((IS_PYTHON_BUILD OR IN_PLACE_BUILD) AND LINKER_RPATH)
    if(APPLE)
      set_target_properties(${target} PROPERTIES INSTALL_RPATH "@loader_path/${path}")
    elseif(UNIX)
      set_target_properties(${target} PROPERTIES INSTALL_RPATH "$ORIGIN/${path}")
    endif()
  endif()
endmacro()

# ==============================================================================

include(FindPackageHandleStandardArgs)
# Find a Python module in the current (potential virtual) environment
#
# find_python_module(<module> [REQUIRED|EXACT|QUIET] [VERSION <version>])
#
# Usage is similar to the builtin find_package(...)
function(find_python_module module)
  # cmake-lint: disable=C0103
  cmake_parse_arguments(PARSE_ARGV 1 PYMOD "REQUIRED;EXACT;QUIET" "VERSION" "")

  string(REPLACE "-" "_" module_name ${module})
  string(TOUPPER ${module_name} MODULE)
  if(NOT PYMOD_${MODULE})
    if(PYMOD_REQUIRED)
      set(PYMOD_${module}_FIND_REQUIRED TRUE)
      set(PYMOD_${MODULE}_FIND_REQUIRED TRUE)
    endif()
    if(PYMOD_QUIET)
      set(PYMOD_${module}_FIND_QUIETLY TRUE)
      set(PYMOD_${MODULE}_FIND_QUIETLY TRUE)
    endif()
    if(PYMOD_EXACT)
      set(PYMOD_${module}_FIND_VERSION_EXACT TRUE)
      set(PYMOD_${MODULE}_FIND_VERSION_EXACT TRUE)
    endif()
    if(PYMOD_VERSION)
      set(PYMOD_${module}_FIND_VERSION ${PYMOD_VERSION})
      set(PYMOD_${MODULE}_FIND_VERSION ${PYMOD_VERSION})
    endif()

    execute_process(
      COMMAND "${Python_EXECUTABLE}" "-c" "import os, ${module_name}; print(os.path.dirname(${module_name}.__file__))"
      RESULT_VARIABLE _${MODULE}_status
      OUTPUT_VARIABLE _${MODULE}_location
      ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

    if(NOT _${MODULE}_status)
      set(PYMOD_${MODULE}_PATH
          ${_${MODULE}_location}
          CACHE STRING "Location of Python module ${module}")

      if(PYMOD_VERSION)
        execute_process(
          COMMAND "${Python_EXECUTABLE}" "-c" "import ${module_name}; print(${module_name}.__version__)"
          RESULT_VARIABLE _${MODULE}_status
          OUTPUT_VARIABLE _${MODULE}_version
          ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

        if(NOT _${MODULE}_status)
          set(PYMOD_${MODULE}_VERSION
              ${_${MODULE}_version}
              CACHE STRING "Version of Python module ${module}")
          set(PYMOD_${module}_VERSION
              ${PYMOD_${MODULE}_VERSION}
              CACHE STRING "Version of Python module ${module}")
        endif()
      endif()
    endif()
  endif()

  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.19 AND CMAKE_VERSION VERSION_LESS 3.20)
    set(CMAKE_FIND_PACKAGE_NAME PYMOD_${module})
  endif()

  # NB: NAME_MISMATCHED is a CMake 3.17 addition
  find_package_handle_standard_args(
    PYMOD_${module_name}
    REQUIRED_VARS PYMOD_${MODULE}_PATH
    VERSION_VAR PYMOD_${MODULE}_VERSION NAME_MISMATCHED)

  set(PYMOD_${MODULE}_FOUND
      ${PYMOD_${MODULE}_FOUND}
      CACHE INTERNAL "")

  mark_as_advanced(PYMOD_${MODULE}_FOUND PYMOD_${MODULE}_PATH PYMOD_${MODULE}_VERSION)
endfunction()

# ==============================================================================
