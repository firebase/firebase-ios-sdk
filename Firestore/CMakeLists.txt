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
project(firestore)

set(FIREBASE_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/..")

# CMAKE_INSTALL_PREFIX should be passed in to this build so that it can find
# outputs of the superbuild. This is handled automatically if run via the
# superbuild (i.e. by invoking cmake on the directory above this).
#
# If you want to use this project directly in e.g. CLion, make sure you
# configure this.
set(FIREBASE_INSTALL_DIR "${CMAKE_INSTALL_PREFIX}")

list(INSERT CMAKE_MODULE_PATH 0 ${FIREBASE_SOURCE_DIR}/cmake)
include(utils)

find_package(GTest REQUIRED)
find_package(LevelDB REQUIRED)

if(APPLE)
  find_package(FirebaseCore REQUIRED)
endif()

# We use C++11
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Fully qualified imports, project wide
include_directories("${FIREBASE_SOURCE_DIR}")

if(APPLE)
  # CMake has no special support for Objective-C as a distinct language but enabling modules and
  # other clang extensions would apply even to regular C++ sources which is nonportable. Keep these
  # flags separate to avoid misuse.
  set(
    OBJC_FLAGS
    -fobjc-arc
    -fmodules
    -fno-autolink
    -F${FIREBASE_INSTALL_DIR}/Frameworks
  )
endif(APPLE)

enable_testing()
add_subdirectory(third_party/abseil-cpp EXCLUDE_FROM_ALL)
add_subdirectory(core)
