# Copyright 2019 Google
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

find_package(XCTest REQUIRED)
enable_testing()

xctest_add_bundle(firebase_firestore_objc_integration_tests
  macOS_Example_App
  FSTSmokeTests.mm
  FSTDatastoreTests.mm
  FSTTransactionTests.mm
  API/FIRArrayTransformTests.mm
  API/FIRFieldsTests.mm
  API/FIRNumericTransformTests.mm
  API/FIRTypeTests.mm
  API/FIRCursorTests.mm
  API/FIRFirestoreSourceTests.mm
  API/FIRQueryTests.mm
  # TODO(wuandy): Some tests interacting with FirebaseApp seem to fail.
  # Investigate and enable them.
  # API/FIRValidationTests.mm
  # API/FIRDatabaseTests.mm
  API/FIRListenerRegistrationTests.mm
  API/FIRServerTimestampTests.mm
  API/FIRWriteBatchTests.mm
)

add_objc_flags(firebase_firestore_objc_integration_tests
  FSTSmokeTests.mm
  FSTDatastoreTests.mm
  FSTTransactionTests.mm
  API/FIRArrayTransformTests.mm
  API/FIRFieldsTests.mm
  API/FIRNumericTransformTests.mm
  API/FIRTypeTests.mm
  API/FIRCursorTests.mm
  API/FIRFirestoreSourceTests.mm
  API/FIRQueryTests.mm
  # API/FIRValidationTests.mm
  # API/FIRDatabaseTests.mm
  API/FIRListenerRegistrationTests.mm
  API/FIRServerTimestampTests.mm
  API/FIRWriteBatchTests.mm
)

target_include_directories(
    firebase_firestore_objc_integration_tests
    PUBLIC
    ${FIREBASE_SOURCE_DIR}/Firestore/Source/Public
    ${FIREBASE_SOURCE_DIR}/Firestore/Example/Tests/Util
  )

target_link_libraries(firebase_firestore_objc_integration_tests PUBLIC FirebaseFirestore)
target_link_libraries(firebase_firestore_objc_integration_tests PUBLIC firebase_firestore_tests_util)

xctest_add_test(firebase_firestore_objc_integration_tests
  firebase_firestore_objc_integration_tests)