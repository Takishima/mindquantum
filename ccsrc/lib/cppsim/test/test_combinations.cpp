#include <algorithm>
#include <array>
#include <complex>
#include <cstdlib>
#define EIGEN_DEFAULT_DENSE_INDEX_TYPE int
#define EIGEN_VECTORIZE
#include <Eigen/Dense>
#include "combinations.h"

#define add(a, b) (a + b)
#define mul(a, b) (a * b)

#define M(j, i) (m[j * 32 + i])

template<class T>
inline void kernel_core(T* psi, std::size_t I, std::size_t d0, std::size_t d1, std::size_t d2, std::size_t d3, std::size_t d4, const T* m)
{
    const std::array v = {
        psi[I],
        psi[I + d0],
        psi[I + d1],
        psi[I + d0 + d1],
        psi[I + d2],
        psi[I + d0 + d2],
        psi[I + d1 + d2],
        psi[I + d0 + d1 + d2],
        psi[I + d3],
        psi[I + d0 + d3],
        psi[I + d1 + d3],
        psi[I + d0 + d1 + d3],
        psi[I + d2 + d3],
        psi[I + d0 + d2 + d3],
        psi[I + d1 + d2 + d3],
        psi[I + d0 + d1 + d2 + d3],
        psi[I + d4],
        psi[I + d0 + d4],
        psi[I + d1 + d4],
        psi[I + d0 + d1 + d4],
        psi[I + d2 + d4],
        psi[I + d0 + d2 + d4],
        psi[I + d1 + d2 + d4],
        psi[I + d0 + d1 + d2 + d4],
        psi[I + d3 + d4],
        psi[I + d0 + d3 + d4],
        psi[I + d1 + d3 + d4],
        psi[I + d0 + d1 + d3 + d4],
        psi[I + d2 + d3 + d4],
        psi[I + d0 + d2 + d3 + d4],
        psi[I + d1 + d2 + d3 + d4],
        psi[I + d0 + d1 + d2 + d3 + d4],
    };

    const auto result = Eigen::Map<const Eigen::Matrix<T, 32, 32, Eigen::RowMajor>>(m) * Eigen::Map<const Eigen::Vector<T, 32>>(v.data());

    psi[I] = result[0];
    psi[I + d0] = result[1];
    psi[I + d1] = result[2];
    psi[I + d0 + d1] = result[3];
    psi[I + d2] = result[4];
    psi[I + d0 + d2] = result[5];
    psi[I + d1 + d2] = result[6];
    psi[I + d0 + d1 + d2] = result[7];
    psi[I + d3] = result[8];
    psi[I + d0 + d3] = result[9];
    psi[I + d1 + d3] = result[10];
    psi[I + d0 + d1 + d3] = result[11];
    psi[I + d2 + d3] = result[12];
    psi[I + d0 + d2 + d3] = result[13];
    psi[I + d1 + d2 + d3] = result[14];
    psi[I + d0 + d1 + d2 + d3] = result[15];
    psi[I + d4] = result[16];
    psi[I + d0 + d4] = result[17];
    psi[I + d1 + d4] = result[18];
    psi[I + d0 + d1 + d4] = result[19];
    psi[I + d2 + d4] = result[20];
    psi[I + d0 + d2 + d4] = result[21];
    psi[I + d1 + d2 + d4] = result[22];
    psi[I + d0 + d1 + d2 + d4] = result[23];
    psi[I + d3 + d4] = result[24];
    psi[I + d0 + d3 + d4] = result[25];
    psi[I + d1 + d3 + d4] = result[26];
    psi[I + d0 + d1 + d3 + d4] = result[27];
    psi[I + d2 + d3 + d4] = result[28];
    psi[I + d0 + d2 + d3 + d4] = result[29];
    psi[I + d1 + d2 + d3 + d4] = result[30];
    psi[I + d0 + d1 + d2 + d3 + d4] = result[31];
    
}

#undef add
#undef mul
#undef M

