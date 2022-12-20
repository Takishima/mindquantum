#ifndef SCHEDULE_CPU_H
#define SCHEDULE_CPU_H

#include "partitioner.h"

#ifdef _OPENMP
#include <omp.h>
#endif
#include <stdint.h>
#include <sstream>
#include <vector>

namespace cpu {

template<
	class Contexts,
	class Callable,
	uint32_t ...Args // Underlying combination parameters
>
class Schedule
{
	using Combination = typename Combinations::template Combination<Args...>::type;

	int nworkers;
	uint32_t maxCombinationsPerWorker;
	
	std::vector<Combination> starts;

	Callable c;

public :

	int getWorkersCount() const { return nworkers; }
	
	const char* getName() const { return "cpu"; }

	Schedule(int nworkers_, Callable c_) :
		nworkers(nworkers_), c(c_)
	{
		// Calculate workers partitions on host, which should be
		// fast, as the iterator body is trivial. Then we re-use
		// this schedule to perform the real iterations with a
		// meaningful user-defined iterator body.		
		Partitioner::template partition<Args...>(
			starts, nworkers, maxCombinationsPerWorker);
	}
	
	void execute(Contexts ctxs)
	{
		#pragma omp parallel for
		for (int iworker = 0; iworker < nworkers; iworker++)
		{
			auto& ctx = ctxs[iworker];
			uint32_t limit = maxCombinationsPerWorker;
			Combinations::template iterate<Args...>(starts[iworker], limit, [&](auto... args)
			{
				c(ctx, args...);
			});
		}
	}
};

// We need to know all of the types participating in the used-defined
// combination specialization, in order to estimate the maximum number
// of blocks that could simultaneously fit into the GPU. By using this
// number multipled by the number of SMs, we partition the workload
// most evenly.
template<
	class Contexts,
	uint32_t ...Args, // Underlying combination parameters
	class Callable
>
auto make_schedule(Callable c, int nworkers = 0)
{
	if (nworkers == 0)
	{
#ifdef _OPENMP
		#pragma omp parallel
		{
			#pragma omp master
			{
				nworkers = omp_get_num_threads();
			}
		}
#else
		nworkers = 1;
#endif
	}
	
	if (nworkers <= 0) nworkers = 1;
	
	return Schedule<
		Contexts,
		Callable,
		Args...>(nworkers, c);
}

} // namespace cpu

#endif // SCHEDULE_CPU_H

