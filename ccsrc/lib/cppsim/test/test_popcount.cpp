#include <algorithm>
#include <array>
#include <complex>
#include <cstdlib>
#include "combinations.h"

#include "gtest/gtest.h"

size_t popcount_reference(unsigned id4, unsigned id3, unsigned id2, unsigned id1, unsigned id0)
{
    std::size_t d0 = 1UL << id0, d1 = 1UL << id1, d2 = 1UL << id2, d3 = 1UL << id3, d4 = 1UL << id4;
    std::size_t n = 1 + d0 + d1 + d2 + d3 + d4;
    std::size_t dsorted[] = { d4, d3, d2, d1, d0 };
    std::sort(dsorted, dsorted + 5, std::greater<std::size_t>());

    size_t popcount = 0;
    for (std::size_t i0 = 0; i0 < n; i0 += 2 * dsorted[0])
        for (std::size_t i1 = 0; i1 < dsorted[0]; i1 += 2 * dsorted[1])
            for (std::size_t i2 = 0; i2 < dsorted[1]; i2 += 2 * dsorted[2])
                for (std::size_t i3 = 0; i3 < dsorted[2]; i3 += 2 * dsorted[3])
                    for (std::size_t i4 = 0; i4 < dsorted[3]; i4 += 2 * dsorted[4])
                        for (std::size_t i5 = 0; i5 < dsorted[4]; ++i5)
                            popcount++;
    
    return popcount;
}

TEST(popcount, kernel5)
{
	constexpr unsigned id0 = 0, id1 = 1, id2 = 2, id3 = 3, id4 = 4;
	constexpr std::size_t d0 = 1UL << id0, d1 = 1UL << id1, d2 = 1UL << id2, d3 = 1UL << id3, d4 = 1UL << id4;
	constexpr std::size_t n = 1 + d0 + d1 + d2 + d3 + d4;
	auto popcount1 = popcount_reference(id4, id3, id2, id1, id0);
	auto popcount2 = Combinations::popcount<n, d4, d3, d2, d1, d0>();
	ASSERT_EQ(popcount1, popcount2);
}

int main(int argc, char* argv[])
{
	::testing::InitGoogleTest(&argc, argv);
	return RUN_ALL_TESTS();
}

