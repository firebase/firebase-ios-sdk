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

if(APPLE)
  # When building on the apple platform certain Objective-C++ classes bridge
  # back into other Firebase Cocoapods. This requires shelling out to xcodebuild
  # to verify the built frameworks are up-to-date. You can disable this to speed
  # up the build.
  option(BUILD_PODS, "Always build dependent cocoapods." ON)
endif(APPLE)

list(INSERT CMAKE_MODULE_PATH 0 ${PROJECT_SOURCE_DIR}/cmake)

set(FIREBASE_INSTALL_DIR ${PROJECT_BINARY_DIR})

enable_testing()

include(external/FirebaseCore)
include(external/googletest)
include(external/leveldb)
include(external/grpc)
include(external/protobuf)
include(external/nanopb)
include(external/firestore)
