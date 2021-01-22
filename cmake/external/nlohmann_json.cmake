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

if(TARGET nlohmann_json)
return()
endif()

set(version v3.9.1)

ExternalProject_Add(
  nlohmann_json

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME nlohmann_json-${version}.tar.gz
  URL https://github.com/nlohmann/json/archive/${version}.tar.gz

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/nlohmann_json

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
)
