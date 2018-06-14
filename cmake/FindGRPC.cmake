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

include(FindPackageHandleStandardArgs)
include(FindZLIB)

set(BINARY_DIR ${FIREBASE_BINARY_DIR}/external/grpc)

## ZLIB

# the grpc ExternalProject already figures out if zlib should be built or
# referenced from its installed location. If it elected to allow grpc to build
# zlib then it will be available at this location.
find_library(
  ZLIB_LIBRARY
  NAMES z
  HINTS ${BINARY_DIR}/src/grpc-build/third_party/zlib
)

# If found above, the standard package will honor the ZLIB_LIBRARY variable.
find_package(ZLIB REQUIRED)


## BoringSSL/OpenSSL

find_path(
  OPENSSL_INCLUDE_DIR openssl/ssl.h
  HINTS ${BINARY_DIR}/src/grpc/third_party/boringssl/include
)

find_library(
  OPENSSL_SSL_LIBRARY
  NAMES ssl
  HINTS ${BINARY_DIR}/src/grpc-build/third_party/boringssl/ssl
)

find_library(
  OPENSSL_CRYPTO_LIBRARY
  NAMES crypto
  HINTS ${BINARY_DIR}/src/grpc-build/third_party/boringssl/crypto
)

find_package(OpenSSL REQUIRED)


## C-Ares

find_library(
  CARES_LIBRARY
  NAMES cares
  HINTS ${BINARY_DIR}/src/grpc-build/third_party/cares/cares/lib
)
if(NOT (CARES_LIBRARY STREQUAL "CARES_LIBRARY-NOTFOUND"))
  if (NOT TARGET c-ares::ares)
    add_library(c-ares::ares UNKNOWN IMPORTED)
    set_target_properties(
      c-ares::ares PROPERTIES
      IMPORTED_LOCATION ${CARES_LIBRARY}
    )
  endif()
endif()


## GRPC

find_path(
  GRPC_INCLUDE_DIR grpc/grpc.h
  HINTS
    $ENV{GRPC_ROOT}/include
    ${GRPC_ROOT}/include
    ${BINARY_DIR}/src/grpc/include
)

find_library(
  GPR_LIBRARY
  NAMES gpr
  HINTS
    $ENV{GRPC_ROOT}/lib
    ${GRPC_ROOT}/lib
    ${BINARY_DIR}/src/grpc-build
)

find_library(
  GRPC_LIBRARY
  NAMES grpc
  HINTS
    $ENV{GRPC_ROOT}/lib
    ${GRPC_ROOT}/lib
    ${BINARY_DIR}/src/grpc-build
)

find_package_handle_standard_args(
  gRPC
  DEFAULT_MSG
  GRPC_INCLUDE_DIR
  GRPC_LIBRARY
  GPR_LIBRARY
)

if(GRPC_FOUND)
  set(GRPC_INCLUDE_DIRS ${GRPC_INCLUDE_DIR})
  set(GRPC_LIBRARIES ${GRPC_LIBRARY})

  if (NOT TARGET grpc::gpr)
    add_library(grpc::gpr UNKNOWN IMPORTED)
    set_target_properties(
      grpc::gpr PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${GRPC_INCLUDE_DIR}
      IMPORTED_LOCATION ${GPR_LIBRARY}
    )
  endif()

  if (NOT TARGET grpc::grpc)
    set(
      GRPC_LINK_LIBRARIES
      c-ares::ares
      grpc::gpr
      OpenSSL::SSL
      OpenSSL::Crypto
      ZLIB::ZLIB
    )

    add_library(grpc::grpc UNKNOWN IMPORTED)
    set_target_properties(
      grpc::grpc PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${GRPC_INCLUDE_DIR}
      INTERFACE_LINK_LIBRARIES "${GRPC_LINK_LIBRARIES}"
      IMPORTED_LOCATION ${GRPC_LIBRARY}
    )
  endif()
endif(GRPC_FOUND)
