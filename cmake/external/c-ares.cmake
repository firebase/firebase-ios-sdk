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

if(TARGET c-ares)
  return()
endif()

# The gRPC build fails if c-ares is not present in its expected location so
# this ExternalProject unpacks itself inside the gRPC source tree. CMake clears
# the SOURCE_DIR when unpacking so this must come after the grpc
# ExternalProject.

ExternalProject_Add(
  c-ares

  DEPENDS
    grpc-download

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  URL https://github.com/c-ares/c-ares/archive/cares-1_14_0.tar.gz
  URL_HASH SHA256=62dd12f0557918f89ad6f5b759f0bf4727174ae9979499f5452c02be38d9d3e8

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/grpc/third_party/cares/cares

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
)
