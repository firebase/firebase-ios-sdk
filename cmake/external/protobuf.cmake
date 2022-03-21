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

# Based on https://github.com/grpc/grpc/blob/v1.27.0/bazel/grpc_deps.bzl
# v3.11.4, master@{2020-01-15}
set(commit 29cd005ce1fe1a8fabf11e325cb13006a6646d59)

ExternalProject_Add(
  protobuf

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME protobuf-${commit}.tar.gz
  URL https://github.com/protocolbuffers/protobuf/archive/${commit}.tar.gz
  URL_HASH SHA256=51398b0b97b353c1c226d0ade0bae80c80380e691cba7c1a108918986784a1c7

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/protobuf

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
  HTTP_HEADER "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
