# Copyright 2017 Google LLC
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

include(CheckSymbolExists)
include(CheckIncludeFiles)


## firestore_util

# The set of sources to use for firestore_util are complex.
file(
  GLOB util_sources
  src/firebase/firestore/util/*.cc
  src/firebase/firestore/util/*.h
)

if(APPLE)
  firebase_ios_glob(
    util_sources APPEND src/firebase/firestore/util/*.mm
    EXCLUDE src/firebase/firestore/util/*_win.cc
  )

elseif(WIN32)
  firebase_ios_glob(
    util_sources EXCLUDE
    src/firebase/firestore/util/*_apple.*
    src/firebase/firestore/util/*_posix.*
  )

else()
  # Linux and other UNIX systems.
  firebase_ios_glob(
    util_sources EXCLUDE
    src/firebase/firestore/util/*_apple.cc
    src/firebase/firestore/util/*_win.cc
  )
endif()


# Choose Executor implementation

# Comment out this check on macOS to build with ExecutorStd instead of
# ExecutorLibdispatch.
check_symbol_exists(dispatch_async_f dispatch/dispatch.h HAVE_LIBDISPATCH)

firebase_ios_glob(
  util_sources EXCLUDE src/firebase/firestore/util/executor_*
)
if(HAVE_LIBDISPATCH)
  firebase_ios_glob(
    util_sources APPEND src/firebase/firestore/util/executor_libdispatch.*
  )
else()
  firebase_ios_glob(
    util_sources APPEND src/firebase/firestore/util/executor_std.*
  )
endif()


# Choose Logger implementation
firebase_ios_glob(
  util_sources EXCLUDE src/firebase/firestore/util/log_*
)

# TODO(wilhuff): Can this be if(APPLE)?
if(IOS)
  firebase_ios_glob(
    util_sources APPEND src/firebase/firestore/util/log_apple.mm
  )
else()
  firebase_ios_glob(
    util_sources APPEND src/firebase/firestore/util/log_stdio.cc
  )
endif()


# Choose SecureRandom implementation
check_symbol_exists(arc4random stdlib.h HAVE_ARC4RANDOM)

if(TARGET OpenSSL::Crypto)
  get_target_property(
    CMAKE_REQUIRED_INCLUDES OpenSSL::Crypto INTERFACE_INCLUDE_DIRECTORIES
  )
  check_include_files(openssl/rand.h HAVE_OPENSSL_RAND_H)
endif()

firebase_ios_glob(
  util_sources EXCLUDE src/firebase/firestore/util/secure_random_*.cc
)
if(HAVE_ARC4RANDOM)
  firebase_ios_glob(
    util_sources APPEND
    src/firebase/firestore/util/secure_random_arc4random.cc
  )
elseif(HAVE_OPENSSL_RAND_H)
  firebase_ios_glob(
    util_sources APPEND
    src/firebase/firestore/util/secure_random_openssl.cc
  )
else()
  message(
    FATAL_ERROR
    "Don't know how to get high quality random numbers on this platform."
  )
endif()


configure_file(
  src/firebase/firestore/util/config.h.in
  src/firebase/firestore/util/config.h  # NOLINT(generated)
)


firebase_ios_add_library(firestore_util EXCLUDE_FROM_ALL ${util_sources})

target_link_libraries(
  firestore_util PUBLIC
  absl_base
  absl_memory
  absl_meta
  absl_optional
  absl_strings
)

if(APPLE)
  target_link_libraries(
    firestore_util PUBLIC
    "-framework CoreFoundation"
    "-framework Foundation"
    FirebaseCore
  )
endif()


## firestore_nanopb

# Nanopb-related utilities that not specific to Firestore and are used from
# generated nanopb messages.

firebase_ios_glob(
  nanopb_sources
  src/firebase/firestore/nanopb/byte_string.*
  src/firebase/firestore/nanopb/nanopb_util.*
  src/firebase/firestore/nanopb/pretty_printing.*
)

firebase_ios_add_library(firestore_nanopb EXCLUDE_FROM_ALL ${nanopb_sources})

target_link_libraries(
  firestore_nanopb PUBLIC
  absl_strings
  firestore_util
  protobuf-nanopb-static
)


## firestore_core


firebase_ios_glob(
  core_sources
  include/firebase/firestore/*.h
  src/firebase/firestore/*.cc
  src/firebase/firestore/*.h
  src/firebase/firestore/api/*.cc
  src/firebase/firestore/api/*.h
  src/firebase/firestore/auth/*.cc
  src/firebase/firestore/auth/*.h
  src/firebase/firestore/core/*.cc
  src/firebase/firestore/core/*.h
  src/firebase/firestore/immutable/*.cc
  src/firebase/firestore/immutable/*.h
  src/firebase/firestore/local/*.cc
  src/firebase/firestore/local/*.h
  src/firebase/firestore/model/*.cc
  src/firebase/firestore/model/*.h
  src/firebase/firestore/nanopb/*.cc
  src/firebase/firestore/nanopb/*.h
  src/firebase/firestore/objc/*.h
  src/firebase/firestore/remote/*.cc
  src/firebase/firestore/remote/*.h
  EXCLUDE ${nanopb_sources}
)

if(APPLE)
  firebase_ios_glob(
    core_sources APPEND
    src/firebase/firestore/auth/firebase_credentials_provider_apple.*
    src/firebase/firestore/remote/connectivity_monitor_apple.mm
  )
endif()


firebase_ios_add_library(firestore_core ${core_sources})

podspec_version(version ${PROJECT_SOURCE_DIR}/FirebaseFirestore.podspec)

target_compile_definitions(
  firestore_core PRIVATE
  FIRFirestore_VERSION=${version}
)

target_include_directories(
  firestore_core PUBLIC
  ${PROJECT_SOURCE_DIR}/Firestore/core/include
)

target_link_libraries(
  firestore_core PUBLIC
  LevelDB::LevelDB
  absl_base
  absl_memory
  absl_meta
  absl_optional
  absl_strings
  firestore_nanopb
  firestore_protos_nanopb
  firestore_util
  grpc++
  protobuf-nanopb-static
)

if(APPLE)
  target_link_libraries(
    firestore_core PUBLIC
    "-framework Foundation"
    "-framework SystemConfiguration"
    FirebaseAuthInterop
    FirebaseCore
  )
endif()


## gRPC Certificates

# Source files should be generated in place so that the XCode build can pick
# them up.
set(OUTPUT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/firebase/firestore/remote)

set(
  GRPC_ROOT_CERTIFICATE_SOURCES
  ${OUTPUT_DIR}/grpc_root_certificates_generated.h  # NOLINT(generated)
  ${OUTPUT_DIR}/grpc_root_certificates_generated.cc # NOLINT(generated)
)

# `roots.pem` is a file containing root certificates that is distributed
# alongside gRPC and is necessary to establish SSL connections. Embed this file
# into the binary by converting it to a char array.
add_custom_command(
  COMMENT "Generating root certificates for embedding"
  OUTPUT
  ${GRPC_ROOT_CERTIFICATE_SOURCES}
  COMMAND
  python ${FIREBASE_SOURCE_DIR}/scripts/binary_to_array.py
  --output_header=${OUTPUT_DIR}/grpc_root_certificates_generated.h
  --output_source=${OUTPUT_DIR}/grpc_root_certificates_generated.cc
  --cpp_namespace=firebase::firestore::remote
  --array=grpc_root_certificates_generated_data
  --array_size=grpc_root_certificates_generated_size
  ${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/etc/roots.pem
  VERBATIM
  DEPENDS
  grpc
  ${FIREBASE_SOURCE_DIR}/scripts/binary_to_array.py
  ${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/etc/roots.pem
)

# gRPC certificates have to be regenerated manually on each new gRPC release
# (which typically has updated certificates).
add_custom_target(
  firestore_gen_grpc_certs
  DEPENDS ${GRPC_ROOT_CERTIFICATE_SOURCES}
)


add_subdirectory(test/firebase/firestore/testutil)
add_subdirectory(test/firebase/firestore)
add_subdirectory(test/firebase/firestore/api)
add_subdirectory(test/firebase/firestore/auth)
add_subdirectory(test/firebase/firestore/core)
add_subdirectory(test/firebase/firestore/immutable)
add_subdirectory(test/firebase/firestore/local)
add_subdirectory(test/firebase/firestore/model)
add_subdirectory(test/firebase/firestore/objc)
add_subdirectory(test/firebase/firestore/nanopb)
add_subdirectory(test/firebase/firestore/remote)
add_subdirectory(test/firebase/firestore/util)
