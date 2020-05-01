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

set(version 0.3.9.5)

ExternalProject_Add(
  nanopb

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  URL https://github.com/nanopb/nanopb/archive/nanopb-${version}.tar.gz
  URL_HASH SHA256=c14ac70128bd019c48d8b35d5a4923ea98aa769b930f6cf07ac2c223babdb5ca

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
)
