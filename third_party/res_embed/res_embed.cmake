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

set(VER 0.0.1)

if(ENABLE_GITEE)
  set(GIT_URL "https://github.com/dmikushin/res_embed.git")
else()
  set(GIT_URL "https://github.com/dmikushin/res_embed.git")
endif()
set(GIT_TAG "26a18b27794c1fcf698e603beb8b122218dae490")

mindquantum_add_pkg(
  res_embed
  VER ${VER}
  GIT_REPOSITORY ${GIT_URL}
  GIT_TAG ${GIT_TAG}
  MD5 "xxxx" # NB: would be required if local server is enabled for downloads
  ONLY_COPY_DIRS cmake
  FORCE_LOCAL_PKG)

if(res_embed_DIR)
  # cmake-lint: disable=C0103
  set(res_embed_CMAKE_DIR ${res_embed_BASE_DIR}/cmake)
  message(STATUS "res_embed_CMAKE_DIR = ${res_embed_CMAKE_DIR}")
endif()
