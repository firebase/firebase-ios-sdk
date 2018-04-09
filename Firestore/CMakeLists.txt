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

cmake_minimum_required(VERSION 2.8.11)
project(firestore C CXX)

option(ASAN "Build with Address sanitizer (mutually exculsive with TSAN)" OFF)
# TODO(varconst): msan
# Memory sanitizer is more complicated:
# - it requires all dependencies to be compiled with msan enabled (see
#   https://github.com/google/sanitizers/wiki/MemorySanitizerLibcxxHowTo);
# - AppleClang doesn't support it.
option(TSAN "Build with Thread sanitizer (mutually exculsive with ASAN)" OFF)
option(UBSAN "Build with Undefined behavior sanitizer" OFF)

if (CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set(HAVE_SANITIZERS 1)
endif()
if(ASAN OR TSAN OR UBSAN)
  set(USE_SANITIZERS 1)
endif()

if (NOT HAVE_SANITIZERS AND USE_SANITIZERS)
  message(FATAL_ERROR "Only Clang and GCC support sanitizers.")
endif()

function(add_to_compile_and_link_flags flag)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${flag}")
  set(CMAKE_LINKER_FLAGS "${CMAKE_LINKER_FLAGS} ${flag}")
  message("${flag}")
endfunction()

if (HAVE_SANITIZERS AND USE_SANITIZERS)
  if ((ASAN AND TSAN) OR (UBSAN AND TSAN))
    message(FATAL_ERROR "You cannot combine sanitizers except asan and ubsan.")
  endif()

  # Recommended to "get nicer stack traces in error messages"
  # TODO(varconst): double-check that tsan actually needs this flag (it's
  # explicitly recommended in the docs for asan and ubsan)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-omit-frame-pointer")

  if (TSAN)
    add_to_compile_and_link_flags("-fsanitize=thread")
  else()
    if (ASAN)
      add_to_compile_and_link_flags("-fsanitize=address")
    endif()
    if (UBSAN)
      add_to_compile_and_link_flags("-fsanitize=undefined")
    endif()
  endif()
endif()

set(FIREBASE_SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/..)

# CMAKE_INSTALL_PREFIX should be passed in to this build so that it can find
# outputs of the superbuild. This is handled automatically if run via the
# superbuild (i.e. by invoking cmake on the directory above this).
#
# If you want to use this project directly in e.g. CLion, make sure you
# configure this.
set(FIREBASE_INSTALL_DIR ${CMAKE_INSTALL_PREFIX})

list(INSERT CMAKE_MODULE_PATH 0 ${FIREBASE_SOURCE_DIR}/cmake)
include(utils)

# Include GoogleTest directly in the build.
set(gtest_dir ${FIREBASE_INSTALL_DIR}/external/googletest)
add_subdirectory(
  ${gtest_dir}/src/googletest
  ${gtest_dir}/src/googletest-build
  EXCLUDE_FROM_ALL
)

# Set up aliases with the same names as available via FindGTest.
add_library(
  GTest::GTest ALIAS gtest
)

add_library(
  GTest::Main ALIAS gtest_main
)

find_package(LevelDB REQUIRED)
find_package(GRPC REQUIRED)
find_package(Nanopb REQUIRED)

if(APPLE)
  find_package(FirebaseCore REQUIRED)
endif()

enable_testing()
add_subdirectory(third_party/abseil-cpp)

include(CompilerSetup)

# Generated sources will be relative to the binary directory.
include_directories(${FIREBASE_INSTALL_DIR})

# Fully qualified imports, project wide
include_directories(${FIREBASE_SOURCE_DIR})

add_subdirectory(core)
add_subdirectory(Protos)
