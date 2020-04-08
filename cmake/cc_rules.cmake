# Copyright 2017 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include(CMakeParseArguments)
include(FindASANDylib)


# firebase_ios_add_executable(
#   target
#   sources...
# )
#
# Wraps a call to add_executable (including arguments like EXCLUDE_FROM_ALL)
# that additionally sets common options that apply to all executables in this
# repo.
function(firebase_ios_add_executable target)
  firebase_ios_split_target_options(flag ${ARGN})

  add_executable(${target} ${flag_REST})
  firebase_ios_set_common_target_options(${target} ${flag_OPTIONS})
endfunction()

# firebase_ios_add_library(
#   target
#   sources...
# )
#
# Wraps a call to add_library (including any arguments like EXCLUDE_FROM_ALL)
# that additionally sets common options that apply to all libraries in this
# repo.
function(firebase_ios_add_library target)
  firebase_ios_split_target_options(flag ${ARGN})

  add_library(${target} ${flag_REST})
  firebase_ios_set_common_target_options(${target} ${flag_OPTIONS})
endfunction()

# firebase_ios_add_framework(
#   target
#   sources...
# )
#
# Wraps a call to add_library (including arguments like EXCLUDE_FROM_ALL) that
# additionally sets common options that apply to all frameworks in this repo.
#
# Note that this does not build an actual framework bundle--even recent versions
# of CMake (3.15.5 as of this writing) produce problematic output when
# frameworks are enabled. However `firebase_ios_add_framework` along with
# `firebase_ios_framework_public_headers` produces a library target that
# can be compiled against as if it *were* a framework. Notably, imports of the
# form #import <Framework/Framework.h> and public headers that refer to each
# other unqualified will work.
function(firebase_ios_add_framework target)
  firebase_ios_split_target_options(flag ${ARGN})

  add_library(${target} ${flag_REST})
  firebase_ios_set_common_target_options(${target} ${flag_OPTIONS})

  target_link_libraries(${target} INTERFACE -ObjC)
endfunction()

# firebase_ios_framework_public_headers(
#   target
#   headers...
# )
#
# Prepares the given headers for use as public headers of the given target.
# This emulates CocoaPods behavior of flattening public headers by creating
# a separate directory tree in the build output, consisting of symbolic links to
# the actual header files. This makes it possible to use imports of these forms:
#
#   * #import <Framework/Header.h>
#   * #import "Header.h"
function(firebase_ios_framework_public_headers target)
  target_sources(${target} PRIVATE ${ARGN})

  podspec_prep_headers(${target} ${ARGN})
  target_include_directories(
    ${target}

    # ${target} is a subdirectory, making <Framework/Header.h> work.
    PUBLIC ${PROJECT_BINARY_DIR}/Headers

    # Make unqualified imports work too, often needed for peer imports from
    # one public header to another.
    PUBLIC ${PROJECT_BINARY_DIR}/Headers/${target}
  )
endfunction()

# firebase_ios_add_test(
#   target
#   sources...
# )
#
# Wraps a call to `add_executable` (including arguments like `EXCLUDE_FROM_ALL`)
# and `add_test` that additionally sets common options that apply to all tests
# in this repo.
#
# Also adds dependencies on GTest::GTest and GTest::Main.
function(firebase_ios_add_test target)
  firebase_ios_split_target_options(flag ${ARGN})

  add_executable(${target} ${flag_REST})
  add_test(${target} ${target})

  firebase_ios_set_common_target_options(${target} ${flag_OPTIONS})

  target_link_libraries(${target} PRIVATE GTest::GTest GTest::Main)
endfunction()

# firebase_ios_add_objc_test(
#   target
#   host_app
#   sources...
# )
#
# Creates an XCTest bundle suitable for running tests written in Objective-C by
# wrapping a call to `xctest_add_bundle` (including arguments like
# `EXCLUDE_FROM_ALL`) and `xctest_add_test` that additionally sets common
# options that apply to all tests in this repo.
function(firebase_ios_add_objc_test target host)
  xctest_add_bundle(${target} ${host} ${ARGN})

  firebase_ios_set_common_target_options(${target})

  xctest_add_test(${target} ${target})

  if(WITH_ASAN)
    set_property(
      TEST ${target} APPEND PROPERTY
      ENVIRONMENT DYLD_INSERT_LIBRARIES=${CLANG_ASAN_DYLIB}
    )
  endif()

  if(WITH_TSAN)
    set_property(
      TEST ${target} APPEND PROPERTY
      ENVIRONMENT DYLD_INSERT_LIBRARIES=${CLANG_TSAN_DYLIB}
    )
  endif()
