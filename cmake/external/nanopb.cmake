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
include(protobuf)

if(TARGET nanopb)
  return()
endif()

set(NANOPB_PROTOC_BIN ${FIREBASE_INSTALL_DIR}/bin/protoc)

ExternalProject_Add(
  nanopb

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  URL https://github.com/nanopb/nanopb/archive/nanopb-0.3.9.1.tar.gz
  URL_HASH SHA256=67460d0c0ad331ef4d5369ad337056d0cd2f900c94887628d287eb56c69324bc

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
)
