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

set(VER 1.0.0)
set(GIT_TAG "30e2932dec80d42d69fdf866f2249c5852c6eeb9")

if(ENABLE_GITEE)
  set(GIT_REPOSITORY "https://gitee.com/dmikushin/cppsim.git")
else()
  # set(GIT_REPOSITORY "https://github.com/dmikushin/cppsim.git")
  set(GIT_REPOSITORY "https://gitee.com/dmikushin/cppsim.git")
endif()

set(CMAKE_OPTION
    -DBUILD_TESTING=OFF
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -DEigen3_DIR=${Eigen3_DIR}
    -DPYTHON_EXECUTABLE=${Python_EXECUTABLE}
    -DPython3_EXECUTABLE=${Python_EXECUTABLE}
    -DPython_EXECUTABLE=${Python_EXECUTABLE}
    -Ddigestpp_DIR=${digestpp_DIR}
    -Dpybind11_DIR=${pybind11_DIR}
    -Dres_embed_DIR=${res_embed_DIR})

if(APPLE)
  foreach(
    _var
    OpenMP_C_FLAGS
    OpenMP_C_INCLUDE_DIR
    OpenMP_C_LIB_NAMES
    OpenMP_CXX_FLAGS
    OpenMP_CXX_INCLUDE_DIR
    OpenMP_CXX_LIB_NAMES
    OpenMP_gomp_LIBRARY
    OpenMP_libomp_LIBRARY
    OpenMP_pthread_LIBRARY)
    if(NOT "${${_var}}" STREQUAL "")
      list(APPEND CMAKE_OPTION -D${_var}=${${_var}})
    endif()
  endforeach()
endif()

if(NOT _Boost_SYSTEM)
  # Boost was locally built, make sure we use that one
  list(APPEND CMAKE_OPTION -DBOOST_ROOT=${Boost_DIRPATH} -DBoost_NO_SYSTEM_PATHS:BOOL=ON)
endif()

mindquantum_add_pkg(
  cppsim
  VER ${VER}
  GIT_REPOSITORY ${GIT_REPOSITORY}
  GIT_TAG ${GIT_TAG}
  MD5 "xxxx" # NB: would be required if local server is enabled for downloads
  CMAKE_OPTION ${CMAKE_OPTION}
  FORCE_LOCAL_PKG
  TARGET_ALIAS mindquantum::cppsim cppsim::kernelgen)
