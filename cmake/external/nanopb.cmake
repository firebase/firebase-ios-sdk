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
include(ExternalProjectFlags)

ExternalProject_GitSource(
  NANOPB_GIT
  GIT_REPOSITORY "https://github.com/nanopb/nanopb.git"
  GIT_TAG "master" # Needs the most recent. 0.3.9 doesn't fully support cmake.
)

ExternalProject_Add(
  nanopb
  DEPENDS
    protobuf

  ${NANOPB_GIT}

  PREFIX ${PROJECT_BINARY_DIR}/external/nanopb

  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
    -DBUILD_SHARED_LIBS:BOOL=OFF
    -Dnanopb_BUILD_GENERATOR:BOOL=ON
    -Dnanopb_PROTOC_PATH:STRING=${FIREBASE_INSTALL_DIR}/external/protobuf/src/protobuf-build/src/protoc

  BUILD_COMMAND
    ${CMAKE_COMMAND} --build .
  # NB: The following additional build commands are only necessary to
  # regenerate the nanopb proto files.
  COMMAND
    ${CMAKE_COMMAND} -E make_directory <BINARY_DIR>/generator/proto
  COMMAND
    ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/generator/proto/__init__.py <BINARY_DIR>/generator/proto/
  COMMAND
    ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/generator/protoc-gen-nanopb <BINARY_DIR>/generator/
  COMMAND
    ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/generator/nanopb_generator.py <BINARY_DIR>/generator/
  COMMAND
    ${CMAKE_COMMAND} -E copy <BINARY_DIR>/nanopb_pb2.py <BINARY_DIR>/generator/proto/
  COMMAND
    ${CMAKE_COMMAND} -E copy <BINARY_DIR>/plugin_pb2.py <BINARY_DIR>/generator/proto/

  # TODO: once we clone via a tag (rather than the master branch) we should
  # disable updates; i.e.:
  #   UPDATE_COMMAND ""

  INSTALL_COMMAND ""
)
