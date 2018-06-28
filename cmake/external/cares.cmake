# Copyright 2018 Google
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

ExternalProject_Add(
  c-ares

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  URL https://github.com/c-ares/c-ares/archive/cares-1_14_0.tar.gz
  URL_HASH SHA256=62dd12f0557918f89ad6f5b759f0bf4727174ae9979499f5452c02be38d9d3e8

  PREFIX ${PROJECT_BINARY_DIR}/external/cares

  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
    -DCMAKE_INSTALL_PREFIX:STRING=${FIREBASE_INSTALL_DIR}
    -DCARES_STATIC:BOOL=ON
    -DCARES_SHARED:BOOL=OFF
    -DCARES_STATIC_PIC:BOOL=ON

  UPDATE_COMMAND ""
  TEST_COMMAND ""
)