endfunction()


# firebase_ios_cc_library(
#   target
#   SOURCES sources...
#   DEPENDS libraries...
#   [EXCLUDE_FROM_ALL]
# )
#
# Defines a new library target with the given target name, sources, and
# dependencies.
function(firebase_ios_cc_library name)
  set(flag DISABLE_STRICT_WARNINGS EXCLUDE_FROM_ALL HEADER_ONLY)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(ccl "${flag}" "" "${multi}" ${ARGN})

  if(ccl_HEADER_ONLY)
    firebase_ios_generate_dummy_source(${name} ccl_SOURCES)
  endif()

  firebase_ios_maybe_remove_objc_sources(sources ${ccl_SOURCES})
  add_library(${name} ${sources})

  set(warnings_flag "")
  if(ccl_DISABLE_STRICT_WARNINGS)
    set(warnings_flag DISABLE_STRICT_WARNINGS)
  endif()
  firebase_ios_add_compile_options(${name} ${warnings_flag} ${sources})

  target_compile_options(${name} PRIVATE ${FIREBASE_IOS_CXX_FLAGS})
  target_link_libraries(${name} PUBLIC ${ccl_DEPENDS})

  if(ccl_EXCLUDE_FROM_ALL)
    set_property(
      TARGET ${name}
      PROPERTY EXCLUDE_FROM_ALL ON
    )
  endif()
endfunction()

# firebase_ios_cc_select(
#   interface_library
#   CONDITION1 implementation_library1
#   [CONDITION2 implementation_library2 ...]
#   [DEFAULT implementation_library_default]
# )
#
# Creates an INTERFACE library named `interface_library`.
#
# For each pair of condition and implementation_library, evaluates the condition
# and if true makes that library an INTERFACE link library of
# `interface_library`.
#
# If supplied, uses the `DEFAULT` implementation if no other condition matches.
#
# If no condition matches, fails the configuration cycle with an error message
# indicating that no suitable implementation was found.
function(firebase_ios_cc_select library_name)
  add_library(${library_name} INTERFACE)

  list(LENGTH ARGN length)
  if(length GREATER 0)
    math(EXPR length "${length} - 1")
    foreach(key RANGE 0 ${length} 2)
      math(EXPR value "${key} + 1")
      list(GET ARGN ${key} condition)
      list(GET ARGN ${value} impl_library)

      if((${condition} STREQUAL "DEFAULT") OR (${${condition}}))
        message("Using ${library_name} = ${impl_library}")
        target_link_libraries(
          ${library_name} INTERFACE ${impl_library}
        )
        return()
      endif()
    endforeach()
  endif()

  message(FATAL_ERROR "Could not find implementation for ${library_name}")
endfunction()

# firebase_ios_cc_binary(
#   target
#   SOURCES sources...
#   DEPENDS libraries...
#   [EXCLUDE_FROM_ALL]
# )
#
# Defines a new executable target with the given target name, sources, and
# dependencies.
function(firebase_ios_cc_binary name)
  set(flag DISABLE_STRICT_WARNINGS EXCLUDE_FROM_ALL)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(ccb "${flag}" "" "${multi}" ${ARGN})

  firebase_ios_maybe_remove_objc_sources(sources ${ccb_SOURCES})
  add_executable(${name} ${sources})

  set(warnings_flag "")
  if(ccb_DISABLE_STRICT_WARNINGS)
    set(warnings_flag DISABLE_STRICT_WARNINGS)
  endif()
  firebase_ios_add_compile_options(${name} ${warnings_flag} ${sources})

  target_compile_options(${name} PRIVATE ${FIREBASE_CXX_FLAGS})
  target_include_directories(${name} PRIVATE ${FIREBASE_SOURCE_DIR})
  target_link_libraries(${name} PRIVATE ${ccb_DEPENDS})

  if(ccb_EXCLUDE_FROM_ALL)
    set_property(
      TARGET ${name}
      PROPERTY EXCLUDE_FROM_ALL ON
    )
  endif()
endfunction()

