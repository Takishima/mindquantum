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

# OpenMP

set(PARALLEL_LIBS)
if(ENABLE_OPENMP)
  if(APPLE)
    find_program(BREW_CMD brew PATHS /usr/local/bin)
    if(BREW_CMD)
      # Homebrew installs libomp in ${LLVM_PREFIX}/lib and the headers in /usr/local/include
      execute_process(COMMAND ${BREW_CMD} --prefix llvm OUTPUT_VARIABLE LLVM_PREFIX)
      string(STRIP ${LLVM_PREFIX} LLVM_PREFIX)
      list(APPEND CMAKE_LIBRARY_PATH ${LLVM_PREFIX}/lib)
    else()
      # MacPorts install libomp in /opt/local/lib/libomp and the headers in /opt/local/include/libomp
      find_library(
        LIBOMP_LIB omp gomp libomp
        HINTS /opt/local/lib
        PATH_SUFFIXES libomp
        NO_DEFAULT_PATH)
      fin_path(
        LIBOMP_INC
        omp.h
        HINTS
        /opt/local/include
        PATH_SUFFIXES
        libomp
        NO_DEFAULT_PATH)
      if(LIBOMP_LIB AND LIBOMP_INC)
        get_filename_component(LIBOMP_DIR ${LIBOMP_LIB} DIRECTORY)
        list(APPEND CMAKE_LIBRARY_PATH ${LIBOMP_DIR})
        list(APPEND CMAKE_INCLUDE_PATH ${LIBOMP_INC})
      endif()
    endif()
  endif()

  # ----------------------------------------------------------------------------

  if(APPLE)
    list(PREPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/Modules/apple)
  endif()
  find_package(OpenMP)
  if(OpenMP_FOUND)
    list(APPEND PARALLEL_LIBS OpenMP::OpenMP_CXX)
  endif()
endif()

if(USE_PARALLEL_STL)
  find_package(TBB REQUIRED tbb)
  target_compile_options(TBB::tbb INTERFACE "$<$<COMPILE_LANGUAGE:DPCXX>:-tbb>")
  list(APPEND PARALLEL_LIBS TBB::tbb)
endif()

# ==============================================================================

find_package(Threads REQUIRED)
list(APPEND PARALLEL_LIBS Threads::Threads)

find_package(Patch REQUIRED)

# ==============================================================================

# Only helps set the Python executable for CMake >= 3.16
if(DEFINED PYTHON_EXECUTABLE)
  set(Python_EXECUTABLE ${PYTHON_EXECUTABLE}) # cmake-lint: disable=C0103
endif()

set(_python_find_args Python 3.6.0 COMPONENTS Interpreter)
if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.18)
  list(APPEND _python_find_args Development.Module)
else()
  list(APPEND _python_find_args Development)
endif()
find_package(${_python_find_args})

# NB: This should be removed for CMake >= 3.16
if(NOT Python_FOUND)
  # Use PYTHON_EXECUTABLE if it is defined, otherwise default to python
  if(PYTHON_EXECUTABLE)
    set(Python_EXECUTABLE ${PYTHON_EXECUTABLE}) # cmake-lint: disable=C0103
  elseif(NOT Python_EXECUTABLE)
    find_program(Python_EXECUTABLE NAMES python3 python)
    if(NOT Python_EXECUTABLE)
      message(FATAL_ERROR "Unable to locate Python!")
    endif()
  endif()

  execute_process(
    COMMAND "${Python_EXECUTABLE}" --version
    RESULT_VARIABLE result
    OUTPUT_VARIABLE _python_version)
  string(STRIP "${_python_version}" Python_VERSION)

  if(Python_VERSION VERSION_LESS 3.6.0)
    message(FATAL_ERROR "Cannot use Python ${Python_VERSION} (${Python_EXECUTABLE}): version too old!")
  endif()

  execute_process(
    COMMAND "${Python_EXECUTABLE}" -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE _python_inc)
  string(STRIP "${_python_inc}" _python_inc)

  execute_process(
    COMMAND "${Python_EXECUTABLE}" -c "import distutils.sysconfig as sysconfig; import os; \
                  print(os.path.join(sysconfig.get_config_var('LIBDIR'), sysconfig.get_config_var('LDLIBRARY')))"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE _python_lib)
  string(STRIP "${_python_lib}" _python_lib)

  # Define an imported library for Python
  macro(_python_import_library lib_name)
    if(lib MATCHES "${CMAKE_SHARED_LIBRARY_SUFFIX}$")
      set(_type SHARED)
    else()
      set(_type STATIC)
    endif()

    add_library(${lib_name} ${_type} IMPORTED)
    target_include_directories(${lib_name} INTERFACE "${_python_inc}")
    # cmake-lint: disable=C0307
    set_target_properties(${lib_name} PROPERTIES IMPORTED_LINK_INTERFACE_LANGUAGES "C" IMPORTED_LOCATION
                                                                                       "${_python_lib}")
  endmacro()

  _python_import_library(Python::Python)
  if(WIN32
     OR CYGWIN
     OR MSYS)
    # On Windows/Cygwin/MSYS Python::Module is an alias for Python::Python. See CMake code for FindPython.
    _python_import_library(Python::Module)
  else()
    if(NOT TARGET Python::Module)
      add_library(Python::Module INTERFACE IMPORTED)
    endif()
    target_include_directories(Python::Module INTERFACE "${_python_inc}")
    target_link_options(Python::Module INTERFACE $<$<PLATFORM_ID:Darwin>:LINKER:-undefined,dynamic_lookup>
                        $<$<PLATFORM_ID:SunOS>:LINKER:-z,nodefs> $<$<PLATFORM_ID:AIX>:LINKER:-b,erok>)
  endif()
endif()

if(CMAKE_VERSION VERSION_LESS 3.17)
  message(CHECK_START "Looking for python SOABI")

  execute_process(
    COMMAND "${Python_EXECUTABLE}" "-c" "from sysconfig import get_config_var; \
print(get_config_var ('EXT_SUFFIX') or s.get_config_var ('SO'))"
    RESULT_VARIABLE _soabi_success
    OUTPUT_VARIABLE _python_so_extension
    ERROR_VARIABLE _soabi_error_value
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  if(NOT _soabi_success MATCHES 0)
    message(CHECK_FAIL "failed")
    message(FATAL_ERROR "Failed to extract Python SOABI extension:\n${_soabi_error_value}")
  else()
    message(CHECK_PASS "done")
  endif()
endif()

# ==============================================================================
# For Huawei internal security assessment

if(BINSCOPE)
  get_filename_component(_binscope_path ${BINSCOPE} DIRECTORY)
  get_filename_component(_binscope_name ${BINSCOPE} NAME)
endif()

find_program(
  binscope_exec
  NAMES binscope ${_binscope_name}
  HINTS ${_binscope_path})
include(${CMAKE_CURRENT_LIST_DIR}/binscope.cmake)

# ==============================================================================
