# ==============================================================================
#
# Copyright 2020 <Huawei Technologies Co., Ltd>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#
# ==============================================================================

# lint_cmake: -whitespace/indent

# NB: no -Wl, here, CMake automatically adds the correct prefix for the linker
if(LINKER_STRIP_ALL)
  test_linker_option(
    linker_flags
    LANGS C CXX DPCXX CUDA NVCXX
    FLAGS "--strip-all -s"
    GENEX "$<OR:$<CONFIG:RELEASE>,$<CONFIG:RELWITHDEBINFO>>")
endif()

test_linker_option(
  linker_flags
  LANGS C CXX DPCXX CUDA NVCXX
  FLAGS "-z,now")

# ------------------------------------------------------------------------------

if(LINKER_NOEXECSTACK)
  test_linker_option(
    link_no_execstack
    LANGS C CXX DPCXX CUDA NVCXX
    FLAGS "-z,noexecstack")
endif()

# ------------------------------------------------------------------------------

if(LINKER_RELRO)
  test_linker_option(
    link_relro
    LANGS C CXX DPCXX CUDA NVCXX
    FLAGS "-z,relro")
endif()

# ------------------------------------------------------------------------------

if(ENABLE_CUDA)
  # NB: simply copy over the compiler options to linker options since they are the same
  foreach(_src_target nvhpc_cuda_flags_NVCXX nvhpc_cuda_version_flags_NVCXX)
    get_target_property(_flag ${_src_target} INTERFACE_COMPILE_OPTIONS)
    foreach(_dst_target ${_src_target} NVCXX_mindquantum NVCXX_try_compile NVCXX_try_compile_flagcheck)
      target_link_options(${_dst_target} INTERFACE ${_flag})
    endforeach()
  endforeach()

  get_target_property(_flag nvhpc_gpu_compute_capability_NVCXX INTERFACE_COMPILE_OPTIONS)
  foreach(_dst_target nvhpc_gpu_compute_capability_NVCXX NVCXX_mindquantum)
    target_link_options(${_dst_target} INTERFACE ${_flag})
  endforeach()

  # NB: only copy one of the -gpu=ccXX flags for try_compile targets
  list(GET _flag 0 _flag)
  foreach(_dst_target NVCXX_try_compile NVCXX_try_compile_flagcheck)
    target_link_options(${_dst_target} INTERFACE ${_flag})
  endforeach()
endif()

# ------------------------------------------------------------------------------

if(ENABLE_STACK_PROTECTION)
  test_linker_option(
    stack_protection
    LANGS C CXX DPCXX
    FLAGS "-fstack-protector-all"
    VERBATIM)
endif()

# ------------------------------------------------------------------------------

if(ENABLE_RUNPATH)
  if(LINKER_DTAGS)
    test_linker_option(
      linker_dtags
      LANGS C CXX DPCXX CUDA NVCXX
      FLAGS "--enable-new-dtags")
  endif()
else()
  if(LINKER_DTAGS)
    test_linker_option(
      linker_dtags
      LANGS C CXX DPCXX CUDA NVCXX
      FLAGS "--disable-new-dtags")
  endif()

  if(CUDA_STATIC)
    test_linker_option(
      nvhpc_static_flags
      LANGS NVCXX
      FLAGS "-static-nvidia" "-Mnorpath"
      VERBATIM)
  endif()
endif()

if(UNIX AND NOT APPLE)
  if(NOT DEFINED _cmake_rpath_check)
    set(_cmake_rpath_check FALSE)
    find_program(_readelf readelf)
    if(_readelf)
      set(_cmake_rpath_check TRUE)
    else()
      message(STATUS "Readelf program not found -> skipping RPATH/RUNPATH check")
    endif()
    # cmake-lint: disable=C0103
    set(_cmake_rpath_check
        ${_cmake_rpath_check}
        CACHE BOOL "Do an extended CMake test to make sure no RPATH are set?")

    mark_as_advanced(_readelf _cmake_rpath_check)
  endif()
endif()

# ==============================================================================

