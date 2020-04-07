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


add_subdirectory(include/firebase/firestore)

add_subdirectory(src/firebase/firestore)
add_subdirectory(src/firebase/firestore/api)
add_subdirectory(src/firebase/firestore/auth)
add_subdirectory(src/firebase/firestore/core)
add_subdirectory(src/firebase/firestore/immutable)
add_subdirectory(src/firebase/firestore/local)
add_subdirectory(src/firebase/firestore/model)
add_subdirectory(src/firebase/firestore/nanopb)
add_subdirectory(src/firebase/firestore/objc)
add_subdirectory(src/firebase/firestore/remote)


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


# Emulate the new combined firestore_core and firestore_util libraries with
# interface libraries. CMake interface libraries pass their dependencies and
# settings through to any consumers, allowing dependees to migrate to this form
# incrementally.
#
# TODO(wilhuff): Replace these with an actual combined libraries.

add_library(firestore_nanopb INTERFACE)

target_link_libraries(
  firestore_nanopb INTERFACE
  firebase_firestore_nanopb_runtime
)


add_library(firestore_core INTERFACE)

target_link_libraries(
  firestore_core INTERFACE
  firebase_firestore_api
  firebase_firestore_auth
  firebase_firestore_core
  firebase_firestore_immutable
  firebase_firestore_local
  firebase_firestore_local_persistence_leveldb
  firebase_firestore_model
  firebase_firestore_nanopb
  firebase_firestore_remote
  firebase_firestore_types

  firestore_util
)

if(APPLE)
  target_link_libraries(
    firestore_core INTERFACE
    firebase_firestore_auth_apple
  )
endif()

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
