# ~~~
# Generate some kernel functions
#
# kernelgen([COMBINATIONS]
#           [NQUBITS <n_qubits>]
#           [VARIANT <intrin>|<nointrin>]
#           [TARGET <target-name>]
# )
# ~~~
function(kernelgen)
  set(options COMBINATIONS)
  set(oneValueArgs NQUBITS VARIANT TARGET)
  cmake_parse_arguments(KERNELGEN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(NQUBITS ${KERNELGEN_NQUBITS})
  set(VARIANT ${KERNELGEN_VARIANT})
  if(NOT DEFINED CPPSIM_INCLUDE_DIR)
    set(CPPSIM_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)
  endif()
  set(KERNELGEN "${CPPSIM_INCLUDE_DIR}/${VARIANT}/kernelgen.py")
  set(KERNEL_PATH "${CMAKE_CURRENT_BINARY_DIR}/generated/${VARIANT}/kernel${NQUBITS}.hpp")

  if(NOT EXISTS "${KERNELGEN_PY}")
    message(FATAL_ERROR "Cannot locate kernelgen Python script: ${KERNELGEN_PY}")
  endif()

  set(_args)
  if(KERNELGEN_COMBINATIONS)
    list(APPEND _args --combinations=True)
  endif()

  # Call generator.
  add_custom_command(
    OUTPUT ${KERNEL_PATH}
    COMMAND ${Python_EXECUTABLE} ${KERNELGEN_PY} ${NQUBITS} ${KERNEL_PATH} ${_args}
    COMMENT "Generating kernel for ${NQUBITS} qubits"
    DEPENDS ${KERNELGEN_PY})
  set_source_files_properties("${KERNEL_PATH}" PROPERTIES GENERATED TRUE)

  # Append the generated file to the target sources.
  target_sources(${KERNELGEN_TARGET} PRIVATE ${KERNEL_PATH})
  target_include_directories(${KERNELGEN_TARGET} PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
  target_compile_features(${KERNELGEN_TARGET} PRIVATE cxx_std_17)
endfunction()
