#include "kernelgen.hpp"
#include "res_embed.h"

#include <iostream>
#include <pybind11/embed.h>
#include <pybind11/eval.h>
#include <pybind11/stl.h>

namespace py = pybind11;
using namespace pybind11::literals;

std::string KernelGen::generate(int nqubits, unsigned* ids)
{
	// Use embedded Python interpreter to run the script
	// and get the resulting string of source code.
	// We intentionally keep the generator in Python, in order
	// to let the people to customize it more easily.
	py::scoped_interpreter guard {};
	try
	{
		py::dict globals = py::globals();
		// Assign the __name__, otherwise it is set to "__main__" by default.
		globals["__name__"] = "kernelgen";
		py::eval<py::eval_statements>(nointrin, globals, globals);
		if (ids)
		{
			std::vector<unsigned> vids(nqubits);
			vids.assign(ids, ids + nqubits);
			auto source = globals["kernelgen"](nqubits, "ids"_a = vids).cast<std::string>();
			return source;
		}
		else
		{
			auto source = globals["kernelgen"](nqubits).cast<std::string>();
			return source;
		}
	}
	catch (pybind11::error_already_set e)
	{
		std::cerr << "Unable to invoke the Python script: " << e.what() << std::endl;
		exit(-1);
	}
}

namespace res {

namespace embed {

namespace init {

void nointrin();

} // namespace init

} // namespace embed

} // namespace res

KernelGen::KernelGen()
{
	// Extract the Python script.
	res::embed::init::nointrin();
	size_t size = 0;
	auto source = res::embed::get("nointrin", &size);
	nointrin = std::string(source, size);
}

