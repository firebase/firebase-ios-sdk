# Copyright 2018 Google # # Licensed under the Apache License, Version 2.0 (the "License");
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
  NANOPB_GIT
  GIT_REPOSITORY "https://github.com/nanopb/nanopb.git"
  GIT_TAG "0.3.8"
)

set(
  NANOPB_PROTOC_BIN
  ${FIREBASE_INSTALL_DIR}/external/protobuf/src/protobuf-build/src/protoc
)

ExternalProject_Add(
  nanopb
  DEPENDS
    protobuf

  ${NANOPB_GIT}

  BUILD_IN_SOURCE ON

  PREFIX ${PROJECT_BINARY_DIR}/external/nanopb

  # Note for (not yet released) nanopb 0.4.0: nanopb will (likely) switch to
  # cmake for the protoc plugin. Set these additional cmake variables to use
  # it.
  #   -Dnanopb_BUILD_GENERATOR:BOOL=ON
  #   -Dnanopb_PROTOC_PATH:STRING=${FIREBASE_INSTALL_DIR}/external/protobuf/src/protobuf-build/src/protoc
  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
    -DBUILD_SHARED_LIBS:BOOL=OFF

  BUILD_COMMAND
  COMMAND
    ${CMAKE_COMMAND} --build .
  # NB: The following additional command is only necessary to regenerate the
  # nanopb proto files.
  COMMAND
    make -C <SOURCE_DIR>/generator/proto

  # nanopb relies on $PATH for the location of protoc. cmake makes it difficult
  # to adjust the path, so we'll just patch the build files with the exact
  # location of protoc.
  #
  # NB: cmake sometimes runs the patch command multiple times in the same src
  # dir, so we need to make sure this is idempotent. (eg 'make && make clean &&
  # make')
  PATCH_COMMAND
    grep ${NANOPB_PROTOC_BIN} ./generator/proto/Makefile
      || perl -i -pe s,protoc,${NANOPB_PROTOC_BIN},g
           ./CMakeLists.txt ./generator/proto/Makefile

  UPDATE_COMMAND ""
  INSTALL_COMMAND ""
)
