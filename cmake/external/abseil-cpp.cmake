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

set(source_dir ${PROJECT_SOURCE_DIR}/Firestore/third_party/abseil-cpp)
set(binary_dir ${PROJECT_BINARY_DIR}/Firestore/third_party/abseil-cpp)

ExternalProject_Add(
  abseil-cpp
  DEPENDS googletest

  PREFIX "${binary_dir}"
  SOURCE_DIR "${source_dir}"
  BINARY_DIR "${binary_dir}"

  INSTALL_DIR "${FIREBASE_INSTALL_DIR}"
  INSTALL_COMMAND ""
  TEST_BEFORE_INSTALL ON

  CMAKE_ARGS
      -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
)

