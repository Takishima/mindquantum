#ifndef GPU_SUPPORT_H
#define GPU_SUPPORT_H

#ifdef __CUDACC__
#include <cuda.h>
#define GPU_SUPPORT __host__ __device__
#else
#define GPU_SUPPORT
#endif

#include <sstream>
#include <string>

namespace gpu {

// TODO 128 threads per block should be preferred,
// but also need to respect the upper limit that could
// be introduced by the kernel (e.g. due to the user code,
// which requires a lot of registers).
constexpr const int nthreadsPerBlock = 128;

#if defined(__CUDACC__) || defined(__HIPCC__)

#ifdef __CUDACC__
constexpr const auto gpuSuccess = cudaSuccess;
constexpr const auto GPU_SUCCESS = CUDA_SUCCESS;
#else
constexpr const auto gpuSuccess = hipSuccess;
constexpr const auto GPU_SUCCESS = HIP_SUCCESS;
#endif

template<typename gpuError_t>
void checkErrorStatus(gpuError_t status)
{
	if (status == gpuSuccess) return;

	std::stringstream ss;
	ss << "GPU runtime error, errno = ";
	ss << status;
	ss << " (";
#if defined(__CUDACC__)
	ss << cudaGetErrorString(status);
#elif defined(__HIPCC__)
	ss << hipGetErrorString(status);
#endif
	ss << ")";
	std::string errorString = ss.str();
	throw std::invalid_argument(errorString);
}

template<typename CUresult>
void checkErrorStatusDriver(CUresult status)
{
	if (status == GPU_SUCCESS) return;
	
	std::stringstream ss;
	ss << "GPU driver runtime error, errno = ";
	ss << status;
	std::string errorString = ss.str();
	throw std::invalid_argument(errorString);		
}

#endif // defined(__CUDACC__) || defined(__HIPCC__)

} // namespace gpu

#endif // GPU_SUPPORT_H

