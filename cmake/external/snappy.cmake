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

if(TARGET snappy)
  return()
endif()

set(version 1.1.9)

ExternalProject_Add(
  snappy

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME snappy-${version}.tar.gz
  URL https://github.com/google/snappy/archive/refs/tags/${version}.tar.gz
  URL_HASH SHA256=75c1fbb3d618dd3a0483bff0e26d0a92b495bbe5059c8b4f1c962b478b6e06e7

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
  PATCH_COMMAND     patch -Np1 --binary -i ${CMAKE_CURRENT_LIST_DIR}/snappy.patch

  HTTP_HEADER "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
