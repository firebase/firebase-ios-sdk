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

if(TARGET grpc)
  return()
endif()

set(version 1.50.0)

ExternalProject_Add(
  grpc

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME grpc-${version}.tar.gz
  URL https://github.com/grpc/grpc/archive/v${version}.tar.gz
  # URL_HASH SHA256=8c05641b9f91cbc92f51cc4a5b3a226788d7a63f20af4ca7aaca50d92cc94a0d

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/grpc

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  TEST_COMMAND ""
  INSTALL_COMMAND ""

  HTTP_HEADER "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
