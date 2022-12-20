#ifndef TEMP_FILE_H
#define TEMP_FILE_H

#include <string>

#if __has_include(<version>)
#  include <version>
#endif

#if __has_include(<filesystem>) && __cpp_lib_filesystem >= 201703
#include <filesystem>
#include <system_error>
namespace ec_ns = std;
namespace fs = std::filesystem;
#else
#include <boost/filesystem.hpp>
#include <boost/system/error_code.hpp>
namespace ec_ns = boost::system;
namespace fs = boost::filesystem;
#endif


class TempFile
{
        ec_ns::error_code ec;

	std::string filename;

public :

	const std::string& string(std::error_code& ec) const;

	TempFile(const std::string& mask);

	~TempFile();
};

#endif // TEMP_FILE_H

