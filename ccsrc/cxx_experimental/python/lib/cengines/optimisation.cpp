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

#include "cengines/optimisation.hpp"

#include <pybind11/pybind11.h>

#include "details/python2cpp_conv.hpp"

#define GET_ATTR_FROM_PYTHON(name) mindquantum::details::get_attr_from_python(src, value, #name, &optim_t::set_##name)

bool mindquantum::details::load_optimiser(pybind11::handle src, python::cpp::LocalOptimizer& value) {
    using optim_t = python::cpp::LocalOptimizer;
    if (!GET_ATTR_FROM_PYTHON(_m)) {
        return false;
    }
    return true;
}

#undef GET_ATTR_FROM_PYTHON
