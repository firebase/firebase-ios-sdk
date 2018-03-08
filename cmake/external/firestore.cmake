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
  Firestore
  DEPENDS
    FirebaseCore
    googletest
    leveldb
    grpc
    nanopb

  # Lay the binary directory out as if this were a subproject. This makes it
  # possible to build and test in it directly.
  PREFIX ${PROJECT_BINARY_DIR}/external/Firestore
  SOURCE_DIR ${PROJECT_SOURCE_DIR}/Firestore
  BINARY_DIR ${PROJECT_BINARY_DIR}/Firestore

  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
    -DCMAKE_INSTALL_PREFIX:PATH=${FIREBASE_INSTALL_DIR}

  BUILD_ALWAYS ON

  INSTALL_COMMAND ""
  TEST_BEFORE_INSTALL ON
)
