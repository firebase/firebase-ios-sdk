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

# Superbuild for Firebase

cmake_minimum_required(VERSION 3.5.1)

# Disallow mixing keyword and non-keyword forms of target_link_libraries
if(POLICY CMP0023)
  cmake_policy(SET CMP0023 NEW)
endif()

# Report AppleClang separately from Clang. Their version numbers are different.
# https://cmake.org/cmake/help/v3.0/policy/CMP0025.html
if(POLICY CMP0025)
  cmake_policy(SET CMP0025 NEW)
endif()

# Enable rpath by default
if(POLICY CMP0042)
  cmake_policy(SET CMP0042 NEW)
endif()

# Generate Ninja phony rules for unknown dependencies in the build tree and
# don't complain about doing so. Our dependencies aren't good about declaring
# BYPRODUCTS and we mix them all into a single superbuild so we can't enable
# this policy until all dependencies are capable of doing so.
if(POLICY CMP0058)
  cmake_policy(SET CMP0058 OLD)
endif()

# Enable the ccache compilation cache, if available.
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
  message(STATUS "Found ccache: ${CCACHE_PROGRAM}")
  set(CMAKE_C_COMPILER_LAUNCHER   "${CCACHE_PROGRAM}")
  set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
endif()

# Defer enabling any languages.
project(firebase NONE)

if(WIN32)
  # On Windows, prefer cl over gcc if both are available. By default most of
  # the CMake generators prefer gcc, even on Windows.
  set(CMAKE_GENERATOR_CC cl)
endif()

enable_language(C)
enable_language(CXX)

set(
  FIREBASE_LD_EXECUTABLE
  ""
  CACHE
  STRING
  "The filename of the C/C++ linker to use. \
    For example, the default linker for clang and gcc is ld. \
    Using a fast linker, like mold (https://github.com/rui314/mold), \
    could be useful during development to reduce build/test cycle times."
)

if(NOT ("${FIREBASE_LD_EXECUTABLE}" STREQUAL ""))
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fuse-ld=${FIREBASE_LD_EXECUTABLE}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fuse-ld=${FIREBASE_LD_EXECUTABLE}")
endif()

option(
  FIREBASE_IOS_BUILD_BENCHMARKS
  "Enable building of C++ and Objective-C benchmarks for this project"
  OFF
)

option(
  FIREBASE_IOS_BUILD_TESTS
  "Enable building of C++ and Objective-C tests for this project"
  ON
)

list(INSERT CMAKE_MODULE_PATH 0 ${PROJECT_SOURCE_DIR}/cmake)
include(compiler_setup)
include(sanitizer_options)
include(fuzzing_options)

# rules depend on properties and options set above
include(external_rules)
include(podspec_rules)
include(cc_rules)


set(FIREBASE_SOURCE_DIR ${PROJECT_SOURCE_DIR})
set(FIREBASE_BINARY_DIR ${PROJECT_BINARY_DIR})
set(FIREBASE_INSTALL_DIR ${PROJECT_BINARY_DIR}/opt)

set(
  FIREBASE_DOWNLOAD_DIR
  ${PROJECT_BINARY_DIR}/downloads
  CACHE PATH "Where to store downloaded files"
)

set(
  FIREBASE_EXTERNAL_SOURCE_DIR
  ${FIREBASE_BINARY_DIR}/external/src
  CACHE PATH "Root directory of source code of the external dependencies"
)

download_external_sources()


# Googletest
if(FIREBASE_IOS_BUILD_TESTS)
  set(gtest_force_shared_crt ON CACHE BOOL "Use shared run-time")
  add_external_subdirectory(googletest)
  firebase_ios_add_alias(GTest::GTest gtest)
  firebase_ios_add_alias(GTest::Main gtest_main)
  firebase_ios_add_alias(GMock::GMock gmock)
endif()


# Benchmark
if(FIREBASE_IOS_BUILD_BENCHMARKS)
  set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "Firestore disabled")
  set(BENCHMARK_ENABLE_EXCEPTIONS OFF CACHE BOOL "Firestore disabled")
  set(BENCHMARK_ENABLE_INSTALL OFF CACHE BOOL "Firestore disabled")
  set(BENCHMARK_ENABLE_GTEST_TESTS OFF CACHE BOOL "Firestore disabled")

  if(IOS)
    # benchmark uses CMake's try_run, which doesn't work out of the box when
    # compiling for iOS.
    set(HAVE_STD_REGEX ON CACHE BOOL "iOS has std::regex")
    set(HAVE_POSIX_REGEX ON CACHE BOOL "iOS has POSIX regex.h")
    set(HAVE_STEADY_CLOCK ON CACHE BOOL "iOS has std::chrono::steady_clock")
  endif()

  add_external_subdirectory(benchmark)
endif()


# gRPC

# Force disable Abseil's tests, which don't compile under VS2017.
set(ABSL_RUN_TESTS OFF CACHE BOOL "Disable Abseil tests" FORCE)

# libcurl and c-ares conflict in their usage of this variable. Prevent
# libcurl's setting of this variable from affecting the c-ares build that's
# pulled in indirectly via gRPC.
unset(RANDOM_FILE CACHE)

set(CARES_INSTALL OFF CACHE BOOL "Disabled")

set(protobuf_BUILD_TESTS OFF CACHE BOOL "Disabled")
# See https://github.com/protocolbuffers/protobuf/issues/12185#issuecomment-1887892723
set(protobuf_INSTALL OFF)
set(utf8_range_ENABLE_INSTALL OFF)

