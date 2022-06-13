//   Copyright 2022 <Huawei Technologies Co., Ltd>
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

#ifndef OMP_COMPAT_HPP
#define OMP_COMPAT_HPP

#include <cstdint>

namespace omp {
#ifdef _MSC_VER
typedef int64_t idx_t;
#else
typedef uint64_t idx_t;
#endif  // _MSC_VER
}  // namespace omp

#endif  // OMP_COMPAT_HPP
