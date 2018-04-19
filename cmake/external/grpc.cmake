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
include(FindZLIB)

if(GRPC_ROOT)
  # If the user has supplied a GRPC_ROOT then just use it. Add an empty custom
  # target so that the superbuild dependencies still work.
  add_custom_target(grpc)

else()
  set(
    GIT_SUBMODULES
    third_party/boringssl
    third_party/cares/cares
  )

  set(
    CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
    -DgRPC_BUILD_TESTS:BOOL=OFF
    -DBUILD_SHARED_LIBS:BOOL=OFF
  )

  # zlib can be built by grpc but we can avoid it on platforms that provide it
  # by default.
  find_package(ZLIB)
  if(ZLIB_FOUND)
    list(
      APPEND CMAKE_ARGS
      -DgRPC_ZLIB_PROVIDER:STRING=package
      -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR}
      -DZLIB_LIBRARY=${ZLIB_LIBRARY}
    )

  else()
    list(
      APPEND GIT_SUBMODULES
      third_party/zlib
    )

  endif(ZLIB_FOUND)

  ExternalProject_GitSource(
    GRPC_GIT
    GIT_REPOSITORY "https://github.com/grpc/grpc.git"
    GIT_TAG "v1.8.3"
    GIT_SUBMODULES ${GIT_SUBMODULES}
  )

  ExternalProject_Add(
    grpc

    ${GRPC_GIT}

    PREFIX ${PROJECT_BINARY_DIR}/external/grpc

    # TODO(rsgowman): We're currently building nanopb twice; once via grpc, and
    # once via nanopb. The version from grpc is the one that actually ends up
    # being used. We need to fix this such that either:
    # a) we instruct grpc to use our nanopb
    # b) we rely on grpc's nanopb instead of using our own.
    # For now, we'll pass in the necessary nanopb cflags into grpc. (We require
    # 16 bit fields. Without explicitly requesting this, nanopb uses 8 bit
    # fields.)
    CMAKE_ARGS ${CMAKE_ARGS};-DCMAKE_C_FLAGS=-DPB_FIELD_16BIT;DCMAKE_CXX_FLAGS=-DPB_FIELD_16BIT

    BUILD_COMMAND
      ${CMAKE_COMMAND} --build . --target grpc

    UPDATE_COMMAND ""
    TEST_COMMAND ""
    INSTALL_COMMAND ""
  )

endif(GRPC_ROOT)

