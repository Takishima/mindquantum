include(CheckCXXSourceCompiles)

# ~~~
# Check whether some C++ code compiles
#
# check_cxx_code_compiles(<lang> <cmake_identifier> <out-var> <lang_standard> <code> [<lang>, ...])
# ~~~
function(check_code_compiles cmake_identifier var lang_standard code)
  if(NOT "${ARGN}" STREQUAL "")
    set(_lang_list "${ARGN}")
  else()
    set(_lang_list CXX)
    if(_cuda_enabled)
      list(APPEND _lang_list CUDA)
    endif()
  endif()

  if(lang_standard MATCHES "std_([0-9]+)")
    set(CMAKE_CXX_STANDARD ${CMAKE_MATCH_1})
  endif()
  set(CMAKE_CXX_EXTENSIONS OFF)

  check_cxx_source_compiles("${code}" "${cmake_identifier}")

  set(${var}
      ${${cmake_identifier}}
      PARENT_SCOPE)

  set(${var} FALSE)
  if(${cmake_identifier})
    set(${var} TRUE)
  endif()
  set(${var}
      ${${var}}
      CACHE INTERNAL "${cmake_identifier}")
endfunction()
