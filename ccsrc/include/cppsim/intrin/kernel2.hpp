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

template <class V, class M>
inline void kernel_core(V &psi, std::size_t I, std::size_t d0, std::size_t d1, M const& m, M const& mt)
{
    __m256d v[4];

    v[0] = load2(&psi[I]);
    v[1] = load2(&psi[I + d0]);
    v[2] = load2(&psi[I + d1]);
    v[3] = load2(&psi[I + d0 + d1]);

    _mm256_storeu2_m128d((double*)&psi[I + d0], (double*)&psi[I], add(mul(v[0], m[0], mt[0]), add(mul(v[1], m[1], mt[1]), add(mul(v[2], m[2], mt[2]), mul(v[3], m[3], mt[3])))));
    _mm256_storeu2_m128d((double*)&psi[I + d0 + d1], (double*)&psi[I + d1], add(mul(v[0], m[4], mt[4]), add(mul(v[1], m[5], mt[5]), add(mul(v[2], m[6], mt[6]), mul(v[3], m[7], mt[7])))));

}

// bit indices id[.] are given from high to low (e.g. control first for CNOT)
template <class V, class M>
void kernel(V &psi, unsigned id1, unsigned id0, M const& m, std::size_t ctrlmask)
{
    std::size_t ids_sorted[] = { id1, id0 };
    std::sort(ids_sorted, ids_sorted + 2, std::greater<std::size_t>());
    std::size_t n = 1UL << (ids_sorted[0] + 1);
    std::size_t d0 = 1UL << id0, d1 = 1UL << id1;
    std::size_t dsorted0 = 1UL << ids_sorted[0], dsorted1 = 1UL << ids_sorted[1];

    __m256d mm[] = {load(&m[0][0], &m[1][0]), load(&m[0][1], &m[1][1]), load(&m[0][2], &m[1][2]), load(&m[0][3], &m[1][3]), load(&m[2][0], &m[3][0]), load(&m[2][1], &m[3][1]), load(&m[2][2], &m[3][2]), load(&m[2][3], &m[3][3])};
    __m256d mmt[8];

    __m256d neg = _mm256_setr_pd(1.0, -1.0, 1.0, -1.0);
    for (unsigned i = 0; i < 8; ++i){
        auto badc = _mm256_permute_pd(mm[i], 5);
        mmt[i] = _mm256_mul_pd(badc, neg);
    }

    if (ctrlmask == 0){
        #pragma omp for collapse(LOOP_COLLAPSE2) schedule(static)
        for (omp::idx_t i0 = 0; i0 < n; i0 += 2 * dsorted0){
            for (omp::idx_t i1 = 0; i1 < dsorted0; i1 += 2 * dsorted1){
                for (omp::idx_t i2 = 0; i2 < dsorted1; ++i2){
                    kernel_core(psi, i0 + i1 + i2, d0, d1, mm, mmt);
                }
            }
        }
    }
    else{
        #pragma omp for collapse(LOOP_COLLAPSE2) schedule(static)
        for (omp::idx_t i0 = 0; i0 < n; i0 += 2 * dsorted0){
            for (omp::idx_t i1 = 0; i1 < dsorted0; i1 += 2 * dsorted1){
                for (omp::idx_t i2 = 0; i2 < dsorted1; ++i2){
                    if (((i0 + i1 + i2)&ctrlmask) == ctrlmask)
                        kernel_core(psi, i0 + i1 + i2, d0, d1, mm, mmt);
                }
            }
        }
    }
}
