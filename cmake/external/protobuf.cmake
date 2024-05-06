# Copyright 2018 Google LLC
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

if(TARGET protobuf)
  return()
endif()

# Based on https://github.com/grpc/grpc/blob/v1.62.0/bazel/grpc_deps.bzl
set(commit 7f94235e552599141950d7a4a3eaf93bc87d1b22)

ExternalProject_Add(
  protobuf

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME protobuf-${commit}.tar.gz
  URL https://github.com/protocolbuffers/protobuf/archive/${commit}.tar.gz
  URL_HASH SHA256=70f480fe9cb0c6829dbf6be3c388103313aacb65de667b86d981bbc9eaedb905

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/protobuf

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
  HTTP_HEADER "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
