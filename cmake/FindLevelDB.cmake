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

set(binary_dir ${FIREBASE_BINARY_DIR}/src/leveldb)

find_path(
  LEVELDB_INCLUDE_DIR leveldb/db.h
  HINTS
    $ENV{LEVELDB_ROOT}/include
    ${LEVELDB_ROOT}/include
    ${binary_dir}/include
  PATH_SUFFIXES leveldb
)

find_library(
  LEVELDB_LIBRARY
  NAMES leveldb
  HINTS
    $ENV{LEVELDB_ROOT}/lib
    ${LEVELDB_ROOT}/lib
    ${binary_dir}/out-static
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  LevelDB
  DEFAULT_MSG
  LEVELDB_INCLUDE_DIR
  LEVELDB_LIBRARY
)

if(LEVELDB_FOUND)
  set(LEVELDB_INCLUDE_DIRS ${LEVELDB_INCLUDE_DIR})
  set(LEVELDB_LIBRARIES ${LEVELDB_LIBRARY})

  if (NOT TARGET LevelDB::LevelDB)
    add_library(LevelDB::LevelDB UNKNOWN IMPORTED)
    set_target_properties(
      LevelDB::LevelDB PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${LEVELDB_INCLUDE_DIR}
      IMPORTED_LOCATION ${LEVELDB_LIBRARY}
    )
  endif()
endif(LEVELDB_FOUND)
