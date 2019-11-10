# Copyright 2017 Google
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

# cc_library(
#   target
#   SOURCES sources...
#   DEPENDS libraries...
#   [EXCLUDE_FROM_ALL]
# )
#
# Defines a new library target with the given target name, sources, and
# dependencies.
function(cc_library name)
  set(flag EXCLUDE_FROM_ALL HEADER_ONLY)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(ccl "${flag}" "" "${multi}" ${ARGN})

  if(ccl_HEADER_ONLY)
    generate_dummy_source(${name} ccl_SOURCES)
  endif()

  maybe_remove_objc_sources(sources ${ccl_SOURCES})
  add_library(${name} ${sources})
  add_objc_flags(${name} ${sources})
  target_include_directories(
    ${name}
    PUBLIC
    # Put the binary dir first so that the generated config.h trumps any one
    # generated statically by a Cocoapods-based build in the same source tree.
    ${FIREBASE_BINARY_DIR}
    ${FIREBASE_SOURCE_DIR}
  )

  target_link_libraries(${name} PUBLIC ${ccl_DEPENDS})

  if(ccl_EXCLUDE_FROM_ALL)
    set_property(
      TARGET ${name}
      PROPERTY EXCLUDE_FROM_ALL ON
    )
  endif()
endfunction()

# cc_select(
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
function(cc_select library_name)
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

# cc_binary(
#   target
#   SOURCES sources...
#   DEPENDS libraries...
#   [EXCLUDE_FROM_ALL]
# )
#
# Defines a new executable target with the given target name, sources, and
# dependencies.
function(cc_binary name)
  set(flag EXCLUDE_FROM_ALL)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(ccb "${flag}" "" "${multi}" ${ARGN})

  maybe_remove_objc_sources(sources ${ccb_SOURCES})
  add_executable(${name} ${sources})
  add_objc_flags(${name} ${sources})

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

# cc_test(
#   target
#   SOURCES sources...
#   DEPENDS libraries...
# )
#
# Defines a new test executable target with the given target name, sources, and
# dependencies.  Implicitly adds DEPENDS on GTest::GTest and GTest::Main.
function(cc_test name)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(cct "" "" "${multi}" ${ARGN})

  list(APPEND cct_DEPENDS GTest::GTest GTest::Main)

  maybe_remove_objc_sources(sources ${cct_SOURCES})
  add_executable(${name} ${sources})
  add_objc_flags(${name} ${sources})
  add_test(${name} ${name})

  target_compile_options(${name} PRIVATE ${FIREBASE_CXX_FLAGS})
  target_include_directories(${name} PRIVATE ${FIREBASE_SOURCE_DIR})
  target_link_libraries(${name} PRIVATE ${cct_DEPENDS})
endfunction()

# cc_fuzz_test(
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
function(cc_fuzz_test name)
  # Finds the fuzzer library that is either provided by OSS Fuzz or libFuzzer
  # that is manually built from sources.
  find_package(Fuzzer REQUIRED)

  # Parse arguments of the cc_fuzz_test macro.
  set(single DICTIONARY CORPUS)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(ccf "" "${single}" "${multi}" ${ARGN})

  list(APPEND ccf_DEPENDS Fuzzer)

  cc_binary(
    ${name}
    SOURCES ${ccf_SOURCES}
    DEPENDS ${ccf_DEPENDS}
  )

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
function(maybe_remove_objc_sources output_var)
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

# add_objc_flags(target sources...)
#
# Adds OBJC_FLAGS to the compile options of the given target if any of the
# sources have filenames that indicate they are Objective-C.
function(add_objc_flags target)
  set(_has_objc OFF)

  foreach(source ${ARGN})
    get_filename_component(ext ${source} EXT)
    if((ext STREQUAL ".m") OR (ext STREQUAL ".mm"))
      set(_has_objc ON)
    endif()
  endforeach()

  if(_has_objc)
    target_compile_options(
      ${target}
      PRIVATE
      ${OBJC_FLAGS}
    )

    target_link_libraries(
      ${target}
      PRIVATE
      "-framework Foundation"
    )
  endif()
endfunction()

# add_alias(alias_target actual_target)
#
# Adds a library alias target `alias_target` if it does not already exist,
# aliasing to the given `actual_target` target. This allows library dependencies
# to be specified uniformly in terms of the targets found in various
# find_package modules even if the library is being built internally.
function(add_alias ALIAS_TARGET ACTUAL_TARGET)
  if(NOT TARGET ${ALIAS_TARGET})
    add_library(${ALIAS_TARGET} ALIAS ${ACTUAL_TARGET})
  endif()
endfunction()

# objc_framework(
#   target
#   HEADERS headers...
#   SOURCES sources...
#   INCLUDES inlude_directories...
#   DEFINES macros...
#   DEPENDS libraries...
#   [EXCLUDE_FROM_ALL]
# )
#
# Defines a new framework target with the given target name and parameters.
#
# If SOURCES is not included, a dummy file will be generated.
function(objc_framework target)
  if(APPLE)
    set(flag EXCLUDE_FROM_ALL)
    set(single VERSION)
    set(multi DEPENDS DEFINES HEADERS INCLUDES SOURCES)
    cmake_parse_arguments(of "${flag}" "${single}" "${multi}" ${ARGN})

    podspec_prep_headers(${target} ${of_HEADERS})

    if (NOT cf_SOURCES)
      generate_dummy_source(${target} of_SOURCES)
    endif()

    add_library(
      ${target}
      STATIC
      ${of_HEADERS}
      ${of_SOURCES}
    )

    add_objc_flags(${target} ${of_SOURCES})

    set_property(TARGET ${target} PROPERTY PUBLIC_HEADER ${of_HEADERS})
    set_property(TARGET ${target} PROPERTY FRAMEWORK ON)
    set_property(TARGET ${target} PROPERTY VERSION ${of_VERSION})

    if(of_EXCLUDE_FROM_ALL)
      set_property(TARGET ${name} PROPERTY EXCLUDE_FROM_ALL ON)
    endif()

    target_compile_definitions(
      ${target}
      PUBLIC
        ${of_DEFINES}
    )

    target_compile_options(
      ${target}
      INTERFACE
        -F${CMAKE_CURRENT_BINARY_DIR}
      PRIVATE
        ${OBJC_FLAGS}
        -fno-autolink
        -Wno-unused-parameter
    )

    target_include_directories(
      ${target}
      PUBLIC ${PROJECT_BINARY_DIR}/Headers
      PRIVATE ${of_INCLUDES}
    )

    target_link_libraries(
      ${target} PUBLIC
      ${of_DEPENDS}
    )
  endif()
endfunction()

# generate_dummy_source(name, sources_list)
#
# Generates a dummy source file containing a single symbol, suitable for use as
# a source file in when defining a header-only library.
#
# Appends the generated source file name to the list named by sources_list.
macro(generate_dummy_source name sources_list)
  set(__empty_header_only_file "${CMAKE_CURRENT_BINARY_DIR}/${name}_header_only_empty.c")

  if(NOT EXISTS ${__empty_header_only_file})
    file(WRITE ${__empty_header_only_file}
      "// Generated file that keeps header-only CMake libraries happy.

      // single meaningless symbol
      void ${name}_header_only_fakesym(void) {}
      "
    )
  endif()

  list(APPEND ${sources_list} ${__empty_header_only_file})
endmacro()