if(IOS OR ANDROID)
  # C-Ares includes a number of example binaries (e.g. `ahost`) that fail to
  # build when compiling for non-host targets.
  set(gRPC_CARES_PROVIDER none CACHE STRING "Don't use C-Ares")

  # protoc needs to be built for the host to be able to invoke it during the
  # build.
  set(protobuf_BUILD_PROTOC_BINARIES OFF CACHE BOOL "Disabled")
endif()

if(ANDROID OR IOS)
  set(OPENSSL_FOUND FALSE)
else()
  find_package(OpenSSL QUIET)
endif()

if(OPENSSL_FOUND)
  set(gRPC_SSL_PROVIDER package CACHE STRING "Use external OpenSSL")
else()
  set(BORINGSSL_ROOT_DIR ${FIREBASE_EXTERNAL_SOURCE_DIR}/boringssl/src)
endif()

find_package(ZLIB QUIET)
if(ZLIB_FOUND)
  set(gRPC_ZLIB_PROVIDER package CACHE STRING "Use external ZLIB")
else()
  set(ZLIB_ROOT_DIR ${FIREBASE_EXTERNAL_SOURCE_DIR}/zlib)
endif()

find_package(re2 QUIET)
if(RE2_FOUND)
  set(gRPC_RE2_PROVIDER package CACHE STRING "Use external re2")
else()
  set(RE2_ROOT_DIR ${FIREBASE_EXTERNAL_SOURCE_DIR}/re2)
endif()

set(gRPC_BUILD_TESTS OFF CACHE BOOL "Disable gRPC tests")
set(gRPC_BUILD_CODEGEN OFF CACHE BOOL "Disable gRPC codegen")
set(gRPC_BUILD_CSHARP_EXT OFF CACHE BOOL "Disable gRPC C# extensions")
set(gRPC_INSTALL OFF CACHE BOOL "Disable gRPC installation")

set(ABSL_ROOT_DIR ${FIREBASE_EXTERNAL_SOURCE_DIR}/abseil-cpp)
set(CARES_ROOT_DIR ${FIREBASE_EXTERNAL_SOURCE_DIR}/cares)
set(PROTOBUF_ROOT_DIR ${FIREBASE_EXTERNAL_SOURCE_DIR}/protobuf)

add_external_subdirectory(grpc)

# Fix up targets included by boringssl (ver: b9232f9e27e5668bc0414879dcdedb2a59ea75f2)
# We might be able to remove this with newer versions.
if(CXX_CLANG)
  if(TARGET crypto)
    target_compile_options(
      crypto PRIVATE
      -Wno-unused-but-set-variable
    )
  endif()
endif()

if(MSVC)
  # Disable warnings about unsafe use of std::copy
  target_compile_definitions(
    absl_strings PUBLIC
    _SCL_SECURE_NO_WARNINGS=1
  )
endif()

if(NOT OPENSSL_FOUND)
  # Not using outboard OpenSSL so set up BoringSSL to look like it.
  firebase_ios_add_alias(OpenSSL::Crypto crypto)
  target_include_directories(
    crypto INTERFACE
    $<BUILD_INTERFACE:${FIREBASE_EXTERNAL_SOURCE_DIR}/boringssl/src/include>
  )

  firebase_ios_add_alias(OpenSSL::SSL ssl)
  target_include_directories(
    ssl INTERFACE
    $<BUILD_INTERFACE:${FIREBASE_EXTERNAL_SOURCE_DIR}/boringssl/src/include>
  )
endif()

if(NOT ZLIB_FOUND)
  target_include_directories(
    zlibstatic INTERFACE
    $<BUILD_INTERFACE:${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/third_party/zlib>
  )
endif()


# Snappy
set(SNAPPY_BUILD_TESTS OFF CACHE BOOL "Firestore disabled")
set(SNAPPY_BUILD_BENCHMARKS OFF CACHE BOOL "Firestore disabled")
add_external_subdirectory(snappy)
firebase_ios_add_alias(Snappy::Snappy snappy)

# LevelDB
set(LEVELDB_BUILD_TESTS OFF CACHE BOOL "Firestore disabled")
set(LEVELDB_BUILD_BENCHMARKS OFF CACHE BOOL "Firestore disabled")
set(LEVELDB_INSTALL OFF CACHE BOOL "Firestore disabled")
add_external_subdirectory(leveldb)
firebase_ios_add_alias(LevelDB::LevelDB leveldb)


# nanopb
set(nanopb_BUILD_GENERATOR ON CACHE BOOL "Enable the nanopb generator")
set(nanopb_MSVC_STATIC_RUNTIME OFF CACHE BOOL "Link static runtime libraries")
add_external_subdirectory(nanopb)

target_compile_definitions(
  protobuf-nanopb-static PUBLIC
  -DPB_FIELD_32BIT -DPB_ENABLE_MALLOC -DPB_NO_PACKED_STRUCTS=1
)

# Enable #include <nanopb/pb.h>
target_include_directories(
  protobuf-nanopb-static INTERFACE
  $<BUILD_INTERFACE:${FIREBASE_EXTERNAL_SOURCE_DIR}/nanopb>
)

# XCTest
if(APPLE)
  find_package(XCTest)
endif()


if(FIREBASE_IOS_BUILD_TESTS)
  enable_testing()
endif()

add_subdirectory(FirebaseAppCheck/Interop)
add_subdirectory(FirebaseCore)
add_subdirectory(Firestore)
add_subdirectory(FirebaseAuth/Interop)
