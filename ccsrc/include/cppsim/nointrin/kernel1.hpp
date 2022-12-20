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

#define LOOP_COLLAPSE1 2

template <class V, class M>
inline void kernel_core(V &psi, std::size_t I, std::size_t d0, M const& m)
{
    std::array v =
    {
        psi[I],
        psi[I + d0]
    };

    psi[I] = (add(mul(v[0], m[0][0]), mul(v[1], m[0][1])));
    psi[I + d0] = (add(mul(v[0], m[1][0]), mul(v[1], m[1][1])));

}

// bit indices id[.] are given from high to low (e.g. control first for CNOT)
template <class V, class M>
void kernel(V &psi, unsigned id0, M const& m, std::size_t ctrlmask)
{
    std::size_t ids_sorted[] = { id0 };
    std::sort(ids_sorted, ids_sorted + 1, std::greater<std::size_t>());
    std::size_t n = 1UL << (ids_sorted[0] + 1);
    std::size_t d0 = 1UL << id0;
    std::size_t dsorted0 = 1UL << ids_sorted[0];

    if (ctrlmask == 0){
        #pragma omp for collapse(LOOP_COLLAPSE1) schedule(static)
        for (omp::idx_t i0 = 0; i0 < n; i0 += 2 * dsorted0){
            for (omp::idx_t i1 = 0; i1 < dsorted0; ++i1){
                kernel_core(psi, i0 + i1, d0, m);
            }
        }
    }
    else{
        #pragma omp for collapse(LOOP_COLLAPSE1) schedule(static)
        for (omp::idx_t i0 = 0; i0 < n; i0 += 2 * dsorted0){
            for (omp::idx_t i1 = 0; i1 < dsorted0; ++i1){
                if (((i0 + i1)&ctrlmask) == ctrlmask)
                    kernel_core(psi, i0 + i1, d0, m);
            }
        }
    }
}