# firebase_ios_cc_test(
#   target
#   SOURCES sources...
#   DEPENDS libraries...
# )
#
# Defines a new test executable target with the given target name, sources, and
# dependencies.  Implicitly adds DEPENDS on GTest::GTest and GTest::Main.
function(firebase_ios_cc_test name)
  if(NOT FIREBASE_IOS_BUILD_TESTS)
    return()
  endif()

  set(flag DISABLE_STRICT_WARNINGS)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(cct "${flag}" "" "${multi}" ${ARGN})

  list(APPEND cct_DEPENDS GTest::GTest GTest::Main)

  firebase_ios_maybe_remove_objc_sources(sources ${cct_SOURCES})
  add_executable(${name} ${sources})

  set(warnings_flag "")
  if(cct_DISABLE_STRICT_WARNINGS)
    set(warnings_flag DISABLE_STRICT_WARNINGS)
  endif()
  firebase_ios_add_compile_options(${name} ${warnings_flag} ${sources})

  add_test(${name} ${name})

  target_compile_options(${name} PRIVATE ${FIREBASE_CXX_FLAGS})
  target_include_directories(${name} PRIVATE ${FIREBASE_SOURCE_DIR})
  target_link_libraries(${name} PRIVATE ${cct_DEPENDS})
endfunction()

# firebase_ios_cc_fuzz_test(
#   target
#   DICTIONARY dict_file
#   CORPUS     corpus_dir
#   SOURCES    sources...
#   DEPENDS    libraries...
# )
#
# Defines a new executable fuzz testing target with the given target name,
# (optional) dictionary file, (optional) corpus directory, sources, and
# dependencies. Implicitly adds DEPENDS on 'Fuzzer', which corresponds to
# libFuzzer if fuzzing runs locally or a provided fuzzing library if fuzzing
# runs on OSS Fuzz. If provided, copies the DICTIONARY file as '${target}.dict'
# and copies the CORPUS directory as '${target}_seed_corpus' after building the
# target. This naming convention is critical for OSS Fuzz build script to
# capture new fuzzing targets.
function(firebase_ios_cc_fuzz_test name)
  # Finds the fuzzer library that is either provided by OSS Fuzz or libFuzzer
  # that is manually built from sources.
  find_package(Fuzzer REQUIRED)

  # Parse arguments of the firebase_ios_cc_fuzz_test macro.
  set(single DICTIONARY CORPUS)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(ccf "" "${single}" "${multi}" ${ARGN})

  list(APPEND ccf_DEPENDS Fuzzer)

  firebase_ios_cc_binary(
    ${name}
    SOURCES ${ccf_SOURCES}
    DEPENDS ${ccf_DEPENDS}
  )

  target_compile_options(${name} PRIVATE ${FIREBASE_CXX_FLAGS})

  # Copy the dictionary file and corpus directory, if they are defined.
  if(DEFINED ccf_DICTIONARY)
    add_custom_command(
      TARGET ${name} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy
          ${ccf_DICTIONARY} ${name}.dict
    )
  endif()
  if(DEFINED ccf_CORPUS)
    add_custom_command(
      TARGET ${name} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_directory
          ${ccf_CORPUS} ${name}_seed_corpus
    )
  endif()
endfunction()

# maybe_remove_objc_sources(output_var sources...)
#
# Removes Objective-C/C++ sources from the given sources if not on an Apple
# platform. Stores the resulting list in the variable named by `output_var`.
function(firebase_ios_maybe_remove_objc_sources output_var)
  unset(sources)
  foreach(source ${ARGN})
    get_filename_component(ext ${source} EXT)
    if(NOT APPLE AND ((ext STREQUAL ".m") OR (ext STREQUAL ".mm")))
      continue()
    endif()
    list(APPEND sources ${source})
  endforeach()
  set(${output_var} ${sources} PARENT_SCOPE)
endfunction()

