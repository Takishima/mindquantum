cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

project(
  cppsim
  VERSION 1.0.0
  LANGUAGES C CXX)

# Minimum required Python version (used both in this file and in the installed CMake configuration)
set(CPPSIM_PYTHON_VERSION_MIN 3.7.0)

option(BUILD_TESTING "Build the test suite?" OFF)

if(NOT DEFINED ITERATOR_DEBUG_VALUE)
  set(ITERATOR_DEBUG_VALUE 0)
endif()
option(MSVC_ITERATOR_DEBUG "Define _ITERATOR_DEBUG_LEVEL (defaults to 0, can be set using ITERATOR_DEBUG_VALUE)" OFF)

# ==============================================================================

include(GNUInstallDirs)

set(CPPSIM_INSTALL_BINDIR "${CMAKE_INSTALL_BINDIR}")
set(CPPSIM_INSTALL_SBINDIR "${CMAKE_INSTALL_SBINDIR}")
set(CPPSIM_INSTALL_SYSCONFDIR "${CMAKE_INSTALL_SYSCONFDIR}")
set(CPPSIM_INSTALL_INCLUDEDIR "${CMAKE_INSTALL_INCLUDEDIR}/cppsim")
set(CPPSIM_INSTALL_DATADIR "${CMAKE_INSTALL_DATADIR}/cppsim")
set(CPPSIM_INSTALL_LIBDIR "${CMAKE_INSTALL_LIBDIR}/cppsim")
set(CPPSIM_INSTALL_DOCDIR "${CMAKE_INSTALL_DATADIR}/doc/cppsim")
set(CPPSIM_INSTALL_CMAKEDIR "${CPPSIM_INSTALL_DATADIR}/cmake")
set(CPPSIM_INSTALL_3RDPARTYDIR "${CPPSIM_INSTALL_LIBDIR}/third_party")

# ==============================================================================

# TODO
include("${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake/compiler_has_std_filesystem.cmake")

# ==============================================================================

include(FetchContent)
set(FETCHCONTENT_QUIET OFF)

if(BUILD_TESTING)
  FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG 25cc5777a17820a6339204a3552aa1dd5e428669)
  FetchContent_Declare(
    hipThrust
    GIT_REPOSITORY https://github.com/dmikushin/Thrust.git
    GIT_TAG 9a12c1259805ed0a3a5fe9bdeb098a872deb936b)
  FetchContent_MakeAvailable(hipThrust googletest)

  if(NOT DEFINED Eigen3_DIR)
    FetchContent_Declare(
      Eigen3
      GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
      GIT_TAG 3147391d946bb4b6c68edd901f2add6ac1f31f8c)
    FetchContent_MakeAvailable(googletest Eigen3)
  else()
    find_package(Eigen3 CONFIG REQUIRED)
  endif()
endif()

# ------------------------------------------------------------------------------
# In the case of digestpp, the repository only consists of a list of files/directories that we need both our build
# process to find as well as future users of an installed copy of cppsim.
#
# We therefore provide a target that we use for our current build and also install its files into a sub-directory of the
# installation prefix. We then define the digestpp::digestpp target directly within cppsimConfig.cmake

FetchContent_Declare(
  digestpp
  GIT_REPOSITORY https://github.com/kerukuro/digestpp.git
  GIT_TAG 4ec4106677e652a90716ad929d657a622089ef16)
FetchContent_MakeAvailable(digestpp)

add_library(digestpp::digestpp INTERFACE IMPORTED)
target_include_directories(digestpp::digestpp INTERFACE $<BUILD_INTERFACE:${digestpp_SOURCE_DIR}>)

install(
  DIRECTORY ${digestpp_SOURCE_DIR}
  DESTINATION ${CPPSIM_INSTALL_INCLUDEDIR}/third_party
  PATTERN docs EXCLUDE
  PATTERN .git EXCLUDE)

# ------------------------------------------------------------------------------

find_package(res_embed QUIET CONFIG)
if(NOT res_embed_FOUND)
  FetchContent_Declare(
    res_embed
    GIT_REPOSITORY https://github.com/dmikushin/res_embed.git
    GIT_TAG 93b5711070086dea53c3b535018ff34e68479242)
  FetchContent_MakeAvailable(res_embed)
else()
  message(STATUS "Found res_embed at ${res_embed_DIR}")
endif()
include(ResEmbed)

# ------------------------------------------------------------------------------

find_package(Python ${CPPSIM_PYTHON_VERSION_MIN} COMPONENTS Interpreter Development.Module)

# ------------------------------------------------------------------------------

