# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include(ExternalProject)

# When updating the below version, be sure to also update the `URL_HASH` in the
# below `ExternalProject_Add` function. Update the `URL_HASH` by:
# 1. Downloading the version's tarball from the URL below.
#    - https://github.com/google/GoogleUtilities/archive/${version}.tar.gz
# 2. Running `shasum` on the downloaded tarball.
#    - `shasum -a 256 GoogleUtilities-${version}.tar.gz`
# 3. Copying the output of the above command into the `URL_HASH` below.
set(version 7.12.0)

ExternalProject_Add(
  GoogleUtilities

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME GoogleUtilities-${version}.tar.gz
  URL https://github.com/google/GoogleUtilities/archive/${version}.tar.gz
  URL_HASH SHA256=0e9461fa0c751ac73125c3d7edd95ac923a80a36a04b4a1b0f47c9a9279d8c2a

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  TEST_COMMAND ""
  HTTP_HEADER "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