# firebase_ios_add_compile_options(target [DISABLE_STRICT_WARNINGS] sources...)
#
# Adds FIREBASE_IOS_CXX_FLAGS or FIREBASE_IOS_CXX_FLAGS_STRICT to the compile
# options of the given target depending on whether or not
# DISABLE_STRICT_WARNINGS was passed.
#
# If any of the sources have filenames that indicate they are Objective-C adds
# Either FIREBASE_IOS_OBJC_FLAGS or FIREBASE_IOS_OBJC_FLAGS_STRICT depending on
# whether or not DISABLE_STRICT_WARNINGS was passed.
function(firebase_ios_add_compile_options target)
  set(flag DISABLE_STRICT_WARNINGS)
  cmake_parse_arguments(aco "${flag}" "" "" ${ARGN})

  # Only set Objective-C flags if there's at least once source file to which
  # that applies.
  set(has_objc OFF)

  # Default to applying the strict warnings to all targets, but targets can
  # opt out.
  set(suffix _STRICT)
  if(aco_DISABLE_STRICT_WARNINGS)
    set(suffix "")
  endif()

  foreach(source ${ARGN})
    get_filename_component(ext ${source} EXT)
    if((ext STREQUAL ".m") OR (ext STREQUAL ".mm"))
      set(has_objc ON)
    endif()
  endforeach()

  target_compile_options(
    ${target}
    PRIVATE
    ${FIREBASE_IOS_CXX_FLAGS${suffix}}
  )

  if(has_objc)
    target_compile_options(
      ${target}
      PRIVATE
      ${FIREBASE_IOS_OBJC_FLAGS${suffix}}
    )
  endif()

  target_include_directories(
    ${target}
    PRIVATE
    # Put the binary dir first so that the generated config.h trumps any one
    # generated statically by a Cocoapods-based build in the same source tree.
    ${FIREBASE_BINARY_DIR}
    ${FIREBASE_SOURCE_DIR}
  )
endfunction()

# firebase_ios_add_alias(alias_target actual_target)
#
# Adds a library alias target `alias_target` if it does not already exist,
# aliasing to the given `actual_target` target. This allows library dependencies
# to be specified uniformly in terms of the targets found in various
# find_package modules even if the library is being built internally.
function(firebase_ios_add_alias ALIAS_TARGET ACTUAL_TARGET)
  if(NOT TARGET ${ALIAS_TARGET})
    add_library(${ALIAS_TARGET} ALIAS ${ACTUAL_TARGET})
  endif()
endfunction()

function(firebase_ios_objc_test target)
  if(NOT APPLE OR NOT FIREBASE_IOS_BUILD_TESTS)
    return()
  endif()

  set(flag DISABLE_STRICT_WARNINGS EXCLUDE_FROM_ALL)
  set(single HOST VERSION WORKING_DIRECTORY)
  set(multi DEPENDS DEFINES HEADERS INCLUDES SOURCES)
  cmake_parse_arguments(ot "${flag}" "${single}" "${multi}" ${ARGN})

  xctest_add_bundle(
    ${target}
    ${ot_HOST}
    ${ot_SOURCES}
  )

  set(warnings_flag "")
  if(ot_DISABLE_STRICT_WARNINGS)
    set(warnings_flag DISABLE_STRICT_WARNINGS)
  endif()
  firebase_ios_add_compile_options(${target} ${warnings_flag} ${ot_SOURCES})

  target_compile_options(${target} PRIVATE ${FIREBASE_CXX_FLAGS})
  target_link_libraries(${target} PRIVATE ${ot_DEPENDS})

  xctest_add_test(
    ${target}
    ${target}
  )

  if(ot_WORKING_DIRECTORY)
    set_property(
      TEST ${target} PROPERTY
      WORKING_DIRECTORY ${ot_WORKING_DIRECTORY}
    )
  endif()

  if(WITH_ASAN)
    set_property(
      TEST ${target} APPEND PROPERTY
      ENVIRONMENT
      DYLD_INSERT_LIBRARIES=${CLANG_ASAN_DYLIB}
    )
  endif()

  if(WITH_TSAN)
    set_property(
      TEST ${target} APPEND PROPERTY
      ENVIRONMENT
      DYLD_INSERT_LIBRARIES=${CLANG_TSAN_DYLIB}
    )
  endif()
endfunction()

# firebase_ios_generate_dummy_source(target, sources_list)
#
# Generates a dummy source file containing a single symbol, suitable for use as
# a source file in when defining a header-only library.
#
# Appends the generated source file target to the list named by sources_list.
macro(firebase_ios_generate_dummy_source target sources_list)
  set(
    __empty_header_only_file
    "${CMAKE_CURRENT_BINARY_DIR}/${target}_header_only_empty.cc"
  )

  if(NOT EXISTS ${__empty_header_only_file})
    file(WRITE ${__empty_header_only_file}
      "// Generated file that keeps header-only CMake libraries happy.

      // single meaningless symbol
      void ${target}_header_only_fakesym() {}
      "
    )
  endif()

  list(APPEND ${sources_list} ${__empty_header_only_file})
