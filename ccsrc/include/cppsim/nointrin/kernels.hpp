// Copyright 2017 ProjectQ-Framework (www.projectq.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <algorithm>
#include <array>
#include <complex>
#include <cstdint> // size_t
#include <functional>

#define add(a, b) (a + b)
#define mul(a, b) (a * b)

#include "cppsim_omp.hpp"

#include "kernel1.hpp"
#include "kernel2.hpp"
#include "kernel3.hpp"
#include "kernel4.hpp"
#include "kernel5.hpp"

#undef add
#undef mul