if(_cmake_rpath_check)
  foreach(_lang C CXX CUDA NVCXX DPCXX)
    is_language_enabled(${_lang} _enabled)
    if(_enabled)
      message(CHECK_START "Performing extended CMake RPATH test for ${_lang}")
      list(APPEND CMAKE_MESSAGE_INDENT "  ")
      set(LANG ${_lang})
      set(LANGS ${_lang})

      if("${_lang}" STREQUAL "CUDA")
        set(LANGS "${LANGS} CXX")
      elseif("${_lang}" STREQUAL NVCXX)
        set(LANGS "${LANGS} CXX")
        get_property(_flags GLOBAL PROPERTY _nvcxx_try_compile_extra_flags)
        if(_flags)
          string(APPEND CMAKE_REQUIRED_FLAGS " ${_flags}")
          list(APPEND CMAKE_REQUIRED_LINK_OPTIONS ${_flags})
        endif()
        set(CMAKE_EXTRA_CONTENT "set(CMAKE_NVCXX_FLAGS_INIT \"${CMAKE_NVCXX_FLAGS_INIT} -v\")\n
set(CMAKE_NVCXX_LDFLAGS_INIT \"${CMAKE_NVCXX_LDFLAGS_INIT} -v\")")
      endif()

      file(REMOVE ${CMAKE_SOURCE_DIR}/tests/cmake-ldtest/CMakeLists.txt)
      configure_file(${CMAKE_SOURCE_DIR}/tests/cmake-ldtest/CMakeLists.txt.in
                     ${CMAKE_SOURCE_DIR}/tests/cmake-ldtest/CMakeLists.txt @ONLY)

      # ------------------------------------

      get_target_property(_linker_flags linker_dtags_${_lang} INTERFACE_LINK_OPTIONS)

      message(CHECK_START "Compiling test library (${_lang})")
      set(_binary_dir ${CMAKE_BINARY_DIR}/cmake-ldtest-${_lang})
      get_target_property(_linker_dtags linker_dtags_${_lang} INTERFACE_LINK_OPTIONS)
      try_compile(
        _create_shared_lib_${lang} ${_binary_dir}
        ${CMAKE_SOURCE_DIR}/tests/cmake-ldtest cmake-ldtest
        CMAKE_FLAGS -DCMAKE_VERBOSE_MAKEFILE=ON -DLINKER_FLAGS=${_linker_dtags}
        OUTPUT_VARIABLE _compile_output)
      if(_create_shared_lib_${lang})
        message(CHECK_PASS "succeeded")
      else()
        message(CHECK_FAIL "failed")
        file(APPEND ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeError.log
             "Failed to compile CMake RPATH extended ${_lang} test project.\nOutput of build:\n${_compile_output}\n")
      endif()

      # ------------------------------------

      if(_create_shared_lib_${lang})
        if(ENABLE_RUNPATH)
          set(_name "RPATH")
        else()
          set(_name "RUNPATH")
        endif()

        message(CHECK_START "Looking for absence of ${_name} (${_lang})")

        find_library(
          _shared_lib_${_lang}
          NAMES shared_lib_${_lang} libshared_lib_${_lang}
          PATHS ${_binary_dir} REQUIRED
          NO_DEFAULT_PATH)
        mark_as_advanced(_shared_lib_${_lang})

        execute_process(
          COMMAND ${_readelf} -Wd ${_shared_lib_${_lang}}
          OUTPUT_VARIABLE _dyn_symbols
          OUTPUT_STRIP_TRAILING_WHITESPACE)

        # Local helper macro to add RPATH to the log file
        macro(_rpath_add_to_log name success msg)
          if(${success})
            set(_file "CMakeOutput.log")
            set(_state_msg "succeeded")
          else()
            set(_file "CMakeError.log")
            set(_state_msg "failed")
          endif()
          file(
            APPEND
            ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${_file}
            "\n\nLooking for absence of ${name} in ${_shared_lib_${_lang}} ${_state_msg}.\n"
            "Output of build for ${_shared_lib_${_lang}}:\n${_compile_output}\nOutput of readelf -Wd:"
            "\n${_dyn_symbols}\n\n${msg}\n\n")
        endmacro()

        set(_test_result FALSE)
        if(ENABLE_RUNPATH AND ${_dyn_symbols} MATCHES ".*\\(RPATH\\)[ ]+([^\n\r\t]*)")
          # Most not have RPATH but found one -> not good
          _rpath_add_to_log(${_name} FALSE "RPATH detected: ${CMAKE_MATCH_1}")
        elseif(ENABLE_RUNPATH AND ${_dyn_symbols} MATCHES ".*\\(RUNPATH\\)[ ]+([^\n\r\t]*)")
          set(_test_result TRUE)
          _rpath_add_to_log(${_name} TRUE "Found RUNPATH: ${CMAKE_MATCH_1} and no RPATH")
          # --------------------------------
        elseif(NOT ENABLE_RUNPATH AND ${_dyn_symbols} MATCHES ".*\\(RUNPATH\\)[ ]+([^\n\r\t]*)")
          # Most not have RUNPATH but found one -> not good
          _rpath_add_to_log(${_name} FALSE "RUNPATH detected: ${CMAKE_MATCH_1}")
        elseif(NOT ENABLE_RUNPATH AND ${_dyn_symbols} MATCHES ".*\\(RPATH\\)[ ]+([^\n\r\t]*)")
          set(_test_result TRUE)
          _rpath_add_to_log(${_name} TRUE "Found RPATH: ${CMAKE_MATCH_1} and no RUNPATH")
          # --------------------------------
        else()
          _rpath_add_to_log(${_name} FALSE "No RPATH or RUNPATH found.")
          message(CHECK_FAIL "failed")
          message(FATAL_ERROR "No RPATH or RUNPATH found in ${_shared_lib}")
        endif()

        if(_test_result)
          message(CHECK_PASS "succeeded")
        else()
          message(CHECK_FAIL "failed")
        endif()
      endif()

      # ------------------------------------

      list(POP_BACK CMAKE_MESSAGE_INDENT)
      if(_test_result)
        message(CHECK_PASS "succeeded")
        # cmake-lint: disable=C0103

        # Only perform the RPATH/RUNPATH check once
        set(_cmake_rpath_check
            FALSE
            CACHE INTERNAL "")
      else()
        message(CHECK_FAIL "failed")
        message(FATAL_ERROR "Failed extended RPATH test: cannot continue!")
      endif()
    endif()
  endforeach()
endif()

# ==============================================================================
