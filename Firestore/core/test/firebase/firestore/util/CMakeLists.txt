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

set(CMAKE_CXX_EXTENSIONS ON)

# Required to allow 0 length printf style strings for testing purposes.
if(NOT MSVC)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-format-zero-length")
endif()

## assert and log

if(APPLE)
  cc_test(
    firebase_firestore_util_log_apple_test
    SOURCES
      hard_assert_test.cc
      log_test.cc
    DEPENDS
      firebase_firestore_util_log_apple
  )
endif(APPLE)

cc_test(
  firebase_firestore_util_log_stdio_test
  SOURCES
    hard_assert_test.cc
    log_test.cc
  DEPENDS
    firebase_firestore_util_log_stdio
)

## secure random

if(HAVE_ARC4RANDOM)
  cc_test(
    firebase_firestore_util_random_arc4random_test
    SOURCES
      secure_random_test.cc
    DEPENDS
      firebase_firestore_util_random_arc4random
  )
endif()

if(HAVE_OPENSSL_RAND_H)
  cc_test(
    firebase_firestore_util_random_openssl_test
    SOURCES
      secure_random_test.cc
    DEPENDS
      firebase_firestore_util_random_openssl
  )
endif()

## executors

cc_test(
  firebase_firestore_util_executor_std_test
  SOURCES
    executor_test.h
    executor_test.cc
    executor_std_test.cc
    async_tests_util.h
  DEPENDS
    firebase_firestore_util_executor_std
)

if(HAVE_LIBDISPATCH)
  cc_test(
    firebase_firestore_util_executor_libdispatch_test
    SOURCES
      executor_test.h
      executor_test.cc
      executor_libdispatch_test.mm
      async_tests_util.h
    DEPENDS
      firebase_firestore_util_executor_libdispatch
  )
endif()

## async queue

cc_test(
  firebase_firestore_util_async_queue_std_test
  SOURCES
    async_queue_test.h
    async_queue_test.cc
    async_queue_std_test.cc
    async_tests_util.h
  DEPENDS
    firebase_firestore_util_executor_std
    firebase_firestore_util
)

if(HAVE_LIBDISPATCH)
  cc_test(
    firebase_firestore_util_async_queue_libdispatch_test
    SOURCES
      async_queue_test.h
      async_queue_test.cc
      async_queue_libdispatch_test.mm
      async_tests_util.h
    DEPENDS
    firebase_firestore_util_executor_libdispatch
    firebase_firestore_util
  )
endif()

## main library

cc_test(
  firebase_firestore_util_test
  SOURCES
    autoid_test.cc
    bits_test.cc
    comparison_test.cc
    hashing_test.cc
    iterator_adaptors_test.cc
    ordered_code_test.cc
    path_test.cc
    status_test.cc
    status_test_util.h
    statusor_test.cc
    strerror_test.cc
    string_format_test.cc
    string_util_test.cc
    string_win_test.cc
  DEPENDS
    absl_base
    absl_strings
    firebase_firestore_util
    GMock::GMock
)

if(APPLE)
  target_sources(
    firebase_firestore_util_test
    PUBLIC
      string_format_apple_test.mm
      type_traits_apple_test.mm
  )
endif()
