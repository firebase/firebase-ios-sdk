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

ExternalProject_Add(
  protobuf

  DOWNLOAD_DIR ${PROJECT_BINARY_DIR}/downloads
  DOWNLOAD_NAME protobuf-v3.5.11.tar.gz
  URL https://github.com/google/protobuf/archive/v3.5.1.1.tar.gz
  URL_HASH SHA256=56b5d9e1ab2bf4f5736c4cfba9f4981fbc6976246721e7ded5602fbaee6d6869

  PREFIX ${PROJECT_BINARY_DIR}/external/protobuf

  # protobuf ships CMake files but not at the root of the repo, which confuses
  # CMake by default. Unfortunately when you override CONFIGURE_COMMAND like
  # this, CMake no longer automatically plumbs in CMAKE_ARGS and friends so
  # those need to be manually passed in this command line.
  CONFIGURE_COMMAND
    ${CMAKE_COMMAND}
      -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX:PATH=${FIREBASE_INSTALL_DIR}
      -Dprotobuf_BUILD_TESTS=OFF
      ${PROJECT_BINARY_DIR}/external/protobuf/src/protobuf/cmake

  UPDATE_COMMAND ""
  TEST_COMMAND ""
  INSTALL_COMMAND ""
)
