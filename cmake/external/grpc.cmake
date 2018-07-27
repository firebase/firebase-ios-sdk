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

if(TARGET grpc)
  return()
endif()

ExternalProject_Add(
  grpc-download

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME grpc-1.8.3.tar.gz
  URL https://github.com/grpc/grpc/archive/v1.8.3.tar.gz
  URL_HASH SHA256=c14bceddc6475a09927a815811a8161cdfa7acb445262835da6bc24da9842c92

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/grpc

  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  TEST_COMMAND ""
  INSTALL_COMMAND ""
)

# gRPC depends upon these projects, so from an IWYU point of view should
# include these files. Unfortunately gRPC's build requires these to be
# subdirectories in its own source tree and CMake's ExternalProject download
# step clears the source tree so these must be declared to depend upon the grpc
# target. ExternalProject dependencies must already exist when declared so
# these must come after the ExternalProject_Add block above.
include(boringssl)
include(c-ares)
include(protobuf)
include(zlib)

add_custom_target(
  grpc
  DEPENDS
    boringssl
    c-ares
    grpc-download
    protobuf
    zlib
)
