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
  # NB: This repository is not up to date...

  # set(GIT_URL "https://gitee.com/tomgee/digestpp.git")
  set(GIT_URL "https://github.com/kerukuro/digestpp.git")
else()
  set(GIT_URL "https://github.com/kerukuro/digestpp.git")
endif()
set(GIT_TAG "4ec4106677e652a90716ad929d657a622089ef16")

mindquantum_add_pkg(
  digestpp
  VER ${VER}
  GIT_REPOSITORY ${GIT_URL}
  GIT_TAG ${GIT_TAG}
  MD5 "xxxx" # NB: would be required if local server is enabled for downloads
  FORCE_LOCAL_PKG
  ONLY_COPY_DIRS algorithm detail digestpp.hpp hasher.hpp
  TARGET_ALIAS mindquantum::digestpp digestpp::digestpp)
