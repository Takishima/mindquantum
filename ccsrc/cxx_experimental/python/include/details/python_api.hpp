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

#ifndef PYTHON_API_HPP
#define PYTHON_API_HPP

#include <pybind11/pybind11.h>

namespace mindquantum::details {
    class PythonScopeGuard {
     public:
        PythonScopeGuard(PyObject* obj) : obj_(obj) {
        }
        ~PythonScopeGuard() {
            if (obj_ != NULL) {
                Py_DECREF(obj_);
            }
        }

        operator bool() {
            return obj_ != NULL;
        }

        operator PyObject*() {
            return obj_;
        }

     private:
        PyObject* obj_;
    };
}  // namespace mindquantum::details

#endif /* PYTHON_API_HPP */
