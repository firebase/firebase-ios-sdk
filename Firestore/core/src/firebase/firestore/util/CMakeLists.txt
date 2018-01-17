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

cc_library(
  firebase_firestore_util_base
  SOURCES
    secure_random.h
    secure_random_arc4random.cc
    string_printf.cc
    string_printf.h
  DEPENDS
    absl_base
)

## assert and log

cc_library(
  firebase_firestore_util_stdio
  SOURCES
    assert_stdio.cc
    log_stdio.cc
  DEPENDS
    firebase_firestore_util_base
    absl_base
  EXCLUDE_FROM_ALL
)

cc_library(
  firebase_firestore_util_apple
  SOURCES
    assert_apple.mm
    log_apple.mm
    string_apple.h
  DEPENDS
    FirebaseCore
  EXCLUDE_FROM_ALL
)

# Export a dependency on the correct logging library for this platform. All
# buildable libraries are built and tested but only the best fit is exported.
if(APPLE)
  list(APPEND UTIL_DEPENDS firebase_firestore_util_apple)
else()
  list(APPEND UTIL_DEPENDS firebase_firestore_util_stdio)
endif()


## main library

cc_library(
  firebase_firestore_util
  SOURCES
    autoid.cc
    autoid.h
    firebase_assert.h
    log.h
  DEPENDS
    ${UTIL_DEPENDS}
    firebase_firestore_util_base
    absl_base
)
