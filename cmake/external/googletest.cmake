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
include(ExternalProjectFlags)

ExternalProject_GitSource(
  GOOGLETEST_GIT
  GIT_REPOSITORY "https://github.com/google/googletest.git"
  GIT_TAG "release-1.8.0"
)

ExternalProject_Add(
  googletest
  DEPENDS
    FirebaseCore  # for sequencing

  ${GOOGLETEST_GIT}

  PREFIX ${PROJECT_BINARY_DIR}/external/googletest

  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
    -DBUILD_SHARED_LIBS:BOOL=OFF

  INSTALL_COMMAND ""
  TEST_COMMAND ""
)

ExternalProject_Get_Property(
  googletest
  SOURCE_DIR BINARY_DIR
)

# Arguments to pass to another CMake invocation so that it can find googletest
# without installing it using the standard FindGTest module.
set(GTEST_INCLUDE_DIR ${SOURCE_DIR}/googletest/include)
set(GTEST_LIBRARY ${BINARY_DIR}/googlemock/gtest/libgtest.a)
set(GTEST_MAIN_LIBRARY ${BINARY_DIR}/googlemock/gtest/libgtest_main.a)
set(
  GTEST_CMAKE_ARGS
  -DGTEST_INCLUDE_DIR=${GTEST_INCLUDE_DIR}
  -DGTEST_LIBRARY=${GTEST_LIBRARY}
  -DGTEST_MAIN_LIBRARY=${GTEST_MAIN_LIBRARY}
)
