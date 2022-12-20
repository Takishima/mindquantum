include(check_code_compiles)

# ==============================================================================

check_code_compiles(
  compiler_has_std_filesystem
  CPPSIM_HAS_STD_FILESYSTEM
  cxx_std_17
  [[
#ifdef __has_include
# if __has_include(<version>)
#   include <version>
# endif
#endif
int main() {
#if __cpp_lib_filesystem >= 201703
    return 0;
#else
#error std::filesystem not supported
#endif
}
]])

# ==============================================================================
