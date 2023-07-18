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

include(python_setup)
FirebaseSetupPythonInterpreter(
  OUTVAR MY_PYTHON_EXECUTABLE
  KEY LevelDbPatch
)

if(TARGET leveldb)
  return()
endif()

set(version 1.22)

ExternalProject_Get_property(snappy SOURCE_DIR)
set(snappy_source_dir "${SOURCE_DIR}")
ExternalProject_Get_property(snappy BINARY_DIR)
set(snappy_binary_dir "${BINARY_DIR}")

set(additional_patch_file ${CMAKE_CURRENT_LIST_DIR}/leveldb-${version}_windows_paths.patch)

ExternalProject_Add(
  leveldb

  DEPENDS snappy

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  GIT_REPOSITORY https://github.com/google/leveldb.git
  GIT_TAG "${version}"

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
  PATCH_COMMAND     "${MY_PYTHON_EXECUTABLE}" ${CMAKE_CURRENT_LIST_DIR}/leveldb_patch.py --snappy-source-dir ${snappy_source_dir} --snappy-binary-dir ${snappy_binary_dir} --additional-patch-file ${additional_patch_file}

  HTTP_HEADER "${EXTERNAL_PROJECT_HTTP_HEADER}"
)
