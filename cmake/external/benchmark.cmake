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

if(TARGET benchmark OR NOT DOWNLOAD_BENCHMARK)
  return()
endif()

set(version v1.5.0)

ExternalProject_Add(
  benchmark

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME benchmark-${version}.tar.gz
  URL https://github.com/google/benchmark/archive/${version}.tar.gz
  URL_HASH SHA256=3c6a165b6ecc948967a1ead710d4a181d7b0fbcaa183ef7ea84604994966221a

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
  HTTP_HEADER       "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
