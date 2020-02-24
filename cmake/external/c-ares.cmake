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

if(TARGET c-ares)
  return()
endif()

# The gRPC build fails if c-ares is not present in its expected location so
# this ExternalProject unpacks itself inside the gRPC source tree. CMake clears
# the SOURCE_DIR when unpacking so this must come after the grpc
# ExternalProject.

# Based on https://github.com/grpc/grpc/blob/v1.27.0/bazel/grpc_deps.bzl
# v1.15.0, master@{2018-10-23}
set(commit e982924acee7f7313b4baa4ee5ec000c5e373c30)

ExternalProject_Add(
  c-ares

  DEPENDS
    grpc-download

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME c-ares-${commit}.tar.gz
  URL https://github.com/c-ares/c-ares/archive/${commit}.tar.gz
  URL_HASH SHA256=e8c2751ddc70fed9dc6f999acd92e232d5846f009ee1674f8aee81f19b2b915a

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/grpc/third_party/cares/cares

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
)
