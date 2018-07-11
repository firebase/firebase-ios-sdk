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
include(external/c-ares)
include(external/protobuf)
include(external/zlib)

if(TARGET grpc)
  return()
endif()

if(GRPC_ROOT)
  # If the user has supplied a GRPC_ROOT then just use it. Add an empty custom
  # target so that the superbuild dependencies still work.
  add_custom_target(grpc)
  return()
endif()

set(
  CMAKE_ARGS
  -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
  -DBUILD_SHARED_LIBS:BOOL=OFF
  -DgRPC_INSTALL:BOOL=OFF
  -DgRPC_BUILD_TESTS:BOOL=OFF

  # TODO(rsgowman): We're currently building nanopb twice; once via grpc, and
  # once via nanopb. The version from grpc is the one that actually ends up
  # being used. We need to fix this such that either:
  #   a) we instruct grpc to use our nanopb
  #   b) we rely on grpc's nanopb instead of using our own.
  # For now, we'll pass in the necessary nanopb cflags into grpc. (We require
  # 16 bit fields. Without explicitly requesting this, nanopb uses 8 bit
  # fields.)
  -DCMAKE_C_FLAGS=-DPB_FIELD_16BIT
  -DCMAKE_CXX_FLAGS=-DPB_FIELD_16BIT
)


## c-ares
if(NOT c-ares_DIR)
  set(c-ares_DIR ${FIREBASE_INSTALL_DIR}/lib/cmake/c-ares)
endif()

list(
  APPEND CMAKE_ARGS
  -DgRPC_CARES_PROVIDER:STRING=package
  -Dc-ares_DIR:PATH=${c-ares_DIR}
)


## protobuf

# Unlike other dependencies of gRPC, we control the protobuf version because we
# have checked-in protoc outputs that must match the runtime.

# The location where protobuf-config.cmake will be installed varies by platform
if(NOT Protobuf_DIR)
  if(WIN32)
    set(Protobuf_DIR "${FIREBASE_INSTALL_DIR}/cmake")
  else()
    set(Protobuf_DIR "${FIREBASE_INSTALL_DIR}/lib/cmake/protobuf")
  endif()
endif()

list(
  APPEND CMAKE_ARGS
  -DgRPC_PROTOBUF_PROVIDER:STRING=package
  -DgRPC_PROTOBUF_PACKAGE_TYPE:STRING=CONFIG
  -DProtobuf_DIR:PATH=${Protobuf_DIR}
)


## zlib

# cmake/external/zlib.cmake figures out whether or not to build zlib. Either
# way, from the gRPC build's point of view it's a package.
list(
  APPEND CMAKE_ARGS
  -DgRPC_ZLIB_PROVIDER:STRING=package
)
if(ZLIB_FOUND)
  # Propagate possible user configuration to FindZLIB.cmake in the sub-build.
  list(
    APPEND CMAKE_ARGS
    -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR}
    -DZLIB_LIBRARY=${ZLIB_LIBRARY}
  )
endif()


ExternalProject_Add(
  grpc-download
  DEPENDS
    c-ares
    protobuf
    zlib

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
include(external/boringssl)

ExternalProject_Add(
  grpc
  DEPENDS
    boringssl
    grpc-download

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/grpc

  CMAKE_ARGS
    ${CMAKE_ARGS}

  BUILD_COMMAND
    ${CMAKE_COMMAND} --build . --target grpc

  UPDATE_COMMAND ""
  TEST_COMMAND ""
  INSTALL_COMMAND ""
)
