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

include(ExternalProject)
ExternalProject_Add(
  googletest_external
  PREFIX googletest
  URL "https://github.com/google/googletest/archive/release-1.8.0.tar.gz"
  URL_HASH "SHA256=58a6f4277ca2bc8565222b3bbd58a177609e9c488e8a72649359ba51450db7d8"

  CMAKE_ARGS
      -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
      -DBUILD_GMOCK:BOOL=OFF
      -DBUILD_GTEST:BOOL=ON

  # Cut down on scary log output
  LOG_DOWNLOAD ON
  LOG_CONFIGURE ON

  INSTALL_COMMAND ""
  UPDATE_COMMAND ""
  TEST_COMMAND ""
)

ExternalProject_Get_Property(googletest_external source_dir binary_dir)

# CMake requires paths in include_directories to exist at configure time
file(MAKE_DIRECTORY ${source_dir}/googletest/include)

add_library(gtest STATIC IMPORTED GLBOAL)
set_target_properties(
  gtest PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${source_dir}/googletest/include
  IMPORTED_LOCATION ${binary_dir}/googletest/${CMAKE_FIND_LIBRARY_PREFIXES}gtest.a
)
add_dependencies(gtest googletest_external)

add_library(gtest_main STATIC IMPORTED GLOBAL)
set_target_properties(
  gtest_main PROPERTIES
  IMPORTED_LOCATION ${binary_dir}/googletest/${CMAKE_FIND_LIBRARY_PREFIXES}gtest_main.a
)
add_dependencies(gtest_main googletest_external)
