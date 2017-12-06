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

list(INSERT CMAKE_MODULE_PATH 0 ${PROJECT_SOURCE_DIR}/cmake)

# External Projects install into this prefix and download into the source tree
# to avoid re-downloading repeatedly during development.
set(FIREBASE_INSTALL_DIR "${PROJECT_BINARY_DIR}/usr")
set(FIREBASE_DOWNLOAD_DIR "${PROJECT_SOURCE_DIR}/.downloads")

enable_testing()

include(external/googletest)
include(external/abseil-cpp)
include(external/firestore)
