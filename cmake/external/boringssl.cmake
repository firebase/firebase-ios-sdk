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

if(TARGET boringssl)
  return()
endif()

# Based on https://github.com/grpc/grpc/blob/v1.62.0/bazel/grpc_deps.bzl
set(commit ae72a4514c7afd150596b0a80947f3ca9b8363b5)

ExternalProject_Add(
  boringssl

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME boringssl-${commit}.tar.gz
  URL https://github.com/google/boringssl/archive/${commit}.tar.gz
  URL_HASH SHA256=057f662b0e85931a84945b2e89ba201fd44b0583da827c948fe443593690fb83

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/boringssl

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
  HTTP_HEADER       "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
