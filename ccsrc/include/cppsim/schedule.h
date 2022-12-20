#ifndef COMBINATIONS_SCHEDULE_H
#define COMBINATIONS_SCHEDULE_H

#include "combinations.h"

#if defined(__CUDACC__) || defined(__HIPCC__)
#include "gpu/schedule.h"
#endif
#include "cpu/schedule.h"

enum BackendPreference
{
	BackendNoPreference = 0,
	BackendPreferCPU = 1,
	BackendPreferDiscreteGPU = 2,
	BackendPreferIntegratedGPU = 3
};

template<
	BackendPreference backend = BackendNoPreference>
class Schedule
{
public :

	// Iterate through combinations with specific starting point and duration.
	// For each combination, call a user-provided function.
	template<
		class Contexts,
		uint32_t ...Args, // Underlying combination parameters
		class Callable
	>
	static auto schedule(Callable c, int nworkers = 0)
	{
		if constexpr (backend == BackendNoPreference)
		{
			// Prioritize GPU execution, if supported.
#if defined(__CUDACC__) || defined(__HIPCC__)
			return gpu::make_schedule<
				Contexts,
				Args...>(c, nworkers);
#else
			return cpu::make_schedule<
				Contexts,
				Args...>(c, nworkers);
#endif
		}
#if defined(__CUDACC__) || defined(__HIPCC__)
		else if constexpr (backend == BackendPreferDiscreteGPU)
		{
			return gpu::make_schedule<
				Contexts,
				Args...>(c, nworkers);
		}
#endif
		else if constexpr (backend == BackendPreferCPU)
		{
			return cpu::make_schedule<
				Contexts,
				Args...>(c, nworkers);
		}
		else
		{
			throw std::invalid_argument("Unsupported backend");
		}
	}

	template<typename Contexts, typename Schedule>
	static void iterate(Contexts& ctxs, Schedule& schedule)
	{
		schedule.execute(ctxs);
	}
};

#endif // COMBINATIONS_SCHEDULE_H

