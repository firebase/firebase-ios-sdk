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

# Based on https://github.com/grpc/grpc/blob/v1.40.0/bazel/grpc_deps.bzl
# master-with-bazel@{2021-06-21}
set(commit bcc01b6c66b1c6fa2816b108e50a544b757fbd7b)

ExternalProject_Add(
  boringssl

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME boringssl-${commit}.tar.gz
  URL https://github.com/google/boringssl/archive/${commit}.tar.gz
  URL_HASH SHA256=19870fcdbdfc61217ad814077483347a5b2bf4b3bbb5f6c983edac7856a40bbb

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/boringssl

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
  HTTP_HEADER       "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
