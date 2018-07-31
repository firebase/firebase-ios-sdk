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

if(TARGET leveldb)
  return()
endif()

if(WIN32)
  # Unfortunately, LevelDB does not build on Windows (yet). See:
  #
  #   * https://github.com/google/leveldb/issues/363
  #   * https://github.com/google/leveldb/issues/466
  add_custom_target(leveldb)
  return()
endif()

# CMake support was added after the 1.20 release
set(commit 6caf73ad9dae0ee91873bcb39554537b85163770)  # master@{2018-07-14}

ExternalProject_Add(
  leveldb

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME leveldb-${commit}.tar.gz
  URL https://github.com/google/leveldb/archive/${commit}.tar.gz
  URL_HASH SHA256=255e3283556aff81e337a951c5f5579f5b98b63d5f345db9e97a1f7563f54f9e

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
)
