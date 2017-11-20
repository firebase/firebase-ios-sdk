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
project(firebase C CXX)

# We use C++11
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Fully qualified imports, project wide
include_directories("${PROJECT_SOURCE_DIR}")

# CMake's test target does not build tests before running them. This adds a
# check target that
add_custom_target(check COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure)

enable_testing()
add_subdirectory(Firestore)
