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
# )
#
# Defines a new library target with the given target name, sources, and dependencies.
function(cc_library name)
  set(flag EXCLUDE_FROM_ALL)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(ccl "${flag}" "" "${multi}" ${ARGN})

  add_library(${name} ${ccl_SOURCES})
  add_objc_flags(${name} ccl)
  target_include_directories(
    ${name}
    PUBLIC
    ${FIREBASE_SOURCE_DIR}
    ${FIREBASE_BINARY_DIR}
  )
  target_link_libraries(${name} PUBLIC ${ccl_DEPENDS})

  if(ccl_EXCLUDE_FROM_ALL)
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

  add_executable(${name} ${cct_SOURCES})
  add_objc_flags(${name} cct)
  add_test(${name} ${name})

  target_include_directories(${name} PUBLIC ${FIREBASE_SOURCE_DIR})
  target_link_libraries(${name} ${cct_DEPENDS})
endfunction()

# add_objc_flags(target sources...)
#
# Adds OBJC_FLAGS to the compile options of the given target if any of the
# sources have filenames that indicate they are are Objective-C.
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
