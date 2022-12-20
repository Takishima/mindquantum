#ifndef CPPSIM_OMP_HPP
#define CPPSIM_OMP_HPP

#include <cstdint>

#if defined(_OPENMP)
#  include <omp.h>
#endif

namespace omp {
#ifdef _MSC_VER
using idx_t = int64_t;
#else
using idx_t = uint64_t;
#endif  // _MSC_VER
}  // namespace omp

#endif /* CPPSIM_OMP_HPP */
