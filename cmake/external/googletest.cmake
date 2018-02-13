# Copyright 2017 Google
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
include(ExternalProjectFlags)

ExternalProject_GitSource(
  GOOGLETEST_GIT
  GIT_REPOSITORY "https://github.com/google/googletest.git"
  GIT_TAG "release-1.8.0"
)

ExternalProject_Add(
  googletest

  ${GOOGLETEST_GIT}

  PREFIX ${PROJECT_BINARY_DIR}/external/googletest

  # Just download the sources without building.
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
)
