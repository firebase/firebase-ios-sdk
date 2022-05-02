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
include(googletest)
include(grpc)
include(leveldb)
include(nanopb)
include(protobuf)
include(re2)
include(libfuzzer)

if(TARGET Firestore)
  return()
endif()

ExternalProject_Add(
  Firestore
  DEPENDS
    googletest
    grpc
    leveldb
    nanopb
    protobuf
    re2
    libfuzzer

  # Lay the binary directory out as if this were a subproject. This makes it
  # possible to build and test in it directly.
  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_SOURCE_DIR}/Firestore
  BINARY_DIR ${PROJECT_BINARY_DIR}/Firestore

  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
    -DCMAKE_INSTALL_PREFIX:PATH=${FIREBASE_INSTALL_DIR}
    -DWITH_ASAN:BOOL=${WITH_ASAN}
    -DWITH_TSAN:BOOL=${WITH_TSAN}
    -DWITH_UBSAN:BOOL=${WITH_UBSAN}
    -DFUZZING:BOOL=${FUZZING}

  BUILD_ALWAYS ON

  INSTALL_COMMAND ""
  TEST_BEFORE_INSTALL ON
)
