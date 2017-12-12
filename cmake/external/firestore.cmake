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

set(source_dir ${PROJECT_SOURCE_DIR}/Firestore)
set(binary_dir ${PROJECT_BINARY_DIR}/Firestore)

ExternalProject_Add(
  Firestore
  DEPENDS googletest abseil-cpp

  # Lay the binary directory out as if this were a subproject. This makes it
  # possible to build and test in it directly.
  PREFIX ${binary_dir}
  SOURCE_DIR ${source_dir}
  BINARY_DIR ${binary_dir}
  BUILD_ALWAYS ON

  # Even though this isn't installed, set up the INSTALL_DIR so that
  # find_package can find dependencies built from source.
  INSTALL_DIR ${FIREBASE_INSTALL_DIR}
  INSTALL_COMMAND ""
  TEST_BEFORE_INSTALL ON

  CMAKE_ARGS
      -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
)
