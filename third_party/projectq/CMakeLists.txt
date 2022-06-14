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

file(GLOB _patch_files "${CMAKE_CURRENT_LIST_DIR}/patch/*.patch*")
list(SORT _patch_files CASE INSENSITIVE)

mindquantum_add_pkg(
  projectq
  VER 0.5.1
  MD5 0da22cba1e2d693b32473b2eaf7c29d2
  URL "https://gitee.com/mirrors/ProjectQ/repository/archive/v0.5.1.tar.gz"
  ONLY_COPY_DIRS projectq/backends/_sim/_cppkernels
  PATCHES ${_patch_files}
  FORCE_LOCAL_PKG
  TARGET_ALIAS mindquantum::projectq projectq::projectq)
target_compile_features(projectq::projectq INTERFACE cxx_std_14)

# ==============================================================================

add_library(mq_projectq INTERFACE)
target_sources(
  mq_projectq
  INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/projectq.h>
            $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/projectq_utils.h>
            $<INSTALL_INTERFACE:${MQ_INSTALL_3RDPARTYDIR}/projectq/projectq.h>
            $<INSTALL_INTERFACE:${MQ_INSTALL_3RDPARTYDIR}/projectq/projectq_utils.h>)

target_compile_definitions(mq_projectq INTERFACE INTRIN)
target_include_directories(mq_projectq INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}>
                                                 $<INSTALL_INTERFACE:${MQ_INSTALL_INCLUDEDIR}/projectq>)
target_link_libraries(mq_projectq INTERFACE mindquantum::projectq intrin_flag_CXX)

# ------------------------------------------------------------------------------

install(FILES ${CMAKE_CURRENT_LIST_DIR}/projectq.h ${CMAKE_CURRENT_LIST_DIR}/projectq_utils.h
        DESTINATION ${MQ_INSTALL_INCLUDEDIR}/projectq)

append_to_property(mq_install_targets GLOBAL mq_projectq)

# ==============================================================================
