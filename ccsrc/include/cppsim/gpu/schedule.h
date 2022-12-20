#if defined(__CUDACC__) || defined(__HIPCC__)

#ifndef SCHEDULE_GPU_H
#define SCHEDULE_GPU_H

#include "partitioner.h"

#include <stdint.h>
#include <string>
#include <sstream>
#if defined(__CUDACC__)
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#else
#include <hipThrust/thrust/device_vector.h>
#include <hipThrust/thrust/host_vector.h>
#endif

namespace gpu {

template<
	class Contexts,
	class Callable,
	class Starts,
	uint32_t ...Args // Underlying combination parameters
>
__global__ void kernel(Contexts ctxs, Callable c,
	int nworkers, Starts starts, uint32_t maxCombinationsPerWorker)
{
	int iworker = threadIdx.x + blockDim.x * blockIdx.x;
	if (iworker >= nworkers) return;

	auto& ctx = ctxs[iworker];
	Combinations::template iterate<Args...>(
		starts[iworker], maxCombinationsPerWorker, [&] __device__ (auto... args)
	{
		c(ctx, args...);
	});
}

template<
	class Contexts,
	class Callable,
	uint32_t ...Args // Underlying combination parameters
>
class Schedule
{
	using Combination = typename Combinations::template Combination<Args...>::type;
		
	int nblocks;

	int nworkers;
	uint32_t maxCombinationsPerWorker;
	
	thrust::device_vector<Combination> starts;

	Callable c;
	
	std::string name;

public :
	
	int getWorkersCount() const { return nworkers; }
	
	const char* getName() const { return name.c_str(); }
	
	Schedule(int nworkers_, int nblocks_, Callable c_) :
		nworkers(nworkers_), nblocks(nblocks_), c(c_)
	{		
		// Calculate workers partitions on host, which should be
		// fast, as the iterator body is trivial. Then we re-use
		// this schedule to perform the real iterations with a
		// meaningful user-defined iterator body.		
		thrust::host_vector<Combination> startsHost;
		Partitioner::template partition<Args...>(
			startsHost, nworkers, maxCombinationsPerWorker);
		starts = startsHost;
		
		// Get the GPU name.
#if defined(__CUDACC__)
		cudaDeviceProp props;
		::gpu::checkErrorStatus(cudaGetDeviceProperties(&props, 0));
#elif defined(__HIPCC__)
		hipDeviceProp_t props;
		::gpu::checkErrorStatus(hipGetDeviceProperties(&props, 0));
#endif
		name = props.name;		
	}

	void execute(Contexts ctxs)
	{
		auto startsPtr = thrust::raw_pointer_cast(starts.data());
		kernel<
			Contexts,
			Callable,
			Combination*,
			Combinations,
			Args...><<<nblocks, ::gpu::nthreadsPerBlock>>>(
			ctxs, c, nworkers, startsPtr, maxCombinationsPerWorker);
#if defined(__CUDACC__)
		::gpu::checkErrorStatus(cudaGetLastError());
		::gpu::checkErrorStatus(cudaDeviceSynchronize());
#elif defined(__HIPCC__)
		::gpu::checkErrorStatus(hipGetLastError());
		::gpu::checkErrorStatus(hipDeviceSynchronize());
#endif
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
	using Combination = typename Combinations::template Combination<Args...>::type;

	struct cudaFuncAttributes attrs;
	::gpu::checkErrorStatus(cudaFuncGetAttributes(&attrs,
		kernel<Contexts, Callable, Combination*, Combinations, Args...>));
	printf("%d registers per thread\n", attrs.numRegs);
	
	if (nworkers)
	{
		// Get the GPU compute grid from the user-specified
		// number of workers.
		int nblocks = nworkers / ::gpu::nthreadsPerBlock;
		if (nworkers % ::gpu::nthreadsPerBlock) nblocks++;
		
		return Schedule<
			Contexts,
			Callable,
			Args...>(nworkers, nblocks, c);			
	}

	int nblocks = 0;
	const size_t dynamicSMemSize = 0;
#if defined(__CUDACC__)
	::gpu::checkErrorStatus(cudaOccupancyMaxActiveBlocksPerMultiprocessor(
		&nblocks, kernel<Contexts, Callable, Combination*, Combinations, Args...>,
		::gpu::nthreadsPerBlock, dynamicSMemSize));
	cudaDeviceProp props;
	::gpu::checkErrorStatus(cudaGetDeviceProperties(&props, 0));
#elif defined(__HIPCC__)
	::gpu::checkErrorStatus(hipOccupancyMaxActiveBlocksPerMultiprocessor(
		&nblocks, kernel<Contexts, Callable, Combination*, Combinations, Args...>,
		::gpu::nthreadsPerBlock, dynamicSMemSize));
	hipDeviceProp_t props;
	::gpu::checkErrorStatus(hipGetDeviceProperties(&props, 0));
#endif
	nblocks *= props.multiProcessorCount;

	return Schedule<
		Contexts,
		Callable,
		Args...>(nblocks * ::gpu::nthreadsPerBlock, nblocks, c);
}

} // namespace gpu

#endif // SCHEDULE_GPU_H

#endif // defined(__CUDACC__) || defined(__HIPCC__)

