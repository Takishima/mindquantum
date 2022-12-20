#include "tempfile.h"

#if __has_include(<unistd.h>)
#define HAS_UNISTD_H 1
#else
#define HAS_UNISTD_H 0
#endif

#include <cerrno>       // for errno
#include <cstdio>       // for std::remove
#include <cstdlib>      // for getenv, atoi
#include <iterator>     // for begin, end

#if HAS_UNISTD_H
#include <unistd.h>     // for close
#include <vector>       // for std::vector
#else
#include <algorithm>    // for std::generate_n
#include <cstdint>      // for uint32_t
#include <fstream>      // for ofstream
#include <string_view>  // for std::string_view
#include <random>       // for std::default_random_engine, etc.
#include <utility>      // for std::move
#endif // HAS_UNISTD_H

#if !HAS_UNISTD_H
namespace  {
     std::string create_temp_file(std::string template_str, ec_ns::error_code& ec) {
          static constexpr std::string_view chars =
               "0123456789"
               "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
               "abcdefghijklmnopqrstuvwxyz";
          thread_local std::random_device rd;
          thread_local auto rng = std::default_random_engine(rd());
          thread_local auto dist = std::uniform_int_distribution<uint32_t>{0U,
               static_cast<uint32_t>(chars.size())};

          auto dir = fs::temp_directory_path(ec);
          if (ec) return {};

          const auto size = template_str.size();

          for(unsigned int i(0); i < (62 * 62 * 62) /* same as mkstemp */; ++i) {
               std::generate_n(std::end(template_str)-6, 6, []() { return chars[dist(rng)]; });

               std::ofstream fout(template_str);
               if(fout)
               {
                    return template_str;
               }
          }

          ec = ec_ns::error_code(errno, ec_ns::generic_category());
          return {};
     }
}
#endif // !HAS_UNISTD_H

// =============================================================================

const std::string& TempFile::string(std::error_code& ec_) const
{
	ec_ = ec;
	return filename;
}

TempFile::TempFile(const std::string& mask_)
{
	auto dir = fs::temp_directory_path(ec);
	if (ec) return;

#if HAS_UNISTD_H
	std::string mask = (dir / mask_).string();

	std::vector<char> vfilename(mask.c_str(), mask.c_str() + mask.size() + 1);
	auto fd = mkstemp(&vfilename[0]);
	if (fd == -1)
	{
		ec = ec_ns::error_code(errno, ec_ns::generic_category());
		return;
	}

	close(fd);
	filename = std::string(begin(vfilename), end(vfilename));
#else
        auto fname = create_temp_file((dir / mask_).string(), ec);
	if (ec) return;

        filename = std::move(fname);
#endif // HAS_UNISTD_H
}

TempFile::~TempFile()
{
	bool keepCache = false;
	const char* keepCacheValue = std::getenv("KEEP_CACHE");
	if (keepCacheValue)
                keepCache = std::atoi(keepCacheValue);
	if (!keepCache)
                std::remove(filename.c_str());
}

