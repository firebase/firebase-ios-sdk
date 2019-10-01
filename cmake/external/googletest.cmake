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

# Googletest 1.8.0 fails to build on VS 2017:
# https://github.com/google/googletest/issues/1111.
#
# No release has been made since, so just pick a commit since then.
set(commit ba96d0b1161f540656efdaed035b3c062b60e006)  # master@{2018-07-10}

ExternalProject_Add(
  googletest

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME googletest-${commit}.tar.gz
  URL https://github.com/google/googletest/archive/${commit}.tar.gz
  URL_HASH SHA256=949c556896cf31ed52e53449e17a1276b8b26d3ee5932f5ca49ee929f4b35c51

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
)
