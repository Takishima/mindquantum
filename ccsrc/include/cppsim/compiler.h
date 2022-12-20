#ifndef COMPILER_H
#define COMPILER_H

#include <string>

class Compiler
{
public :

	void* codegen(int nqubits, const std::string& source, std::string& errmsg);

	Compiler();

};

Compiler& get_compiler();

#endif // COMPILER_H