if(APPLE)
  find_program(BREW_CMD brew PATHS /usr/local/bin)
  if(BREW_CMD)
    # Homebrew installs libomp in ${LIBOMP_PREFIX}/lib and the headers in ${LIBOMP_PREFIX}/include
    execute_process(COMMAND ${BREW_CMD} --prefix libomp OUTPUT_VARIABLE LIBOMP_PREFIX)
    string(STRIP ${LIBOMP_PREFIX} LIBOMP_PREFIX)

    find_library(
      LIBOMP_LIB omp gomp libomp
      HINTS ${LIBOMP_PREFIX}
      PATH_SUFFIXES lib
      NO_DEFAULT_PATH)
    if(LIBOMP_LIB)
      get_filename_component(LIBOMP_DIR ${LIBOMP_LIB} DIRECTORY)
      list(APPEND CMAKE_LIBRARY_PATH ${LIBOMP_DIR})
    endif()

    find_path(
      LIBOMP_INC omp.h
      HINTS ${LIBOMP_PREFIX}
      PATH_SUFFIXES include
      NO_DEFAULT_PATH)
    if(LIBOMP_INC)
      list(APPEND CMAKE_INCLUDE_PATH ${LIBOMP_INC})
    else()
      message(WARNING "Unable to locate omp.h, the code might not compile properly.\n"
                      "You might want to try installing the `libomp` Homebrew formula: brew install libomp")
    endif()
  else()
    set(_macports_install_prefix "/opt/local")
    # MacPorts install libomp in ${_macports_install_prefix}/lib/libomp and the headers in
    # ${_macports_install_prefix}/include/libomp
    find_library(
      LIBOMP_LIB omp gomp libomp
      PATHS "${_macports_install_prefix}/lib"
      PATH_SUFFIXES libomp
      NO_DEFAULT_PATH)
    if(LIBOMP_LIB)
      get_filename_component(LIBOMP_DIR ${LIBOMP_LIB} DIRECTORY)
      list(APPEND CMAKE_LIBRARY_PATH ${LIBOMP_DIR})
    endif()

    find_path(
      LIBOMP_INC omp.h
      PATHS "${_macports_install_prefix}/include"
      PATH_SUFFIXES libomp
      NO_DEFAULT_PATH)
    if(LIBOMP_INC)
      list(APPEND CMAKE_INCLUDE_PATH ${LIBOMP_INC})
    else()
      message(WARNING "Unable to locate omp.h, the code might not compile properly.\n"
                      "You might want to try installing the `libomp` MacPorts port: sudo port install libomp")
    endif()
  endif()
endif()

find_package(OpenMP REQUIRED)

# ------------------------------------------------------------------------------

# TODO Shouldn't we take dlfcn-win32 to third_party,
# or replace it with cross-platform dynalo?
if(MSVC
   OR MINGW
   OR MSYS)
  find_package(dlfcn-win32 CONFIG QUIET)
  if(NOT dlfcn-win32_FOUND)
    set(_build_shared_libs ${BUILD_SHARED_LIBS})
    set(BUILD_SHARED_LIBS OFF)
    FetchContent_Declare(
      dlfcn-win32
      GIT_REPOSITORY https://github.com/dlfcn-win32/dlfcn-win32.git
      GIT_TAG 9d0ef119d9fcb9139f831adc224857b791c81140)
    FetchContent_MakeAvailable(dlfcn-win32)
    set(BUILD_SHARED_LIBS ${_build_shared_libs})
    target_include_directories(dl PUBLIC $<BUILD_INTERFACE:${dlfcn-win32_SOURCE_DIR}/src>)
    list(APPEND CMAKE_DL_LIBS dl)
  else()
    message(STATUS "Found dlfcn-win32 at ${dlfcn-win32_DIR}")
    list(APPEND CMAKE_DL_LIBS dlfcn-win32::dl)
  endif()
endif()

# ------------------------------------------------------------------------------

set(filesystem_LIBS)
if(NOT CPPSIM_HAS_STD_FILESYSTEM)
  find_package(Boost REQUIRED COMPONENTS filesystem)
  set(filesystem_LIBS Boost::filesystem)
endif()

# ==============================================================================

include(CMakePackageConfigHelpers)

set(_namespace cppsim::)

configure_package_config_file(${CMAKE_CURRENT_LIST_DIR}/../../../cmake/cppsimConfig.cmake.in
                              ${PROJECT_BINARY_DIR}/cppsimConfig.cmake INSTALL_DESTINATION ${CPPSIM_INSTALL_CMAKEDIR})

write_basic_package_version_file(${PROJECT_BINARY_DIR}/cppsimConfigVersion.cmake COMPATIBILITY SameMajorVersion)

install(FILES ${PROJECT_BINARY_DIR}/cppsimConfig.cmake ${PROJECT_BINARY_DIR}/cppsimConfigVersion.cmake
        DESTINATION ${CPPSIM_INSTALL_CMAKEDIR})

