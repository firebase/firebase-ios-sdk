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

# Download and install googletest during configuration rather than at build
# time. This makes it just a regular target as far as the outer build is
# concerned.
#
# See https://crascit.com/2015/07/25/cmake-gtest/
configure_file(CMakeLists.txt.download download/CMakeLists.txt)
execute_process(
  COMMAND "${CMAKE_COMMAND}" -G "${CMAKE_GENERATOR}" .
  WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/download"
)
execute_process(
  COMMAND "${CMAKE_COMMAND}" --build .
  WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/download"
)

set(BUILD_GTEST ON)
set(BUILD_GMOCK OFF)

# Include the downloaded sources as a part of this project, but exclude its
# targets from "all" since we only need the resulting libraries for building
# tests.
add_subdirectory(
  "${CMAKE_CURRENT_BINARY_DIR}/src"
  "${CMAKE_CURRENT_BINARY_DIR}/build"
  EXCLUDE_FROM_ALL
)
