#ifndef KERNELGEN_HPP
#define KERNELGEN_HPP

#include "compiler.h"

#include <iostream>
#include <string>

class KernelGen
{
	std::string nointrin;

public :

	std::string generate(int nqubits, unsigned* ids = nullptr);

	KernelGen();
};

// bit indices id[.] are given from high to low (e.g. control first for CNOT)
template <class V, class Id, class M>
void kernelgen(V &psi, Id& ids, M const& m, std::size_t ctrlmask)
{
	static KernelGen g;

	const auto nqubits = ids.size();

	// Generate the kernel source code.
	auto source = g.generate(nqubits, &ids[0]);
	
	// Compile the source code using external compiler.
	std::string errmsg;
	void* handle = get_compiler().codegen(nqubits, source, errmsg);
	if (!handle)
	{
		std::cerr << "Kernel generation has failed, aborting:" << std::endl;
		std::cerr << errmsg;
		exit(-1);
	}
	
	// Call the generated kernel.
	typedef void (*kernel_t)(void* /*psi*/, unsigned int* /*ids*/, const int* /*m*/, size_t /*ctrlmask*/);
	auto kernel = (kernel_t)handle;
	#pragma omp parallel
	kernel(reinterpret_cast<void*>(&psi[0]), &ids[0], reinterpret_cast<const int*>(&m[0][0]), ctrlmask);
}

#endif // KERNELGEN_HPP

