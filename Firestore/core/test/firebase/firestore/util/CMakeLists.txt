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
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-format-zero-length")

if(HAVE_ARC4RANDOM)
  cc_test(
    firebase_firestore_util_arc4random_test
    SOURCES
      secure_random_test.cc
    DEPENDS
      firebase_firestore_util_arc4random
  )
endif()

if(HAVE_OPENSSL_RAND_H)
  cc_test(
    firebase_firestore_util_openssl_test
    SOURCES
      secure_random_test.cc
    DEPENDS
      firebase_firestore_util_openssl
  )
endif()

cc_test(
  firebase_firestore_util_test
  SOURCES
    autoid_test.cc
    bits_test.cc
    comparison_test.cc
    ordered_code_test.cc
    string_printf_test.cc
    string_util_test.cc
  DEPENDS
    firebase_firestore_util
)

if(APPLE)
  cc_test(
    firebase_firestore_util_apple_test
    SOURCES
      assert_test.cc
      log_test.cc
    DEPENDS
      firebase_firestore_util_apple
  )
endif(APPLE)

cc_test(
  firebase_firestore_util_stdio_test
  SOURCES
    assert_test.cc
    log_test.cc
  DEPENDS
    firebase_firestore_util_stdio
)
