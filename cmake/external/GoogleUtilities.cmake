# Copyright 2021 Google LLC
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

set(version 7.2.0)

ExternalProject_Add(
  GoogleUtilities

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME GoogleUtilities-${version}.tar.gz
  URL https://github.com/google/GoogleUtilities/archive/${version}.tar.gz
  URL_HASH SHA256=d9e4479d9d8cdd54cc239afc3481d68524bc7919ca095924748bc0787035e7c7

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
)
