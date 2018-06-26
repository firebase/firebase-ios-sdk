# Copyright 2018 Google
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

set(NANOPB_PROTOC_BIN ${FIREBASE_INSTALL_DIR}/bin/protoc)

ExternalProject_Add(
  nanopb
  DEPENDS
    protobuf

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  URL https://github.com/nanopb/nanopb/archive/nanopb-0.3.9.1.tar.gz
  URL_HASH SHA256=67460d0c0ad331ef4d5369ad337056d0cd2f900c94887628d287eb56c69324bc

  PREFIX ${PROJECT_BINARY_DIR}/external/nanopb

  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
    -DCMAKE_INSTALL_PREFIX:STRING=${FIREBASE_INSTALL_DIR}
    -DBUILD_SHARED_LIBS:BOOL=OFF
    -Dnanopb_BUILD_GENERATOR:BOOL=ON
    -Dnanopb_PROTOC_PATH:STRING=${NANOPB_PROTOC_BIN}

  UPDATE_COMMAND ""
  TEST_COMMAND ""
)
