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

# Use a system- or user-supplied zlib if available
find_package(ZLIB)
if(ZLIB_FOUND)
  add_custom_target(zlib)

else()
  ExternalProject_Add(
    zlib

    DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
    DOWNLOAD_NAME zlib-v1.2.11.tar.gz
    URL https://github.com/madler/zlib/archive/v1.2.11.tar.gz
    URL_HASH SHA256=629380c90a77b964d896ed37163f5c3a34f6e6d897311f1df2a7016355c45eff

    PREFIX ${PROJECT_BINARY_DIR}/external/zlib

    CMAKE_ARGS
      -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX:STRING=${FIREBASE_INSTALL_DIR}
      -DBUILD_SHARED_LIBS:BOOL=OFF

    UPDATE_COMMAND ""
    TEST_COMMAND ""
  )
endif()
