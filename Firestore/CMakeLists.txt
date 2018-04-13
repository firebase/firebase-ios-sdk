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
