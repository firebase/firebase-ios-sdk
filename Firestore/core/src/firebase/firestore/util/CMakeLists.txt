# Copyright 2017 Google
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

# firebase_firestore_util is the interface of this module. The rest of the
# libraries in here are an implementation detail of making this a
# mutli-platform build.

include(CheckSymbolExists)
include(CheckIncludeFiles)


## async

check_symbol_exists(dispatch_async_f dispatch/dispatch.h HAVE_LIBDISPATCH)

cc_library(
  firebase_firestore_util_async_std
  SOURCES
    async_queue.cc
    async_queue.h
    executor_std.cc
    executor_std.h
    executor.h
  DEPENDS
    absl_bad_optional_access
    absl_optional
    firebase_firestore_util_base
  EXCLUDE_FROM_ALL
)

cc_library(
  firebase_firestore_util_async_libdispatch
  SOURCES
    async_queue.cc
    async_queue.h
    executor_libdispatch.mm
    executor_libdispatch.h
    executor.h
  DEPENDS
    absl_bad_optional_access
    absl_optional
    absl_strings
    firebase_firestore_util_base
  EXCLUDE_FROM_ALL
)

cc_select(
  firebase_firestore_util_async
  HAVE_LIBDISPATCH firebase_firestore_util_async_libdispatch
  DEFAULT          firebase_firestore_util_async_std
)


## base

cc_library(
  firebase_firestore_util_base_stdio
  SOURCES
    exception.cc
    exception.h
    hard_assert.cc
    hard_assert.h
    log.h
    log_stdio.cc
    string_format.cc
    string_format.h
    string_win.cc
    string_win.h
  DEPENDS
    absl_base
    absl_strings
  EXCLUDE_FROM_ALL
)

cc_library(
  firebase_firestore_util_base_apple
  SOURCES
    exception.cc
    exception.h
    exception_apple.h
    exception_apple.mm
    hard_assert.cc
    hard_assert.h
    log.h
    log_apple.mm
    string_apple.cc
    string_apple.h
    string_format.cc
    string_format.h
  DEPENDS
    FirebaseCore
    absl_base
    absl_strings
  EXCLUDE_FROM_ALL
)

cc_select(
  firebase_firestore_util_base
  APPLE   firebase_firestore_util_base_apple
  DEFAULT firebase_firestore_util_base_stdio
)


## filesystem

cc_library(
  firebase_firestore_util_filesystem_apple
  SOURCES
    filesystem.h
    filesystem_apple.mm
    filesystem_common.cc
    filesystem_posix.cc
    path.cc
    path.h
  DEPENDS
    absl_strings
    firebase_firestore_util_status
  EXCLUDE_FROM_ALL
)

cc_library(
  firebase_firestore_util_filesystem_posix
  SOURCES
    filesystem.h
    filesystem_common.cc
    filesystem_posix.cc
    path.cc
    path.h
  DEPENDS
    absl_strings
    firebase_firestore_util_status
  EXCLUDE_FROM_ALL
)

cc_library(
  firebase_firestore_util_filesystem_win
  SOURCES
    filesystem.h
    filesystem_common.cc
    filesystem_win.cc
    path.cc
    path.h
  DEPENDS
    absl_strings
    firebase_firestore_util_status
  EXCLUDE_FROM_ALL
)

cc_select(
  firebase_firestore_util_filesystem
  APPLE   firebase_firestore_util_filesystem_apple
  WIN32   firebase_firestore_util_filesystem_win
  DEFAULT firebase_firestore_util_filesystem_posix
)


## random

check_symbol_exists(arc4random stdlib.h HAVE_ARC4RANDOM)
cc_library(
  firebase_firestore_util_random_arc4random
  SOURCES
    secure_random.h
    secure_random_arc4random.cc
  EXCLUDE_FROM_ALL
)

if(TARGET OpenSSL::Crypto)
  get_target_property(
    CMAKE_REQUIRED_INCLUDES
    OpenSSL::Crypto INTERFACE_INCLUDE_DIRECTORIES
  )
  check_include_files(openssl/rand.h HAVE_OPENSSL_RAND_H)
  cc_library(
    firebase_firestore_util_random_openssl
    SOURCES
      secure_random.h
      secure_random_openssl.cc
    DEPENDS
      OpenSSL::Crypto
    EXCLUDE_FROM_ALL
  )
endif()

cc_select(
  firebase_firestore_util_random
  HAVE_ARC4RANDOM     firebase_firestore_util_random_arc4random
  HAVE_OPENSSL_RAND_H firebase_firestore_util_random_openssl
)


## status

cc_library(
  firebase_firestore_util_status
  SOURCES
    error_apple.h
    error_apple.mm
    status.cc
    status.h
    status_apple.mm
    status_fwd.h
    status_posix.cc
    status_win.cc
    statusor.cc
    statusor.h
    statusor_internals.h
    strerror.cc
    strerror.h
  DEPENDS
    absl_base
    absl_strings
    firebase_firestore_util_base
)


## main library

configure_file(
  config.h.in
  config.h  # NOLINT(generated)
)

cc_library(
  firebase_firestore_util_autoid
  SOURCES
    autoid.cc
    autoid.h
  DEPENDS
    firebase_firestore_util_random
)

cc_library(
  firebase_firestore_util
  SOURCES
    bits.cc
    bits.h
    comparison.cc
    comparison.h
    compressed_member.h
    config.h
    delayed_constructor.h
    empty.h
    equality.h
    hashing.h
    iterator_adaptors.h
    nullability.h
    ordered_code.cc
    ordered_code.h
    range.h
    sanitizers.h
    string_util.cc
    string_util.h
    to_string.h
    type_traits.h
    warnings.h
  DEPENDS
    absl_base
    firebase_firestore_util_async
    firebase_firestore_util_autoid
    firebase_firestore_util_base
    firebase_firestore_util_filesystem
    firebase_firestore_util_random
    firebase_firestore_util_status
)
