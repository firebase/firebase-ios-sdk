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

if(WIN32 OR LEVELDB_ROOT)
  # If the user has supplied a LEVELDB_ROOT then just use it. Add an empty
  # custom target so that the superbuild depdendencies don't all have to be
  # conditional.
  #
  # Also, unfortunately, LevelDB does not build on Windows (yet)
  # See:
  #   https://github.com/google/leveldb/issues/363
  #   https://github.com/google/leveldb/issues/466
  add_custom_target(leveldb)

else()
  # Clean up warning output to reduce noise in the build
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    set(
      LEVELDB_CXX_FLAGS "\
        -Wno-deprecated-declarations"
    )
  endif()

  # Map CMake compiler configuration down onto the leveldb Makefile
  set(
    LEVELDB_OPT "\
      $<$<CONFIG:Debug>:${CMAKE_CXX_FLAGS_DEBUG}> \
      $<$<CONFIG:Release>:${CMAKE_CXX_FLAGS_RELEASE}>"
  )

  ExternalProject_Add(
    leveldb

    GIT_REPOSITORY "https://github.com/google/leveldb.git"
    GIT_TAG "v1.20"

    PREFIX ${PROJECT_BINARY_DIR}/third_party/leveldb

    CONFIGURE_COMMAND ""
    BUILD_ALWAYS ON
    BUILD_IN_SOURCE ON
    BUILD_COMMAND
      env CXXFLAGS=${LEVELDB_CXX_FLAGS} OPT=${LEVELDB_OPT} make -j all

    INSTALL_DIR ${FIREBASE_INSTALL_DIR}

    INSTALL_COMMAND ""
    TEST_COMMAND ""
  )
endif(WIN32 OR LEVELDB_ROOT)