// bit indices id[.] are given from high to low (e.g. control first for CNOT)
template<class T>
void kernel(T* psi, unsigned id4, unsigned id3, unsigned id2, unsigned id1, unsigned id0, const T* m, std::size_t ctrlmask)
{
    std::size_t d0 = 1UL << id0, d1 = 1UL << id1, d2 = 1UL << id2, d3 = 1UL << id3, d4 = 1UL << id4;
    std::size_t n = 1 + d0 + d1 + d2 + d3 + d4;
    std::size_t dsorted[] = { d4, d3, d2, d1, d0 };
    std::sort(dsorted, dsorted + 5, std::greater<std::size_t>());

    if (ctrlmask == 0){
        #pragma omp for collapse(6) schedule(static)
        for (std::size_t i0 = 0; i0 < n; i0 += 2 * dsorted[0]){
            for (std::size_t i1 = 0; i1 < dsorted[0]; i1 += 2 * dsorted[1])
                for (std::size_t i2 = 0; i2 < dsorted[1]; i2 += 2 * dsorted[2])
                    for (std::size_t i3 = 0; i3 < dsorted[2]; i3 += 2 * dsorted[3])
                        for (std::size_t i4 = 0; i4 < dsorted[3]; i4 += 2 * dsorted[4])
                            for (std::size_t i5 = 0; i5 < dsorted[4]; ++i5){
                                kernel_core(psi, i0 + i1 + i2 + i3 + i4 + i5, d0, d1, d2, d3, d4, m);
                            }
        }
    }
    else{
        #pragma omp for collapse(6) schedule(static)
        for (std::size_t i0 = 0; i0 < n; i0 += 2 * dsorted[0]){
            for (std::size_t i1 = 0; i1 < dsorted[0]; i1 += 2 * dsorted[1])
                for (std::size_t i2 = 0; i2 < dsorted[1]; i2 += 2 * dsorted[2])
                    for (std::size_t i3 = 0; i3 < dsorted[2]; i3 += 2 * dsorted[3])
                        for (std::size_t i4 = 0; i4 < dsorted[3]; i4 += 2 * dsorted[4])
                            for (std::size_t i5 = 0; i5 < dsorted[4]; ++i5){
                                if (((i0 + i1 + i2 + i3 + i4 + i5)&ctrlmask) == ctrlmask)
                                    kernel_core(psi, i0 + i1 + i2 + i3 + i4 + i5, d0, d1, d2, d3, d4, m);
                            }
        }
    }
}

// bit indices id[.] are given from high to low (e.g. control first for CNOT)
template<unsigned id0, unsigned id1, unsigned id2, unsigned id3, unsigned id4, class T>
void kernel_combinations(T* psi, const T* m, std::size_t ctrlmask)
{
    constexpr std::size_t d0 = 1UL << id0, d1 = 1UL << id1, d2 = 1UL << id2, d3 = 1UL << id3, d4 = 1UL << id4;
    constexpr std::size_t n = 1 + d0 + d1 + d2 + d3 + d4;
    std::size_t dsorted[] = { d4, d3, d2, d1, d0 };
    std::sort(dsorted, dsorted + 5, std::greater<std::size_t>());

    if (ctrlmask == 0){
        Combinations::iterate<n, d4, d3, d2, d1, d0>([=](auto... i)
        {
	    kernel_core(psi, (i + ...), d0, d1, d2, d3, d4, m);
	});
    }
    else{
        Combinations::iterate<n, d4, d3, d2, d1, d0>([=](auto... i)
        {
            if (((i + ...) & ctrlmask) == ctrlmask)
	        kernel_core(psi, (i + ...), d0, d1, d2, d3, d4, m);
	});
    }
}

#include "schedule.h"

