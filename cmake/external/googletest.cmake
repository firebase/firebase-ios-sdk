# Copyright 2017 Google LLC
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

if(TARGET googletest OR NOT DOWNLOAD_GOOGLETEST)
  return()
endif()

# Note: googletest lives at head and encourages to just point to a head commit.
# https://github.com/google/googletest/blob/bf66935e07/README.md?plain=1#L5-L10

# Commit 4a00a24fff was chosen because it is the _last_ commit before googletest
# dropped c++14 support, setting the floor to c++17. Once Firebase sets _its_
# floor to c++17, this pinned commit can be moved to a new one.
# See https://github.com/firebase/firebase-ios-sdk/pull/14474.
set(version 4a00a24fff)

ExternalProject_Add(
  googletest

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG "${version}"

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""

  HTTP_HEADER "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
