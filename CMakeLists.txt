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
set(gtest_force_shared_crt ON CACHE BOOL "Use shared run-time")
add_external_subdirectory(googletest)
firebase_ios_add_alias(GTest::GTest gtest)
firebase_ios_add_alias(GTest::Main gtest_main)
firebase_ios_add_alias(GMock::GMock gmock)


# Benchmark
set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "Firestore disabled")
set(BENCHMARK_ENABLE_EXCEPTIONS OFF CACHE BOOL "Firestore disabled")
set(BENCHMARK_ENABLE_INSTALL OFF CACHE BOOL "Firestore disabled")
set(BENCHMARK_ENABLE_GTEST_TESTS OFF CACHE BOOL "Firestore disabled")
add_external_subdirectory(benchmark)


# Abseil-cpp
# Force disable Abseil's tests, which don't compile under VS2017.
set(old_build_testing ${BUILD_TESTING})
set(ABSL_RUN_TESTS OFF CACHE BOOL "Disable Abseil tests" FORCE)
add_external_subdirectory(abseil-cpp)

if(CXX_CLANG)
  target_compile_options(
    absl_time_zone
    PRIVATE
      -Wno-unused-template
      -Wno-shadow
      -Wno-tautological-type-limit-compare
  )
endif()

if(MSVC)
  # Disable warnings about unsafe use of std::copy
  target_compile_definitions(
    absl_strings
    PUBLIC
      _SCL_SECURE_NO_WARNINGS=1
  )
endif()


# gRPC

# libcurl and c-ares conflict in their usage of this variable. Prevent
# libcurl's setting of this variable from affecting the c-ares build that's
# pulled in indirectly via gRPC.
unset(RANDOM_FILE CACHE)

find_package(OpenSSL QUIET)
if(OPENSSL_FOUND)
  set(gRPC_SSL_PROVIDER package CACHE STRING "Use external OpenSSL")
endif()

find_package(ZLIB QUIET)
if(ZLIB_FOUND)
  set(gRPC_ZLIB_PROVIDER package CACHE STRING "Use external ZLIB")
endif()

set(gRPC_BUILD_TESTS OFF CACHE BOOL "Disable gRPC tests")
add_external_subdirectory(grpc)

# Fix up targets included by gRPC's build
if(OPENSSL_FOUND)
  # gRPC's CMakeLists.txt does not account for finding OpenSSL in a directory
  # that's not in the default search path.
  target_include_directories(grpc PRIVATE ${OPENSSL_INCLUDE_DIR})

  if(CXX_CLANG OR CXX_GNU)
    if((OPENSSL_VERSION VERSION_EQUAL "1.1.0") OR
       (OPENSSL_VERSION VERSION_GREATER "1.1.0"))
      # gRPC uses some features deprecated in OpenSSL 1.1.0
      target_compile_options(
        grpc
        PRIVATE -Wno-deprecated-declarations
      )
    endif()
  endif()

else()
  # Not using outboard OpenSSL so set up BoringSSL to look like it.
  firebase_ios_add_alias(OpenSSL::Crypto crypto)
  target_include_directories(
    crypto
    INTERFACE
      $<BUILD_INTERFACE:${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/third_party/boringssl/include>
  )

  firebase_ios_add_alias(OpenSSL::SSL ssl)
  target_include_directories(
    ssl
    INTERFACE
      $<BUILD_INTERFACE:${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/third_party/boringssl/include>
  )
endif()

if(CXX_CLANG OR CXX_GNU)
  target_compile_options(
    libprotobuf
    PUBLIC -Wno-unused-parameter
  )
endif()
if(CXX_CLANG)
  target_compile_options(
    libprotobuf
    PRIVATE
      -Wno-inconsistent-missing-override
      -Wno-invalid-offsetof
  )
endif()


if(NOT ZLIB_FOUND)
  target_include_directories(
    zlibstatic
    INTERFACE $<BUILD_INTERFACE:${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/third_party/zlib>
  )
endif()


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
  protobuf-nanopb-static
  PUBLIC -DPB_FIELD_32BIT -DPB_ENABLE_MALLOC
)

# Enable #include <nanopb/pb.h>
target_include_directories(
  protobuf-nanopb-static
  INTERFACE
  $<BUILD_INTERFACE:${FIREBASE_EXTERNAL_SOURCE_DIR}>
  $<BUILD_INTERFACE:${FIREBASE_EXTERNAL_SOURCE_DIR}/nanopb>
)


# XCTest
if(APPLE)
  find_package(XCTest)
endif()


if(FIREBASE_IOS_BUILD_TESTS)
  enable_testing()
endif()

add_subdirectory(FirebaseCore)
add_subdirectory(Firestore)
add_subdirectory(GoogleUtilities)
add_subdirectory(Interop/Auth)
add_subdirectory(Interop/CoreDiagnostics)
