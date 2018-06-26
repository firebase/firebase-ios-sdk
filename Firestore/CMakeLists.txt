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

option(WITH_ASAN "Build with Address Sanitizer" OFF)
# TODO(varconst): msan
# Memory sanitizer is more complicated:
# - it requires all dependencies to be compiled with msan enabled (see
#   https://github.com/google/sanitizers/wiki/MemorySanitizerLibcxxHowTo);
# - AppleClang doesn't support it.
option(WITH_TSAN "Build with Thread Sanitizer (mutually exculsive with other sanitizers)" OFF)
option(WITH_UBSAN "Build with Undefined Behavior sanitizer" OFF)

macro(add_to_compile_and_link_flags flag)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${flag}")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${flag}")
endmacro()

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  if(WITH_ASAN)
    add_to_compile_and_link_flags("-fsanitize=address")
  endif()

  if(WITH_TSAN)
    if(WITH_ASAN OR WITH_UBSAN)
      message(FATAL_ERROR "Cannot combine TSan with other santizers")
    endif()
    add_to_compile_and_link_flags("-fsanitize=thread")
  endif()

  if(WITH_UBSAN)
    add_to_compile_and_link_flags("-fsanitize=undefined")
  endif()

  if (WITH_ASAN OR WITH_TSAN OR WITH_UBSAN)
    # Recommended to "get nicer stack traces in error messages"
    # TODO(varconst): double-check that TSan actually needs this flag (it's
    # explicitly recommended in the docs for ASan and UBSan)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-omit-frame-pointer")
  endif()
else()
  if(WITH_ASAN OR WITH_TSAN OR WITH_UBSAN)
    message(FATAL_ERROR "Only Clang and GCC support sanitizers")
  endif()
endif()

set(FIREBASE_SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/..)

# CMAKE_INSTALL_PREFIX should be passed in to this build so that it can find
# outputs of the superbuild. This is handled automatically if run via the
# superbuild (i.e. by invoking cmake on the directory above this).
#
# If you want to use this project directly in e.g. CLion, make sure you
# configure this.
#
# The superbuild passes CMAKE_INSTALL_PREFIX with a value of
# ${FIREBASE_INSTALL_DIR} which is ${PROJECT_BINARY_DIR}/opt.
set(FIREBASE_INSTALL_DIR ${CMAKE_INSTALL_PREFIX})

# Expect that the source and binary directory structures will parallel each
# other.
set(FIREBASE_BINARY_DIR ${PROJECT_BINARY_DIR}/..)

list(INSERT CMAKE_MODULE_PATH 0 ${FIREBASE_SOURCE_DIR}/cmake)
include(utils)

find_package(GTest REQUIRED)
find_package(GMock REQUIRED)
find_package(LevelDB REQUIRED)
find_package(Nanopb REQUIRED)
find_package(Protobuf REQUIRED)
find_package(GRPC REQUIRED)

if(APPLE)
  find_package(FirebaseCore REQUIRED)
endif()

enable_testing()
add_subdirectory(third_party/abseil-cpp)

include(CompilerSetup)

# Superbuild installed results
include_directories(${FIREBASE_INSTALL_DIR}/include)

# Generated sources will be relative to the binary directory.
include_directories(${FIREBASE_BINARY_DIR})

# Fully qualified imports, project wide
include_directories(${FIREBASE_SOURCE_DIR})

add_subdirectory(core)
add_subdirectory(Protos)
