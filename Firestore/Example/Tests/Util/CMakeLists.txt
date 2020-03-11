# Copyright 2019 Google LLC
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

if(APPLE)
  firebase_ios_cc_library(
    firebase_firestore_objc_test_util
    HEADERS
      FSTEventAccumulator.h
      XCTestCase+Await.h
      FSTIntegrationTestCase.h
      FIRFirestore+Testing.h
      FSTHelpers.h
    SOURCES
      FSTEventAccumulator.mm
      XCTestCase+Await.mm
      FSTIntegrationTestCase.mm
      FSTHelpers.mm
    DEPENDS
      absl_any
      absl_strings
      FirebaseFirestore
      firebase_firestore_auth
      firebase_firestore_core
      firebase_firestore_local
      firebase_firestore_model
      firebase_firestore_util
      firebase_firestore_remote
      firebase_firestore_remote_testing
      firebase_firestore_nanopb
      firebase_firestore_protos_nanopb
      firebase_firestore_testutil
      ${XCTest_LIBRARIES}
      GTest::GTest
  )
endif(APPLE)