// bit indices id[.] are given from high to low (e.g. control first for CNOT)
template<unsigned id0, unsigned id1, unsigned id2, unsigned id3, unsigned id4, class T>
void kernel_combinations_partitioned(T* psi, const T* m, std::size_t ctrlmask)
{
    constexpr std::size_t d0 = 1UL << id0, d1 = 1UL << id1, d2 = 1UL << id2, d3 = 1UL << id3, d4 = 1UL << id4;
    constexpr std::size_t n = 1 + d0 + d1 + d2 + d3 + d4;
    std::size_t dsorted[] = { d4, d3, d2, d1, d0 };
    std::sort(dsorted, dsorted + 5, std::greater<std::size_t>());

    if (ctrlmask == 0){
        // Here we do the "planning" of execution, not the execution itself.
        // We do already specify though an interation loop body, in order
        // for the backend to make the resources allocation.
        auto backend = Schedule<BackendPreferCPU>::template schedule<uint32_t*, n, d4, d3, d2, d1, d0>(
            [=](uint32_t& count_worker, auto... i)
        {
	    kernel_core(psi, (i + ...), d0, d1, d2, d3, d4, m);
        });

        printf("Using %s backend with %u workers\n",
            backend.getName(), backend.getWorkersCount());

        // Finally, execute the iterations.
        uint32_t* ptr = nullptr;
        Schedule<BackendPreferCPU>::iterate(ptr, backend);
    }
    else{
        // Here we do the "planning" of execution, not the execution itself.
        // We do already specify though an interation loop body, in order
        // for the backend to make the resources allocation.
        auto backend = Schedule<BackendPreferCPU>::template schedule<uint32_t*, n, d4, d3, d2, d1, d0>(
            [=](uint32_t& count_worker, auto... i)
        {
            if (((i + ...) & ctrlmask) == ctrlmask)
	        kernel_core(psi, (i + ...), d0, d1, d2, d3, d4, m);
        });

        printf("Using %s backend with %u workers\n",
            backend.getName(), backend.getWorkersCount());

        // Finally, execute the iterations.
        uint32_t* ptr = nullptr;
        Schedule<BackendPreferCPU>::iterate(ptr, backend);
    }
}

#include <array>
#include <iostream>
#include <random>

#include "gtest/gtest.h"

template<int nqubits, typename Kernels, typename V>
bool compare(Kernels kernels, V& psi1)
{
	std::default_random_engine dre;
	dre.seed(0);
	std::uniform_int_distribution<int> uid(-1000, 1000);

	// Generate m matrix as integers.
	std::array<std::array<int, 1UL << nqubits>, 1UL << nqubits> m;
	for (int j = 0; j < m.size(); j++)
		for (int i = 0; i < m.size(); i++)
			m[j][i] = uid(dre);

	// Generate psi matrix as integers.
	for (int i = 0; i < psi1.size(); i++)
		psi1[i] = uid(dre);
	auto psi2 = psi1;
	auto psi3 = psi1;

	// Generate control mask.
	std::size_t ctrlmask = 0; // uid(dre);

	// Compare kernel against generated kernel.
	kernels(psi1, psi2, psi3, m, ctrlmask);
	auto diff2 = std::mismatch(psi1.begin(), psi1.end(), psi2.begin());
	auto diff3 = std::mismatch(psi1.begin(), psi1.end(), psi3.begin());
	if ((diff2.first == psi1.end()) && (diff3.first == psi1.end()))
		return true;

	if (diff2.first != psi1.end())
		std::cout << "Mismatch in psi2 at " << std::distance(psi1.begin(), diff2.first) <<
			" : " << *(diff2.first) << " != " << *(diff2.second) << std::endl;
	if (diff3.first != psi1.end())
		std::cout << "Mismatch in psi3 at " << std::distance(psi1.begin(), diff3.first) <<
			" : " << *(diff3.first) << " != " << *(diff3.second) << std::endl;

	return false;
}

TEST(nointrin, kernel5)
{
	constexpr unsigned id0 = 0, id1 = 1, id2 = 2, id3 = 3, id4 = 4;
	size_t n = 1;
	n += 1UL << id0;
	n += 1UL << id1;
	n += 1UL << id2;
	n += 1UL << id3;
	n += 1UL << id4;
	std::vector<int> psi(n);
	ASSERT_TRUE(compare<5>([&](auto& psi1, auto& psi2, auto& psi3, auto m, auto ctrlmask)
	{
		kernel(&psi1[0], id4, id3, id2, id1, id0, &m[0][0], ctrlmask);
		kernel_combinations<id0, id1, id2, id3, id4>(&psi2[0], &m[0][0], ctrlmask);
		kernel_combinations_partitioned<id0, id1, id2, id3, id4>(&psi3[0], &m[0][0], ctrlmask);
	},
	psi));
}

int main(int argc, char* argv[])
{
	::testing::InitGoogleTest(&argc, argv);
	return RUN_ALL_TESTS();
}

