# Copyright 2019 Google
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

set(version 20240722.1)

ExternalProject_Add(
  abseil-cpp

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME abseil-cpp-${version}.tar.gz
  URL https://github.com/abseil/abseil-cpp/archive/${version}.tar.gz
  URL_HASH SHA256=40cee67604060a7c8794d931538cb55f4d444073e556980c88b6c49bb9b19bb7

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
  HTTP_HEADER "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
