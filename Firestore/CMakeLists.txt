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
include(SanitizerOptions)
include(utils)


# External packages
if(APPLE)
  find_package(FirebaseCore REQUIRED)
  find_package(GoogleUtilities REQUIRED)
endif()
find_package(LevelDB REQUIRED)
find_package(ZLIB)


# Googletest
add_subdirectory(
  ${FIREBASE_BINARY_DIR}/src/googletest
  ${FIREBASE_BINARY_DIR}/src/googletest-build
  EXCLUDE_FROM_ALL
)
add_alias(GTest::GTest gtest)
add_alias(GTest::Main gtest_main)
add_alias(GMock::GMock gmock)


# Abseil-cpp
add_subdirectory(
  third_party/abseil-cpp
)


# gRPC
if(ZLIB_FOUND)
  set(gRPC_ZLIB_PROVIDER package CACHE STRING "Use external ZLIB")
endif()

set(gRPC_BUILD_TESTS OFF CACHE BOOL "Disable gRPC tests")
add_subdirectory(
  ${FIREBASE_BINARY_DIR}/src/grpc
  ${FIREBASE_BINARY_DIR}/src/grpc-build
  EXCLUDE_FROM_ALL
)

# Fix up targets included by gRPC's build
add_alias(OpenSSL::Crypto crypto)
target_include_directories(
  crypto
  INTERFACE
    $<BUILD_INTERFACE:${FIREBASE_BINARY_DIR}/src/grpc/third_party/boringssl/include>
)

add_alias(OpenSSL::SSL ssl)
target_include_directories(
  ssl
  INTERFACE
    $<BUILD_INTERFACE:${FIREBASE_BINARY_DIR}/src/grpc/third_party/boringssl/include>
)

add_alias(protobuf::libprotobuf libprotobuf)
target_compile_options(
  libprotobuf
  PUBLIC -Wno-unused-parameter
)

if(NOT ZLIB_FOUND)
  target_include_directories(
    zlibstatic
    INTERFACE
      $<BUILD_INTERFACE:${FIREBASE_BINARY_DIR}/src/grpc/third_party/zlib>
  )
endif()


# nanopb
set(nanopb_BUILD_GENERATOR ON CACHE BOOL "Enable the nanopb generator")
set(nanopb_PROTOC_PATH ${NANOPB_PROTOC_BIN} CACHE STRING "Protoc location")
add_subdirectory(
  ${FIREBASE_BINARY_DIR}/src/nanopb
  ${FIREBASE_BINARY_DIR}/src/nanopb-build
  EXCLUDE_FROM_ALL
)

target_compile_definitions(
  protobuf-nanopb
  PUBLIC -DPB_FIELD_16BIT
)

target_include_directories(
  protobuf-nanopb
  INTERFACE $<BUILD_INTERFACE:${FIREBASE_BINARY_DIR}/src/nanopb>
)


enable_testing()
include(CompilerSetup)

# Superbuild installed results
include_directories(${FIREBASE_INSTALL_DIR}/include)

# Generated sources will be relative to the binary directory.
include_directories(${FIREBASE_BINARY_DIR})

# Fully qualified imports, project wide
include_directories(${FIREBASE_SOURCE_DIR})

add_subdirectory(core)
add_subdirectory(Protos)
