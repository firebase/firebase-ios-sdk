# Copyright 2022 Google LLC
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

if(TARGET RE2)
    return()
endif()

# Based on https://github.com/grpc/grpc/blob/v1.69.x/bazel/grpc_deps.bzl
set(version 2022-04-01)

ExternalProject_Add(
  re2

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME re2-${version}.tar.gz
  URL https://github.com/google/re2/archive/${version}.tar.gz
  URL_HASH SHA256=1ae8ccfdb1066a731bba6ee0881baad5efd2cd661acd9569b689f2586e1a50e9

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/re2

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
)