endmacro()

# Splits the given arguments into two lists: those suitable for passing to
# `firebase_ios_set_common_target_options` and everything else, usually passed
# to `add_library`, `add_executable`, or similar.
#
# The resulting lists are set in the parent scope as `${prefix}_OPTIONS` for use
# when calling `firebase_ios_set_common_target_options`, and `${prefix}_REST`
# that contains any arguments that were unrecognized.
#
# See `firebase_ios_set_common_target_options` for details on which arguments
# are split out.
function(firebase_ios_split_target_options prefix)
  set(option_names DISABLE_STRICT_WARNINGS)

  set(${prefix}_OPTIONS)
  set(${prefix}_REST)

  foreach(arg ${ARGN})
    list(FIND option_names ${arg} option_index)
    if(NOT option_index EQUAL -1)
      list(APPEND ${prefix}_OPTIONS ${arg})
    else()
      list(APPEND ${prefix}_REST ${arg})
    endif()
  endforeach()

  set(${prefix}_OPTIONS ${${prefix}_OPTIONS} PARENT_SCOPE)
  set(${prefix}_REST ${${prefix}_REST} PARENT_SCOPE)
endfunction()

# Sets common options for a given target. This includes:
#
#   * `DISABLE_STRICT_WARNINGS`: disables stricter warnings usually applied to
#     targets in this repo. Use this to compile code that's local but doesn't
#     hold itself to Firestore's warning strictness.
#
# All other arguments are ignored.
function(firebase_ios_set_common_target_options target)
  set(bool DISABLE_STRICT_WARNINGS)
  cmake_parse_arguments(flag "${bool}" "" "" ${ARGN})

  set(suffix _STRICT)
  if(flag_DISABLE_STRICT_WARNINGS)
    set(suffix "")
  endif()

  target_compile_options(${target} PRIVATE ${FIREBASE_IOS_CXX_FLAGS${suffix}})
  if(APPLE)
    target_compile_options(
      ${target} PRIVATE ${FIREBASE_IOS_OBJC_FLAGS${suffix}}
    )
  endif()

  target_include_directories(
    ${target} PRIVATE
    # Put the binary dir first so that the generated config.h trumps any one
    # generated statically by a Cocoapods-based build in the same source tree.
    ${PROJECT_BINARY_DIR}
    ${PROJECT_SOURCE_DIR}
  )
endfunction()

# firebase_ios_glob(
#   list_variable
#   [APPEND]
#   [globs...]
#   [EXCLUDE globs...]
#   [INCLUDE globs...]
# )
#
# Applies globbing rules, accumulating a list of matching files, and sets the
# result to list_variable in the parent scope.
#
# If APPEND is specified, the result will start with any existing values in the
# list_variable. Otherwise, the list_variable will be overwritten with only the
# matches of this invocation.
#
# EXCLUDE and INCLUDE change the direction of the match. EXCLUDE will subtract
# files matching the glob patterns from the result. INCLUDE will again add
# files matching the glob patterns to the result. These can be used sequentially
# to finely tune the match.
#
# As a special case, if invoked with EXCLUDE in the first argument position,
# this is treated as if APPEND had been passed. This makes the common case of
# subtracting something from the list less prone to error. That is, these two
# invocations are equivalent:
#
#     firebase_ios_glob(sources APPEND EXCLUDE *.h)
#     firebase_ios_glob(sources EXCLUDE *.h)
#
# Without this exception, the second form would always end up an empty list and
# would never be useful.
function(firebase_ios_glob list_variable)
  set(result)
  set(list_op APPEND)
  set(first_arg TRUE)

  foreach(arg IN LISTS ARGN)
    if(arg STREQUAL "APPEND")
      list(APPEND result ${${list_variable}})
    elseif(arg STREQUAL "INCLUDE")
      set(list_op APPEND)
    elseif(arg STREQUAL "EXCLUDE")
      if(first_arg)
        list(APPEND result ${${list_variable}})
      endif()
      set(list_op REMOVE_ITEM)
    else()
      # Anything else is a glob pattern. Match the pattern and perform the list
      # operation implied by the current INCLUDE or EXCLUDE mode.
      file(GLOB matched ${arg})
      list(${list_op} result ${matched})
    endif()

    set(first_arg FALSE)
  endforeach()

  set(${list_variable} ${result} PARENT_SCOPE)
endfunction()
