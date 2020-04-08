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

check_symbol_exists(dispatch_async_f dispatch/dispatch.h HAVE_LIBDISPATCH)

check_symbol_exists(arc4random stdlib.h HAVE_ARC4RANDOM)

if(TARGET OpenSSL::Crypto)
  get_target_property(
    CMAKE_REQUIRED_INCLUDES OpenSSL::Crypto INTERFACE_INCLUDE_DIRECTORIES
  )
  check_include_files(openssl/rand.h HAVE_OPENSSL_RAND_H)
endif()

configure_file(
  src/firebase/firestore/util/config.h.in
  src/firebase/firestore/util/config.h  # NOLINT(generated)
)

firebase_ios_add_library(
  firestore_util EXCLUDE_FROM_ALL
  src/firebase/firestore/util/async_queue.cc
  src/firebase/firestore/util/async_queue.h
  src/firebase/firestore/util/autoid.cc
  src/firebase/firestore/util/autoid.h
  src/firebase/firestore/util/background_queue.cc
  src/firebase/firestore/util/background_queue.h
  src/firebase/firestore/util/bits.cc
  src/firebase/firestore/util/bits.h
  src/firebase/firestore/util/comparison.cc
  src/firebase/firestore/util/comparison.h
  src/firebase/firestore/util/compressed_member.h
  src/firebase/firestore/util/config.h
  src/firebase/firestore/util/delayed_constructor.h
  src/firebase/firestore/util/empty.h
  src/firebase/firestore/util/equality.h
  src/firebase/firestore/util/exception.cc
  src/firebase/firestore/util/exception.h
  src/firebase/firestore/util/hard_assert.cc
  src/firebase/firestore/util/hard_assert.h
  src/firebase/firestore/util/hashing.h
  src/firebase/firestore/util/iterator_adaptors.h
  src/firebase/firestore/util/nullability.h
  src/firebase/firestore/util/ordered_code.cc
  src/firebase/firestore/util/ordered_code.h
  src/firebase/firestore/util/path.cc
  src/firebase/firestore/util/path.h
  src/firebase/firestore/util/range.h
  src/firebase/firestore/util/sanitizers.h
  src/firebase/firestore/util/secure_random.h
  src/firebase/firestore/util/status.cc
  src/firebase/firestore/util/status.h
  src/firebase/firestore/util/status_fwd.h
  src/firebase/firestore/util/status_posix.cc
  src/firebase/firestore/util/status_win.cc
  src/firebase/firestore/util/statusor.cc
  src/firebase/firestore/util/statusor.h
  src/firebase/firestore/util/statusor_internals.h
  src/firebase/firestore/util/strerror.cc
  src/firebase/firestore/util/strerror.h
  src/firebase/firestore/util/string_format.cc
  src/firebase/firestore/util/string_format.h
  src/firebase/firestore/util/string_util.cc
  src/firebase/firestore/util/string_util.h
  src/firebase/firestore/util/to_string.h
  src/firebase/firestore/util/type_traits.h
  src/firebase/firestore/util/warnings.h
)

target_link_libraries(
  firestore_util PUBLIC
  absl_base
  absl_memory
  absl_meta
  absl_optional
  absl_strings
)

if(APPLE)
  target_sources(
    firestore_util PRIVATE
    src/firebase/firestore/util/error_apple.h
    src/firebase/firestore/util/error_apple.mm
    src/firebase/firestore/util/exception_apple.h
    src/firebase/firestore/util/exception_apple.mm
    src/firebase/firestore/util/executor.h
    src/firebase/firestore/util/executor_libdispatch.h
    src/firebase/firestore/util/executor_libdispatch.mm
    src/firebase/firestore/util/filesystem.h
    src/firebase/firestore/util/filesystem_apple.mm
    src/firebase/firestore/util/filesystem_common.cc
    src/firebase/firestore/util/filesystem_posix.cc
    src/firebase/firestore/util/log.h
    src/firebase/firestore/util/log_apple.mm
    src/firebase/firestore/util/secure_random_arc4random.cc
    src/firebase/firestore/util/status_apple.mm
    src/firebase/firestore/util/string_apple.cc
    src/firebase/firestore/util/string_apple.h
  )

  target_link_libraries(
    firestore_util PUBLIC
    "-framework CoreFoundation"
    "-framework Foundation"
    FirebaseCore
  )

elseif(WIN32)
  target_sources(
    firestore_util PRIVATE
    src/firebase/firestore/util/executor.h
    src/firebase/firestore/util/executor_std.cc
    src/firebase/firestore/util/executor_std.h
    src/firebase/firestore/util/filesystem.h
    src/firebase/firestore/util/filesystem_common.cc
    src/firebase/firestore/util/filesystem_win.cc
    src/firebase/firestore/util/log.h
    src/firebase/firestore/util/log_stdio.cc
    src/firebase/firestore/util/secure_random_openssl.cc
    src/firebase/firestore/util/string_win.cc
    src/firebase/firestore/util/string_win.h
  )

else()
  target_sources(
    firestore_util PRIVATE
    src/firebase/firestore/util/executor.h
    src/firebase/firestore/util/executor_std.cc
    src/firebase/firestore/util/executor_std.h
    src/firebase/firestore/util/filesystem.h
    src/firebase/firestore/util/filesystem_common.cc
    src/firebase/firestore/util/filesystem_posix.cc
    src/firebase/firestore/util/log.h
    src/firebase/firestore/util/log_stdio.cc
    src/firebase/firestore/util/secure_random_openssl.cc
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
