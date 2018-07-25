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

# Superbuild for Firebase

cmake_minimum_required(VERSION 2.8.11)
project(firebase C CXX)

option(WITH_ASAN "Build with Address Sanitizer" OFF)
option(WITH_TSAN "Build with Thread Sanitizer (mutually exculsive with other sanitizers)" OFF)
option(WITH_UBSAN "Build with Undefined Behavior sanitizer" OFF)

# If no build type is specified, make it a debug build
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug)
endif()

list(INSERT CMAKE_MODULE_PATH 0 ${PROJECT_SOURCE_DIR}/cmake)

set(FIREBASE_BINARY_DIR ${PROJECT_BINARY_DIR})
set(FIREBASE_INSTALL_DIR ${PROJECT_BINARY_DIR}/opt)

set(
  FIREBASE_DOWNLOAD_DIR
  ${PROJECT_BINARY_DIR}/downloads
  CACHE PATH "Where to store downloaded files"
)

enable_testing()

include(ExternalProject)
include(external/firestore)