install(DIRECTORY ${PROJECT_SOURCE_DIR}/../../../cmake/commands DESTINATION ${CPPSIM_INSTALL_CMAKEDIR})
install(FILES ${PROJECT_SOURCE_DIR}/../../../cmake/compiler_has_std_filesystem.cmake DESTINATION ${CPPSIM_INSTALL_CMAKEDIR})

file(GLOB _headers ${CMAKE_CURRENT_LIST_DIR}/include/*.h ${CMAKE_CURRENT_LIST_DIR}/include/*.hpp LIST_DIRECTORIES FALSE)
install(FILES ${_headers} DESTINATION ${CPPSIM_INSTALL_INCLUDEDIR})
install(DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/../../include/cppsim/cpu ${CMAKE_CURRENT_LIST_DIR}/../../include/cppsim/gpu
                  ${CMAKE_CURRENT_LIST_DIR}/../../include/cppsim/intrin ${CMAKE_CURRENT_LIST_DIR}/../../include/cppsim/nointrin
        DESTINATION ${CPPSIM_INSTALL_INCLUDEDIR})

# ==============================================================================

add_library(kernelgen STATIC "kernelgen.cpp" "compiler.cpp" "tempfile.cpp")
target_compile_features(kernelgen PUBLIC cxx_std_17)
set_property(TARGET kernelgen PROPERTY POSITION_INDEPENDENT_CODE ON)
target_include_directories(kernelgen PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../include/cppsim>
                                            $<INSTALL_INTERFACE:${CPPSIM_INSTALL_INCLUDEDIR}>)

if(MSVC AND MSVC_ITERATOR_DEBUG)
  target_compile_definitions(kernelgen PUBLIC _ITERATOR_DEBUG=${ITERATOR_DEBUG_VALUE})
endif()

res_embed(
  TARGET kernelgen
  NAME "nointrin"
  PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../include/cppsim/nointrin/kernelgen.py"
  KEYWORD)

target_link_libraries(kernelgen PUBLIC digestpp::digestpp pybind11::module OpenMP::OpenMP_CXX ${CMAKE_DL_LIBS}
                                       ${filesystem_LIBS})

pybind11_add_module(${PROJECT_NAME} MODULE "_${PROJECT_NAME}.cpp")
target_link_libraries(${PROJECT_NAME} PRIVATE kernelgen)

# ==============================================================================

install(
  TARGETS kernelgen kernelgen_nointrin
  EXPORT cppsimTargets
  PRIVATE_HEADER DESTINATION ${CPPSIM_INSTALL_INCLUDEDIR}
  PUBLIC_HEADER DESTINATION ${CPPSIM_INSTALL_INCLUDEDIR}
  ARCHIVE DESTINATION ${CPPSIM_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CPPSIM_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CPPSIM_INSTALL_BINDIR})

install(
  EXPORT cppsimTargets
  NAMESPACE ${_namespace}
  DESTINATION ${CPPSIM_INSTALL_CMAKEDIR})

# ==============================================================================

if(BUILD_TESTING)
  include(kernelgen)

  add_executable(test_nointrin "test/test_nointrin.cpp")
  target_compile_features(test_nointrin PRIVATE cxx_std_17)
  target_link_libraries(test_nointrin PRIVATE gtest kernelgen Eigen3::Eigen)

  kernelgen(
    TARGET test_nointrin
    NQUBITS 1
    VARIANT nointrin
    COMBINATIONS)
  kernelgen(
    TARGET test_nointrin
    NQUBITS 2
    VARIANT nointrin
    COMBINATIONS)
  kernelgen(
    TARGET test_nointrin
    NQUBITS 3
    VARIANT nointrin
    COMBINATIONS)
  kernelgen(
    TARGET test_nointrin
    NQUBITS 4
    VARIANT nointrin
    COMBINATIONS)
  kernelgen(
    TARGET test_nointrin
    NQUBITS 5
    VARIANT nointrin
    COMBINATIONS)

  add_executable(test_popcount "test/test_popcount.cpp")
  target_compile_features(test_popcount PRIVATE cxx_std_17)
  target_link_libraries(test_popcount PRIVATE Eigen3::Eigen gtest)

  add_executable(test_combinations "test/test_combinations.cpp")
  target_compile_features(test_combinations PRIVATE cxx_std_17)
  target_link_libraries(test_combinations PRIVATE gtest Eigen3::Eigen OpenMP::OpenMP_CXX)

  add_executable(benchmark "benchmark/benchmark.cpp")
  target_link_libraries(benchmark PRIVATE gtest kernelgen)
endif()
