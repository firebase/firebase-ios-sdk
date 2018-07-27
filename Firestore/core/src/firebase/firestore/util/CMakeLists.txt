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

cc_library(
  firebase_firestore_util_base
  SOURCES
    string_format.cc
    string_format.h
  DEPENDS
    absl_base
    absl_strings
)


## assert and log

cc_library(
  firebase_firestore_util_log_stdio
  SOURCES
    hard_assert_stdio.cc
    hard_assert.h
    log.h
    log_stdio.cc
  DEPENDS
    firebase_firestore_util_base
    absl_base
  EXCLUDE_FROM_ALL
)

cc_library(
  firebase_firestore_util_log_apple
  SOURCES
    hard_assert.h
    hard_assert_apple.mm
    log.h
    log_apple.mm
    string_apple.h
  DEPENDS
    FirebaseCore
    GoogleUtilities
    absl_strings
    firebase_firestore_util_base
  EXCLUDE_FROM_ALL
)

if(APPLE)
  set(
    FIREBASE_FIRESTORE_UTIL_LOG
    firebase_firestore_util_log_apple
  )
else()
  set(
    FIREBASE_FIRESTORE_UTIL_LOG
    firebase_firestore_util_log_stdio
  )
endif()


## secure_random

check_symbol_exists(arc4random stdlib.h HAVE_ARC4RANDOM)
cc_library(
  firebase_firestore_util_random_arc4random
  SOURCES
    secure_random_arc4random.cc
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
      secure_random_openssl.cc
    DEPENDS
      OpenSSL::Crypto
  )
endif()

if(HAVE_ARC4RANDOM)
  set(
    FIREBASE_FIRESTORE_UTIL_RANDOM
    firebase_firestore_util_random_arc4random
  )

elseif(HAVE_OPENSSL_RAND_H)
  set(
    FIREBASE_FIRESTORE_UTIL_RANDOM
    firebase_firestore_util_random_openssl
  )

else()
  message(FATAL_ERROR "No implementation for SecureRandom available.")

endif()

## async queue

check_symbol_exists(dispatch_async_f dispatch/dispatch.h HAVE_LIBDISPATCH)

cc_library(
  firebase_firestore_util_executor_std
  SOURCES
    executor_std.cc
    executor_std.h
    executor.h
  DEPENDS
    absl_bad_optional_access
    absl_optional
    ${FIREBASE_FIRESTORE_UTIL_LOG}
  EXCLUDE_FROM_ALL
)

if(HAVE_LIBDISPATCH)
cc_library(
  firebase_firestore_util_executor_libdispatch
  SOURCES
    executor_libdispatch.mm
    executor_libdispatch.h
    executor.h
  DEPENDS
    absl_bad_optional_access
    absl_optional
    absl_strings
    ${FIREBASE_FIRESTORE_UTIL_LOG}
  EXCLUDE_FROM_ALL
)
endif()

if(HAVE_LIBDISPATCH)
  set(
    FIREBASE_FIRESTORE_UTIL_EXECUTOR
    firebase_firestore_util_executor_libdispatch
  )

else()
  set(
    FIREBASE_FIRESTORE_UTIL_EXECUTOR
    firebase_firestore_util_executor_std
  )

endif()


## main library

configure_file(
  config.h.in
  config.h
)

cc_library(
  firebase_firestore_util
  SOURCES
    async_queue.cc
    async_queue.h
    autoid.cc
    autoid.h
    bits.cc
    bits.h
    comparator_holder.h
    comparison.cc
    comparison.h
    config.h
    hashing.h
    iterator_adaptors.h
    ordered_code.cc
    ordered_code.h
    path.cc
    path.h
    range.h
    secure_random.h
    status.cc
    status.h
    statusor.cc
    statusor.h
    statusor_internals.h
    strerror.cc
    strerror.h
    string_util.cc
    string_util.h
    type_traits.h
  DEPENDS
    absl_base
    firebase_firestore_util_base
    ${FIREBASE_FIRESTORE_UTIL_EXECUTOR}
    ${FIREBASE_FIRESTORE_UTIL_LOG}
    ${FIREBASE_FIRESTORE_UTIL_RANDOM}
)

if(APPLE)
  target_sources(
    firebase_firestore_util PRIVATE
    status_apple.mm
  )
endif()
