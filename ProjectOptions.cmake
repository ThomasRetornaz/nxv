include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(nxv_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(nxv_setup_options)
  option(nxv_ENABLE_HARDENING "Enable hardening" ON)
  option(nxv_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    nxv_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    nxv_ENABLE_HARDENING
    OFF)

  nxv_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR nxv_PACKAGING_MAINTAINER_MODE)
    option(nxv_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(nxv_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(nxv_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(nxv_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(nxv_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(nxv_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(nxv_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(nxv_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(nxv_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(nxv_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(nxv_ENABLE_PCH "Enable precompiled headers" OFF)
    option(nxv_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(nxv_ENABLE_IPO "Enable IPO/LTO" ON)
    option(nxv_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(nxv_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(nxv_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(nxv_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(nxv_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(nxv_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(nxv_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(nxv_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(nxv_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(nxv_ENABLE_PCH "Enable precompiled headers" OFF)
    option(nxv_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      nxv_ENABLE_IPO
      nxv_WARNINGS_AS_ERRORS
      nxv_ENABLE_SANITIZER_ADDRESS
      nxv_ENABLE_SANITIZER_LEAK
      nxv_ENABLE_SANITIZER_UNDEFINED
      nxv_ENABLE_SANITIZER_THREAD
      nxv_ENABLE_SANITIZER_MEMORY
      nxv_ENABLE_UNITY_BUILD
      nxv_ENABLE_CLANG_TIDY
      nxv_ENABLE_CPPCHECK
      nxv_ENABLE_COVERAGE
      nxv_ENABLE_PCH
      nxv_ENABLE_CACHE)
  endif()

  nxv_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (nxv_ENABLE_SANITIZER_ADDRESS OR nxv_ENABLE_SANITIZER_THREAD OR nxv_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(nxv_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(nxv_global_options)
  if(nxv_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    nxv_enable_ipo()
  endif()

  nxv_supports_sanitizers()

  if(nxv_ENABLE_HARDENING AND nxv_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR nxv_ENABLE_SANITIZER_UNDEFINED
       OR nxv_ENABLE_SANITIZER_ADDRESS
       OR nxv_ENABLE_SANITIZER_THREAD
       OR nxv_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${nxv_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${nxv_ENABLE_SANITIZER_UNDEFINED}")
    nxv_enable_hardening(nxv_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(nxv_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(nxv_warnings INTERFACE)
  add_library(nxv_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  nxv_set_project_warnings(
    nxv_warnings
    ${nxv_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    nxv_enable_sanitizers(
      nxv_options
      ${nxv_ENABLE_SANITIZER_ADDRESS}
      ${nxv_ENABLE_SANITIZER_LEAK}
      ${nxv_ENABLE_SANITIZER_UNDEFINED}
      ${nxv_ENABLE_SANITIZER_THREAD}
      ${nxv_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(nxv_options PROPERTIES UNITY_BUILD ${nxv_ENABLE_UNITY_BUILD})

  if(nxv_ENABLE_PCH)
    target_precompile_headers(
      nxv_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(nxv_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    nxv_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(nxv_ENABLE_CLANG_TIDY)
    nxv_enable_clang_tidy(nxv_options ${nxv_WARNINGS_AS_ERRORS})
  endif()

  if(nxv_ENABLE_CPPCHECK)
    nxv_enable_cppcheck(${nxv_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(nxv_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    nxv_enable_coverage(nxv_options)
  endif()

  if(nxv_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(nxv_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(nxv_ENABLE_HARDENING AND NOT nxv_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR nxv_ENABLE_SANITIZER_UNDEFINED
       OR nxv_ENABLE_SANITIZER_ADDRESS
       OR nxv_ENABLE_SANITIZER_THREAD
       OR nxv_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    nxv_enable_hardening(nxv_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
