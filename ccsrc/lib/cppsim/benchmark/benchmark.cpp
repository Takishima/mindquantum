#include "kernelgen.hpp"

#include "gtest/gtest.h"

#include <array>
#include <random>
#include <vector>

template<int nqubits>
bool benchmark()
{
	std::array<unsigned, nqubits> ids;
	size_t n = 1;
	for (int i = 0; i < nqubits; i++)
	{
		ids[i] = i;
		n += 1UL << i;
	}

	std::default_random_engine dre;
	std::uniform_int_distribution<int> uid(-1000, 1000);

	// Generate m matrix as integers.
	std::array<std::array<int, 1UL << nqubits>, 1UL << nqubits> m;
	for (int j = 0; j < m.size(); j++)
		for (int i = 0; i < m.size(); i++)
			m[j][i] = uid(dre);

	// Generate psi matrix as integers.
	std::vector<int> psi(n);
	for (int i = 0; i < psi.size(); i++)
		psi[i] = uid(dre);

	// Generate control mask.
	std::size_t ctrlmask = 0; // uid(dre);

	kernelgen(psi, ids, m, ctrlmask);
}

TEST(nointrin, kernel6)
{
	benchmark<6>();
}

int main(int argc, char* argv[])
{
	::testing::InitGoogleTest(&argc, argv);
	return RUN_ALL_TESTS();
}

