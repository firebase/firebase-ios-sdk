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
  src/util/*.cc
  src/util/*.h
)

if(APPLE)
  firebase_ios_glob(
    util_sources APPEND src/util/*.mm
    EXCLUDE src/util/*_win.cc
  )

elseif(WIN32)
  firebase_ios_glob(
    util_sources EXCLUDE
    src/util/*_apple.*
    src/util/*_posix.*
  )

else()
  # Linux and other UNIX systems.
  firebase_ios_glob(
    util_sources EXCLUDE
    src/util/*_apple.cc
    src/util/*_win.cc
  )
endif()


# Choose Executor implementation

# Comment out this check on macOS to build with ExecutorStd instead of
# ExecutorLibdispatch.
check_symbol_exists(dispatch_async_f dispatch/dispatch.h HAVE_LIBDISPATCH)

firebase_ios_glob(
  util_sources EXCLUDE src/util/executor_*
)
if(HAVE_LIBDISPATCH)
  firebase_ios_glob(
    util_sources APPEND src/util/executor_libdispatch.*
  )
else()
  firebase_ios_glob(
    util_sources APPEND src/util/executor_std.*
  )
endif()


# Choose Logger implementation
firebase_ios_glob(
  util_sources EXCLUDE src/util/log_*
)

# TODO(wilhuff): Can this be if(APPLE)?
if(IOS)
  firebase_ios_glob(
    util_sources APPEND src/util/log_apple.mm
  )
else()
  firebase_ios_glob(
    util_sources APPEND src/util/log_stdio.cc
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
  util_sources EXCLUDE src/util/secure_random_*.cc
)
if(HAVE_ARC4RANDOM)
  firebase_ios_glob(
    util_sources APPEND
    src/util/secure_random_arc4random.cc
  )
elseif(HAVE_OPENSSL_RAND_H)
  firebase_ios_glob(
    util_sources APPEND
    src/util/secure_random_openssl.cc
  )
else()
  message(
    FATAL_ERROR
    "Don't know how to get high quality random numbers on this platform."
  )
endif()


configure_file(
  src/util/config_detected.h.in
  src/util/config_detected.h  # NOLINT(generated)
)


firebase_ios_add_library(firestore_util EXCLUDE_FROM_ALL ${util_sources})

target_compile_definitions(
  firestore_util PUBLIC
  FIRESTORE_HAVE_CONFIG_DETECTED_H
)

target_link_libraries(
  firestore_util PUBLIC
  absl::base
  absl::flat_hash_map
  absl::memory
  absl::meta
  absl::optional
  absl::strings
  absl::time
)

if(HAVE_OPENSSL_RAND_H)
  target_link_libraries(
    firestore_util PRIVATE
    OpenSSL::Crypto
  )
endif()

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
  src/nanopb/byte_string.*
  src/nanopb/nanopb_util.*
  src/nanopb/pretty_printing.*
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
  src/*.cc
  src/*.h
  src/api/*.cc
  src/api/*.h
  src/auth/*.cc
  src/auth/*.h
  src/bundle/*.cc
  src/bundle/*.h
  src/core/*.cc
  src/core/*.h
  src/immutable/*.cc
  src/immutable/*.h
  src/local/*.cc
  src/local/*.h
  src/model/*.cc
  src/model/*.h
  src/nanopb/*.cc
  src/nanopb/*.h
  src/objc/*.h
  src/remote/*.cc
  src/remote/*.h
  EXCLUDE ${nanopb_sources}
)

if(APPLE)
  firebase_ios_glob(
    core_sources APPEND
    src/auth/firebase_credentials_provider_apple.*
    src/remote/connectivity_monitor_apple.mm
    src/remote/firebase_metadata_provider_apple.mm
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
  absl::base
  absl::flat_hash_map
  absl::memory
  absl::meta
  absl::optional
  absl::strings
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
set(OUTPUT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/remote)

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


add_subdirectory(test/unit/testutil)
add_subdirectory(test/unit)
add_subdirectory(test/unit/api)
add_subdirectory(test/unit/auth)
add_subdirectory(test/unit/bundle)
add_subdirectory(test/unit/core)
add_subdirectory(test/unit/immutable)
add_subdirectory(test/unit/local)
add_subdirectory(test/unit/model)
add_subdirectory(test/unit/objc)
add_subdirectory(test/unit/nanopb)
add_subdirectory(test/unit/remote)
add_subdirectory(test/unit/util)
