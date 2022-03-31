//   Copyright 2020 <Huawei Technologies Co., Ltd>
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

#ifndef CORE_CONFIG_HPP
#define CORE_CONFIG_HPP

#include <vector>

#include "core/cxx20_config.hpp"
#include "core/details/clang_version.hpp"
#include "core/details/cxx20_compatibility.hpp"

#ifdef __has_cpp_attribute
#    if __has_cpp_attribute(nodiscard)
#        define MQ_NODISCARD [[nodiscard]]
#    endif  // __has_cpp_attribute(nodiscard)
#endif      // __has_cpp_attribute

#ifndef MQ_NODISCARD
#    define MQ_NODISCARD
#endif  // MQ_NODISCARD

#ifndef MQ_IS_CLANG_VERSION_LESS
#    define MQ_IS_CLANG_VERSION_LESS(major, minor)                                                                     \
        (defined __clang__) && (MQ_CLANG_MAJOR < major) && (HIQ_CLANG_MINOR < minor)
#    define MQ_IS_CLANG_VERSION_LESS_EQUAL(major, minor)                                                               \
        (defined __clang__) && (MQ_CLANG_MAJOR <= major) && (HIQ_CLANG_MINOR <= minor)
#endif  // MQ_IS_CLANG_VERSION_LESS

#if !defined(MQ_CONFIG_NO_COUNTER) && !defined(HIQ_CONFIG_COUNTER)
#    define MQ_CONFIG_COUNTER
#endif  // !MQ_CONFIG_NO_COUNTER && !HIQ_CONFIG_COUNTER

#define MQ_UNIQUE_NAME_LINE2(name, line) name##line
#define MQ_UNIQUE_NAME_LINE(name, line)  MQ_UNIQUE_NAME_LINE2(name, line)
#ifdef MQ_CONFIG_COUNTER
#    define MQ_UNIQUE_NAME(name) MQ_UNIQUE_NAME_LINE(name, __COUNTER__)
#else
#    define MQ_UNIQUE_NAME(name) MQ_UNIQUE_NAME_LINE(name, __LINE__)
#endif

namespace mindquantum {
using qubit_id_t = unsigned int;
using qureg_t = std::vector<qubit_id_t>;
}  // namespace mindquantum

#endif /* CORE_CONFIG_HPP */
