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

# Based on https://github.com/grpc/grpc/blob/v1.27.0/bazel/grpc_deps.bzl
# master-with-bazel@{2019-10-18}
set(commit 83da28a68f32023fd3b95a8ae94991a07b1f6c62)

ExternalProject_Add(
  boringssl

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME boringssl-${commit}.tar.gz
  URL https://github.com/google/boringssl/archive/${commit}.tar.gz
  URL_HASH SHA256=781fa39693ec2984c71213cd633e9f6589eaaed75e3a9ac413237edec96fd3b9

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/boringssl

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
  HTTP_HEADER       "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
