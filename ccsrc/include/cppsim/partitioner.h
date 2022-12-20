#ifndef COMBINATIONS_PARTITIONER_H
#define COMBINATIONS_PARTITIONER_H 

#include "combinations.h"

#include <cstdio>

class Partitioner
{
public :

	template<
		uint32_t ...Args, // Underlying combination parameters
		class Starts
	>
	static void partition(Starts& starts, int& nworkers, uint32_t& maxCombinationsPerWorker)
	{
		using Combination = typename Combinations::template Combination<Args...>::type;

		uint32_t totalNumberOfCombinations = Combinations::template popcount<Args...>();
		maxCombinationsPerWorker = totalNumberOfCombinations / nworkers;
		if (totalNumberOfCombinations % nworkers) maxCombinationsPerWorker++;

		// Record starting points for workers' cooperative processing.
		starts.reserve(nworkers);
		uint32_t i = maxCombinationsPerWorker;
		Combinations::template iterate<Args...>([&](auto... args)
		{
			if (i < maxCombinationsPerWorker)
			{
				i++;
				return;
			}

			// Combinations::iterate uses reversed order of starting point indices.
			// We revert it here, in order to make the Combinations::iterate
			// code more generic.
			Combination start { args... };
			Combinations::template reverse<Args...>(start);
			starts.push_back(start);
			i = 1;
		});

		// Re-evaluate the number of workers, as their number could be eventually
		// smaller than the initially proposed number of workers.
		nworkers = starts.size();

		printf("%u iterations in total, %u workers, %u iterations per worker\n",
			totalNumberOfCombinations, nworkers, maxCombinationsPerWorker);
	}
};

#endif // COMBINATIONS_PARTITIONER_H

