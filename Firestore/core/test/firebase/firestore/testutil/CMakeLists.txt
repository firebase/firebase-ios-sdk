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

cc_library(
  firebase_firestore_testutil_apple
  SOURCES
    app_testing.h
    app_testing.mm
    xcgmock.h
  DEPENDS
    FirebaseCore
    absl_strings
    GMock::GMock
    ${XCTest_LIBRARIES}
  EXCLUDE_FROM_ALL
)

if(APPLE)
  list(APPEND TESTUTIL_DEPENDS firebase_firestore_testutil_apple)
endif()

cc_library(
  firebase_firestore_testutil
  SOURCES
    async_testing.cc
    async_testing.h
    equals_tester.h
    testutil.cc
    testutil.h
    time_testing.cc
    time_testing.h
    view_testing.cc
    view_testing.h
  DEPENDS
    # TODO(b/111328563) Force nanopb first to work around ODR violations
    firebase_firestore_nanopb

    ${TESTUTIL_DEPENDS}
    GTest::GTest
    absl_time
    firebase_firestore_core
    firebase_firestore_model
    firebase_firestore_util
)

if(APPLE AND XCTest_FOUND)
  cc_test(
    firebase_firestore_testutil_test
    SOURCES
      xcgmock_test.mm
    DEPENDS
      firebase_firestore_objc_api
      firebase_firestore_testutil
  )
endif()
